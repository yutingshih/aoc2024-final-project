/*
    Accelerator Controller

    Author: Eason Yeh
    Version: 1.0

    Support Operation: Convolution2D / ReLU / MaxPooling2D / AvgPooling2D
*/
`define BYTE 8

module controller #(
    parameter XBUS_NUMS = 12,
              PE_NUMS = 14,
              IFMAP_GIN_ROW_LEN = 4,
              IFMAP_GIN_ID_LEN = 5,
              FILTER_GIN_ROW_LEN = 4,
              FILTER_GIN_ID_LEN = 5,
              IPSUM_GIN_ROW_LEN = 4,
              IPSUM_GIN_ID_LEN = 5,
              OPSUM_GON_ROW_LEN = 4,
              OPSUM_GON_ID_LEN = 5,
              IFMAP_DATA_SIZE = 8,
              FILTER_DATA_SIZE = 16,
              PSUM_DATA_SIZE = 32,
              IFMAP_NUM = 4,
              FILTER_NUM = 1,
              IPSUM_NUM = 4,
              OPSUM_NUM = 4,
              CONFIG_BITWIDTH = 32,
              ADDRESS_BITWIDTH = 32
)(
    input rst,
    input clk,
    /* Signal */
    input start,
    output finish,
    output enable_pe_array,

    /* scalar configuration */
    input [CONFIG_BITWIDTH-1:0] computation_config,
    input [CONFIG_BITWIDTH-1:0] address_ifmap,
    input [CONFIG_BITWIDTH-1:0] address_filter,
    input [CONFIG_BITWIDTH-1:0] address_ipsum,
    input [CONFIG_BITWIDTH-1:0] address_opsum,
    input [CONFIG_BITWIDTH-1:0] address_scan_chain,

    /* Convolution parameters */
    input [2:0]  config_q,
    input [4:0]  config_p,
    input [4:0]  config_U,
    input [4:0]  config_S,
    input [7:0]  config_F,
    input [7:0]  config_W,
    input [7:0]  config_H,
    input [7:0]  config_E,
    input [11:0]  config_C,
    input [11:0]  config_M,
    input [4:0]  config_t,
    input [4:0]  config_r,
   

    /* scan chain information */
    output reg [1:0] pe_config_id;
    output reg set_pe_info,
    output reg set_ln_info,
    output reg set_id,
    output reg set_row,

    /* NoC Control */
    output reg [IFMAP_GIN_ROW_LEN-1:0]   ifmap_row_id, // IFMAP X-Bus
    output reg [IFMAP_GIN_ID_LEN-1:0]    ifmap_col_id, // IFMAP Y-Bus PE id
    output reg [FILTER_GIN_ROW_LEN-1:0]  filter_row_id, // FILTER X-Bus
    output reg [FILTER_GIN_ID_LEN-1:0]   filter_col_id, // FILTER Y-Bus PE id
    output reg [IPSUM_GIN_ROW_LEN-1:0]   ipsum_row_id, // IPSUM X-Bus
    output reg [IPSUM_GIN_ID_LEN-1:0]    ipsum_col_id, // IPSUM Y-Bus PE id
    output reg [OPSUM_GON_ROW_LEN-1:0]   opsum_row_id, // OPSUM X-Bus
    output reg [OPSUM_GON_ID_LEN-1:0]    opsum_col_id, // OPSUM Y-Bus PE id

    output reg ifmap_enable,
    output reg filter_enable,
    output reg ipsum_enable,
    output reg opsum_ready,

    input ifmap_ready,
    input filter_ready,
    input ipsum_ready,
    input opsum_enable,

    /* 
        *** Read Data To Mux ***
        0: PE config  (only when set info)
        1: Scan-chain ID network (only when set info)
        2: Scan-chain ROW network (only when set info)
        3: Scan-chain LN  (only when set info)
        4: IFMAP GIN
        5: FILTER GIN
        6: OFMAP GIN
        7: Pooling
    */
    output reg [3:0] read_to_select,
    /* 
        *** Read Data From Mux ***
        0: IARG-Buffer (BRAM)
        1: OARG-Buffer (BRAM)
    */
    output reg read_from_select,

    output reg [ADDRESS_BITWIDTH-1:] read_address,
    /* 
        *** Write Data From Mux ***
        0: OPSUM GON
        1: RELU OUPUT
        2: Pooling Engine
        3: (Reserved)
    */
    output reg [1:0] write_from_select, 
    /* 
        *** Write Data To Mux ***
        0: OARG-Buffer (BRAM)
        1: Pooling Engine
    */
    output reg write_to_select,
    output reg [ADDRESS_BITWIDTH-1:] write_address,

    output reg ram_enable,
    output reg [3:0] ram_we,

    output reg [3:0] ifmap_buffer_select, // one-hot encode
    output reg [3:0] ipsum_buffer_select, // one-hot encode
    output reg [1:0] opsum_buffer_select, // index
    output wire padding
);

/* 
    Accelerator config 

    scalar0_config
    |- tiled operation [3:0]
        |- Convolution (0: Not use, 1: use) [0]
        |- ReLU (0: Not use, 1: use) [1]
        |- MaxPooling (0: Not use, 1: Maxpooling, 2:Avgpooling) [2]
    |-  kernel size [9:4]
        |- Convolution (0 for not use / 3 / 5 / 7) [7:4]
        |- Pooling (0 for not use / 2 / 3) [9:8]
    |-  stride [13:10]
        |- Convolution (0 for not use /1 / 2) [11:10]
        |- Pooling (0 for not use /1 / 2) [13:12]
    |- padding (0 / 1 / 2 / 3) [21:14]
        |- Convolution (top / left / bottom / right) [2bit for each]
    |- multi-pass-signal [25:22]
        |- ifmap(0/1) / filter(0/1) / bias (0/1) / scan_chain(0/1)

    scalar1_config ~ scalar4_config
    |- global buffer addressing
        |- starting address ( ifmap / filter / ipsum / scan chain )
*/

reg [4:0] state, state_next;
reg [ADDRESS_BITWIDTH:0] counter, counter_next;

reg [ADDRESS_BITWIDTH:0] Scounter, Scounter_next;
reg [ADDRESS_BITWIDTH:0] Rcounter, Rcounter_next;
reg [ADDRESS_BITWIDTH:0] Qcounter, Qcounter_next;
reg [ADDRESS_BITWIDTH:0] Pcounter, Pcounter_next;

reg [ADDRESS_BITWIDTH:0] Fcounter, Fcounter_next;
reg [ADDRESS_BITWIDTH:0] Wcounter, Wcounter_next;

reg [ADDRESS_BITWIDTH:0] Mcounter, Mcounter_next;

reg [ADDRESS_BITWIDTH:0] Ecounter, Ecounter_next;
reg [ADDRESS_BITWIDTH:0] Hcounter, Hcounter_next;

reg [ADDRESS_BITWIDTH:0] Ccounter, Ccounter_next;
reg [ADDRESS_BITWIDTH:0] Ucounter, Ucounter_next;

reg [CONFIG_BITWIDTH-1:0] computation_config_reg;
reg [CONFIG_BITWIDTH-1:0] pe_config_reg [2:0];
reg [CONFIG_BITWIDTH-1:0] address_ifmap_reg;
reg [CONFIG_BITWIDTH-1:0] address_filter_reg;
reg [CONFIG_BITWIDTH-1:0] address_ipsum_reg;
reg [CONFIG_BITWIDTH-1:0] address_opsum_reg;
reg [CONFIG_BITWIDTH-1:0] address_scan_chain_reg;

/* Decode */
wire [3:0] opcode = computation_config_reg[3:0]; // {P,P,R,C}
wire [3:0] conv_kernel_size = computation_config_reg[7:4];
wire [1:0] pooling_kernel_size = computation_config_reg[9:8];
wire [1:0] conv_stride = computation_config_reg[11:10];
wire [1:0] pooling_stride = computation_config_reg[13:12];
wire [1:0] conv_padding_right = computation_config_reg[15:14];
wire [1:0] conv_padding_bottom = computation_config_reg[17:16];
wire [1:0] conv_padding_left = computation_config_reg[19:18];
wire [1:0] conv_padding_top = computation_config_reg[21:20];
wire use_ifmap = computation_config_reg[22];
wire use_filter = computation_config_reg[23];
wire use_bias = computation_config_reg[24];
wire use_scan_chain = computation_config_reg[25];



assign padding = (
    (Wcounter < conv_padding_left) || 
    (Ecounter < conv_padding_top) || 
    (Wcounter+conv_padding_left > config_W) || 
    (Ecounter+conv_padding_top > config_H) 
    );
wire [ADDRESS_BITWIDTH:0] Waddress = (Wcounter < conv_padding_left)? 0: Wcounter-conv_padding_left;
wire [ADDRESS_BITWIDTH:0] Haddress = (Ecounter < conv_padding_top)? 0: Ecounter-conv_padding_top;


wire [ADDRESS_BITWIDTH:0] ipsum_addr_bias = config_S *(config_S * Ccounter + Hcounter) + Wcounter;

                

parameter   SIDLE = 0,
            SCONFIG = 1,
            SPREREAD = 2,
            SSET_PECONFIG = 3,
            SSET_ID = 4,
            SSET_RAW = 5,
            SSET_LN_INFO = 6,
            SSET_PE_INFO = 7,
            SREADY = 9,
            SREAD_FILTER = 10,
            SPUT_FILTER = 11,
            SREAD_IFMAP = 12,
            SGATHER_IFMAP = 13,
            SPUT_IFMAP = 14,
            SCHECK_IPSUM = 16,
            SREAD_IPSUM = 16,
            SGATHER_IPSUM = 17,
            SPUT_IPSUM = 18,
            SGET_OPSUM = 20,
            SWRITE_OPSUM = 21,
            SPUT_POOLING = 22,
            SGET_POOLING = 23,
            SDONE = 31;

parameter   READ_TO_PE_CONFIG = 0,
            READ_TO_SCAN_ID = 1,
            READ_TO_SCAN_ROW = 2,
            READ_TO_SCAN_LN = 3,
            READ_TO_IFMAPGIN = 4,
            READ_TO_FILTERGIN = 5,
            READ_TO_IPSUMGIN = 6,
            READ_TO_POOLING = 7;

parameter   READ_FROM_IARG_BUFFER = 0,
            READ_FROM_OARG_BUFFER = 0;

parameter   WRITE_FROM_OPSUMGON = 0,
            WRITE_FROM_RELU = 1,
            WRITE_FROM_POOLING = 2;

parameter   WRITE_TO_OPSUMGON = 0,
            WRITE_TO_OARG_BUFFER = 1;

/* State Machine */
always @(posedge clk ) begin
    if(~rst) begin
        state <= SIDLE;
        counter <= 0;
        Scounter <= 0;
        Rcounter <= 0;
        Qcounter <= 0;
        Pcounter <= 0;
        Fcounter <= 0;
        Wcounter <= 0;
        Mcounter <= 0;
        Ecounter <= 0;
        Hcounter <= 0;
        Ccounter <= 0;
        Ucounter <= 0;
    end else begin
        state <= state_next;
        counter <= counter_next;
        Scounter <= Scounter_next;
        Rcounter <= Rcounter_next;
        Qcounter <= Qcounter_next;
        Pcounter <= Pcounter_next;
        Fcounter <= Fcounter_next;
        Wcounter <= Wcounter_next;
        Mcounter <= Mcounter_next;
        Ecounter <= Ecounter_next;
        Hcounter <= Hcounter_next;
        Ccounter <= Ccounter_next;
        Ucounter <= Ucounter_next;
    end
end

/* config data and starting address info */
always @(posedge clk ) begin
    if(~rst) begin
        address_ifmap_reg <= 0;
        address_filter_reg <= 0;
        address_ipsum_reg <= 0;
        address_opsum_reg <= 0;
        address_scan_chain_reg <= 0;
        computation_config_reg <= 0;
    end else if(state == SIDLE && start)begin
        address_ifmap_reg <= address_ifmap;
        address_filter_reg <= address_filter;
        address_ipsum_reg <= address_ipsum;
        address_opsum_reg <= address_opsum;
        address_scan_chain_reg <= address_scan_chain;
        computation_config_reg <= computation_config;
    end
end


/* Combinational Circuit */
always @(*) begin
    state_next = SIDLE;
    counter_next = counter;
    Scounter_next = Scounter;
    Rcounter_next = Rcounter;
    Qcounter_next = Qcounter;
    Pcounter_next = Pcounter;
    Fcounter_next = Fcounter;
    Wcounter_next = Wcounter;
    Mcounter_next = Mcounter;
    Ecounter_next = Ecounter;
    Hcounter_next = Hcounter;
    Ccounter_next = Ccounter;
    Ucounter_next = Ucounter;
    IDcounter_next = IDcounter;
    set_pe_info = 0;
    set_ln_info = 0;
    set_id = 0;
    set_row = 0;
    read_to_select = 0;
    read_from_select = 0;
    read_address = 0;
    write_from_select = 0;
    write_to_select = 0;
    write_address = 0;
    ram_enable = 0;
    ram_we = 0;
    ifmap_enable = 0;
    filter_enable = 0;
    ipsum_enable = 0;
    opsum_ready = 0;
    ifmap_ready = 0;
    filter_ready = 0;
    ipsum_ready = 0;
    opsum_enable = 0;
    ifmap_row_id = 0;
    ifmap_col_id = 0;
    filter_row_id = 0;
    filter_col_id = 0;
    ipsum_row_id = 0;
    ipsum_col_id = 0;
    opsum_row_id = 0;
    opsum_col_id = 0;
    ifmap_buffer_select = 0;
    ipsum_buffer_select = 0;
    opsum_buffer_select = 0;
    case (state)
        SIDLE:begin
            if(start) begin
                state_next = SCONFIG; // give it a cycle to store the config data
                counter_next = 'd0;
            end
        end
        SCONFIG: begin // determine if need to config info and scan chain
            if(use_scan_chain) begin
                state_next = SREAD_SCAN;
                counter_next = 'd0; // ready to read scan chain
            end else begin
                state_next = SREADY;
                counter_next = 'd0;
            end
        end
        SPREREAD: begin // read from BRAM address
            state_next =  SSET_PECONFIG;
            counter_next = counter + 'd1;
            read_from_select = READ_FROM_IARG_BUFFER;
            read_address = scan_chain_start_addr+counter;
            ram_enable = 1;
        end
        SSET_PECONFIG: begin
            counter_next = counter + 'd1;
            read_from_select = READ_FROM_IARG_BUFFER;
            read_address = scan_chain_start_addr+counter;
            ram_enable = 1;
            read_to_select = READ_TO_PE_CONFIG;
            pe_config_id = counter[1:0] - 1;
            if(counter == 4)begin
                set_pe_info = 1; 
            end
        end
        SSET_ID: begin // read from BRAM address & write to id scan chain
            counter_next = counter + 'd1;
            if (counter == (XBUS_NUMS * PE_NUMS*4)) begin // 4 network
                state_next = SSET_ROW;
            end
            read_from_select = READ_FROM_IARG_BUFFER;
            read_address = scan_chain_start_addr+counter;
            ram_enable = 1;
            set_id = 1;
            read_to_select = READ_TO_SCAN_ID;
        end
        SSET_ROW: begin
            counter_next = counter + 'd1;
            if (counter == (XBUS_NUMS * 4 + XBUS_NUMS * PE_NUMS*4)) begin // 4 network
                state_next = SSET_LN_INFO;
                counter_next = counter + 'd4;
            end
            read_from_select = READ_FROM_IARG_BUFFER;
            read_address = scan_chain_start_addr+counter;
            ram_enable = 1;
            set_row = 1;
            read_to_select = READ_TO_SCAN_ROW;
        end
        SSET_LN_INFO: begin // just one cycle
            counter_next = 0;
            state_next = SSET_PE_INFO;
            set_ln_info = 1;
            read_to_select = READ_TO_SCAN_LN;
            read_from_select = READ_FROM_IARG_BUFFER;
            read_address = scan_chain_start_addr+counter;
            ram_enable = 1;
        end
        SSET_PE_INFO: begin // just one cycle
            state_next = SREADY;
            set_pe_info = 1;
            read_to_select = READ_TO_SCAN_PE;
            state_next = SSET_PE_INFO;
        end
        SREADY: begin
            state_next = SREAD_FILTER;
            counter_next = 0; 
        end
        SREAD_FILTER: begin  // TBD
            read_from_select = READ_FROM_IARG_BUFFER;
            read_address = address_filter_reg+(
                (Mcounter+Pcounter)*config_C*config_S*config_S + (Ccounter+Qcounter) * config_S * config_S + Rcounter * config_S + Scounter
                )*(FILTER_DATA_SIZE/`BYTE);
            ram_enable = 1;
            state_next = SPUT_FILTER;
        end
        SPUT_FILTER: begin
            read_from_select = READ_FROM_IARG_BUFFER;
            filter_enable = 1;
            read_to_select = READ_TO_FILTERGIN;
            filter_col_id = Scounter; 
            filter_row_id = Ccounter;
            if(filter_ready)begin
                state_next = SREAD_FILTER;
                if(Qcounter + 1 == config_q)begin
                    Qcounter_next = 0;
                    if(Scounter + 1 == config_S)begin
                        Scounter_next = 0;
                        if(Pcounter + 1 == config_p)begin
                            Pcounter_next = 0;
                            if(Rcounter + 1 == config_r)begin
                                Rcounter_next = 0;
                                if(Mcounter + config_p == config_M)begin
                                    Mcounter_next = 0;
                                    if(Ccounter + config_q == config_C)begin
                                        Ccounter_next = 0;
                                        state_next = SREAD_IFMAP;
                                    end else begin
                                        Ccounter_next = Ccounter + config_q;
                                    end
                                end else begin
                                    Mcounter_next = Mcounter + config_p;
                                end
                            end else begin
                                Rcounter_next = Rcounter + 1;
                            end
                        end else begin
                            Pcounter_next = Pcounter + 1;
                        end
                    end else begin
                        Scounter_next = Scounter + 1;
                    end
                end else begin
                    Qcounter_next = Qcounter + 1;
                end
            end
            else begin
                state_next = state;
            end
        end
        SREAD_IFMAP: begin
            read_from_select = READ_FROM_IARG_BUFFER;
            read_address = address_ifmap_reg+(
                (Ccounter+Qcounter)*config_H*config_W + (Haddress) * config_W + Waddress
                )*(IFMAP_DATA_SIZE/`BYTE);
            ram_enable = 1;
            state_next = SGATHER_IFMAP;
        end
        SGATHER_IFMAP: begin
            read_from_select = READ_FROM_IARG_BUFFER;
            read_to_select = READ_TO_IFMAPGIN;
            ifmap_buffer_select = (Qcounter == 0)? 4'b0001:
                        (Qcounter == 1)? 4'b0010:
                        (Qcounter == 2)? 4'b0100:4'b1000;
            if(Qcounter+1 == config_q)begin
                Qcounter_next = 0;
                state_next = SPUT_IFMAP;
            end else begin
                Qcounter_next = Qcounter + 1;
                state_next = SREAD_IFMAP;
            end
        end
        SPUT_IFMAP: begin
            ifmap_col_id = Hcounter; 
            ifmap_row_id = Ccounter;
            ifmap_enable = 1;
            if(ifmap_ready)begin
                state_next = SREAD_IFMAP;
                if(Ecounter + 1 == config_E)begin
                    Ecounter_next = 0;
                    if(Ccounter + config_q == config_C)begin  //TBD
                        Ccounter_next = 0;
                        if(Ucounter + 1 == config_U)begin  //TBD
                            Ucounter_next = 0;
                            state_next = SREAD_IPSUM;
                            Qcounter_next = 0;
                            Wcounter_next = Wcounter + 1;
                        end else begin
                            Ucounter_next = Ucounter + 1;
                        end
                    end else begin
                        Ccounter_next = Ccounter + config_q;
                    end
                end else begin
                    Ecounter_next = Ecounter + 1;
                end
            end
        end
        SREAD_IPSUM: begin
            read_from_select = READ_FROM_IARG_BUFFER;
            read_address = address_ipsum_reg+(
                (Mcounter+Pcounter)*config_E*config_F + (Ecounter) * config_F + Fcounter
                )*(IFMAP_DATA_SIZE/`BYTE);
            ram_enable = 1;
            state_next = SGATHER_IPSUM;
        end
        SGATHER_IPSUM: begin
            read_to_select = READ_TO_IPSUMGIN
            ipsum_buffer_select = (Pcounter[1:0] == 0)? 4'b0001:
                        (Pcounter[1:0] == 1)? 4'b0010:
                        (Pcounter[1:0] == 2)? 4'b0100:4'b1000;
            if(Pcounter[1:0] == 2'b11)begin
                state_next = SPUT_IPSUM;
            end else begin
                Pcounter_next = Pcounter + 1;
                state_next = SREAD_IPSUM;
            end
        end
        SPUT_IPSUM: begin
            ipsum_col_id = Ecounter;
            ipsum_row_id = Mcounter;
            ipsum_enable = 1;
            if(ipsum_ready)begin
                state_next = SREAD_IPSUM;
                if(Pcounter + 1 == config_p)begin
                    Pcounter_next = 0;
                    if(Ecounter + 1 == config_E)begin
                        Ecounter_next = 0;
                        if(Mcounter + config_p == config_M)begin
                            Mcounter_next = 0;
                            state_next = SGET_OPSUM;
                        end else begin
                            Mcounter_next = Mcounter + config_p;
                        end
                    end else begin
                        Ecounter_next = Ecounter + 1;
                    end
                end else begin
                    Pcounter_next = Pcounter + 1;
                end
            end
        end
        SGET_OPSUM: begin
            opsum_col_id = Ecounter;
            opsum_row_id = Mcounter;
            opsum_ready = 1;
            if(opsum_enable)begin
                state_next = SWRITE_OPSUM;
            end
        end
        SWRITE_OPSUM: begin
            write_address = address_opsum_reg+(
                (Mcounter+Pcounter)*config_E*config_F + (Ecounter) * config_F + Fcounter
                )*(IFMAP_DATA_SIZE/`BYTE);
            ram_enable = 1;
            ram_we = 4'b1111;
            opsum_buffer_select = Pcounter[1:0];
            if(Pcounter[1:0] == 2'b11)begin
                state_next = SGET_OPSUM;
                if(Pcounter + 1 == config_p)begin
                    Pcounter_next = 0;
                    if(Ecounter + 1 == config_E)begin
                        Ecounter_next = 0;
                        if(Mcounter + config_p == config_M)begin
                            Mcounter_next = 0;
                            if(Fcounter + 1 == config_F) begin
                                Fcounter_next = 0;
                                state_next = SDONE;
                            end else begin
                                Fcounter_next = Fcounter + 1;
                                state_next = SREAD_IFMAP;
                            end
                        end else begin
                            Mcounter_next = Mcounter + config_p;
                        end
                    end else begin
                        Ecounter_next = Ecounter + 1;
                    end
                end else begin
                    Pcounter_next = Pcounter + 1;
                end
            end else begin
                Pcounter_next = Pcounter + 1;
                state_next = SWRITE_OPSUM;
            end
        end
        SPUT_POOLING: begin
            state_next = SIDLE;
        end
        SGET_POOLING: begin
            state_next = SIDLE;
        end
        SDONE: begin
            finish = 1;
            state_next = SIDLE;
        end
        default: state_next = SIDLE;
    endcase
end
    
endmodule