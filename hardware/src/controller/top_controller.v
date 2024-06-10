/*
    Accelerator Controller

    Author: Eason Yeh
    Version: 1.0

    Support Operation: Convolution2D / ReLU / MaxPooling2D / AvgPooling2D
*/
module controller #(
    parameter XBUS_NUMS = 12,
              PE_NUMS = 14,
              IFMAP_GIN_ROW_LEN = 4,
              IFMAP_GIN_ID_LEN = 4,
              FILTER_GIN_ROW_LEN = 4,
              FILTER_GIN_ID_LEN = 4,
              IPSUM_GIN_ROW_LEN = 4,
              IPSUM_GIN_ID_LEN = 4,
              OPSUM_GON_ROW_LEN = 4,
              OPSUM_GON_ID_LEN = 4,
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
    input [CONFIG_BITWIDTH-1:0] convolution_param1,
    input [CONFIG_BITWIDTH-1:0] convolution_param2,
    input [CONFIG_BITWIDTH-1:0] address_ifmap,
    input [CONFIG_BITWIDTH-1:0] address_filter,
    input [CONFIG_BITWIDTH-1:0] address_ipsum,
    input [CONFIG_BITWIDTH-1:0] address_opsum,
    input [CONFIG_BITWIDTH-1:0] address_scan_chain,
    
   

    /* scan chain information */
    output set_pe_info,
    output set_ln_info,
    output set_id,
    output set_row,

    /* NoC Control */
    output [IFMAP_GIN_ROW_LEN-1:0]   ifmap_row_id, // IFMAP X-Bus
    output [IFMAP_GIN_ID_LEN-1:0]    ifmap_col_id, // IFMAP Y-Bus PE id
    output [FILTER_GIN_ROW_LEN-1:0]  filter_row_id, // FILTER X-Bus
    output [FILTER_GIN_ID_LEN-1:0]   filter_col_id, // FILTER Y-Bus PE id
    output [IPSUM_GIN_ROW_LEN-1:0]   ipsum_row_id, // IPSUM X-Bus
    output [IPSUM_GIN_ID_LEN-1:0]    ipsum_col_id, // IPSUM Y-Bus PE id
    output [OPSUM_GON_ROW_LEN-1:0]   opsum_row_id, // OPSUM X-Bus
    output [OPSUM_GON_ID_LEN-1:0]    opsum_col_id, // OPSUM Y-Bus PE id

    output ifmap_enable,
    output filter_enable,
    output ipsum_enable,
    output opsum_ready,

    input ifmap_ready,
    input filter_ready,
    input ipsum_ready,
    input opsum_enable,

    /* 
        *** Read Data To Mux ***
        0: Scan-chain ID network (only when set info)
        1: Scan-chain ROW network (only when set info)
        2: Scan-chain LN  (only when set info)
        3: Scan-chain PE  (only when set info)
        4: IFMAP GIN
        5: FILTER GIN
        6: OFMAP GIN
        7: Pooling
    */
    output [2:0] read_to_select,
    /* 
        *** Read Data From Mux ***
        0: IARG-Buffer (BRAM)
        1: OARG-Buffer (BRAM)
    */
    output read_from_select,

    output [ADDRESS_BITWIDTH-1:] read_address,
    /* 
        *** Write Data From Mux ***
        0: OPSUM GON
        1: RELU OUPUT
        2: Pooling Engine
        3: (Reserved)
    */
    output [1:0] write_from_select, 
    /* 
        *** Write Data To Mux ***
        0: OARG-Buffer (BRAM)
        1: Pooling Engine
    */
    output write_to_select,
    output [ADDRESS_BITWIDTH-1:] write_address,

    output ram_enable,
    output [3:0] ram_we,
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

reg [ADDRESS_BITWIDTH:0] Fcounter, Fcounter_next;
reg [ADDRESS_BITWIDTH:0] Wcounter, Wcounter_next;

reg [ADDRESS_BITWIDTH:0] Mcounter, Mcounter_next;

reg [ADDRESS_BITWIDTH:0] Ecounter, Ecounter_next;
reg [ADDRESS_BITWIDTH:0] Hcounter, Hcounter_next;

reg [ADDRESS_BITWIDTH:0] Ccounter, Ccounter_next;

reg [CONFIG_BITWIDTH-1:0] computation_config_reg;
reg [CONFIG_BITWIDTH-1:0] convolution_param1_reg;
reg [CONFIG_BITWIDTH-1:0] convolution_param2_reg;
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

wire [7:0] ifmap_W = convolution_param1_reg[7:0];
wire [7:0] ifmap_H = convolution_param1_reg[15:8]; 
wire [2:0] ifmap_C = convolution_param1_reg[18:16];
wire [5:0] filter_NUM = convolution_param1_reg[24:19];

wire [7:0] ofmap_E = convolution_param2_reg[7:0];
wire [7:0] ofmap_F = convolution_param2_reg[15:8]; 
wire [7:0] ofmap_M = convolution_param2_reg[23:16];


wire [ADDRESS_BITWIDTH:0] Waddress = (Wcounter < conv_padding_left)? 'd0: Wcounter-conv_padding_left;
wire [ADDRESS_BITWIDTH:0] Haddress = (Hcounter < conv_padding_top)? 'd0: Hcounter-conv_padding_top;

wire [ADDRESS_BITWIDTH:0] Ccounter, Ccounter_next;

wire [ADDRESS_BITWIDTH:0] ifmap_addr_bias = ifmap_W *(ifmap_H * Ccounter + Hcounter) + Wcounter;

wire [ADDRESS_BITWIDTH:0] filter_addr_bias = conv_kernel_size *(conv_kernel_size * Ccounter + Hcounter) + Wcounter;

wire [ADDRESS_BITWIDTH:0] ipsum_addr_bias = conv_kernel_size *(conv_kernel_size * Ccounter + Hcounter) + Wcounter;

parameter   SIDLE = 0,
            SCONFIG = 1,
            SPREREAD = 2,
            SSET_ID = 3,
            SSET_RAW = 4,
            SSET_LN_INFO = 11,
            SSET_PE_INFO = 12,
            SREADY = 13,
            SREAD_IFMAP = 14,
            SPUT_IFMAP = 15,
            SREAD_FILTER = 16,
            SPUT_FILTER = 17,
            SREAD_IPSUM = 18,
            SPUT_IPSUM = 19,
            SGET_OPSUM = 20,
            SWRITE_OPSUM = 21,
            SPUT_POOLING = 22,
            SGET_POOLING = 23,
            SDONE = 31;

parameter   READ_TO_SCAN_ID = 0,
            READ_TO_SCAN_ROW = 1,
            READ_TO_SCAN_LN = 2,
            READ_TO_SCAN_PE = 3,
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
        counter <= 'd0;
        computation_config_reg;
    end else begin
        state <= state_next;
        counter <= counter_next;
    end
end

/* config data and starting address info */
always @(posedge clk ) begin
    if(~rst) begin
        address_ifmap_reg <= 'd0;
        address_filter_reg <= 'd0;
        address_ipsum_reg <= 'd0;
        address_opsum_reg <= 'd0;
        address_scan_chain_reg <= 'd0;
        convolution_param1_reg <= 'd0;
        convolution_param2_reg <= 'd0;
    end else if(state == SIDLE && start)begin
        address_ifmap_reg <= address_ifmap;
        address_filter_reg <= address_filter;
        address_ipsum_reg <= address_ipsum;
        address_opsum_reg <= address_opsum;
        address_scan_chain_reg <= address_scan_chain;
        convolution_param1_reg <= convolution_param1;
        convolution_param2_reg <= convolution_param2;
    end
end


/* Combinational Circuit */
always @(*) begin
    state_next = SIDLE;
    counter_next = counter;
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
            state_next =  SSET_ID;
            counter_next = counter + 'd1;
            read_from_select = READ_FROM_IARG_BUFFER;
            read_address = scan_chain_start_addr+counter;
            ram_enable = 1;
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
            state_next = SREAD_FILTER
            counter_next = 'd0; 
        end
        SREAD_FILTER: begin  // TBD
            counter_next = SREADY;
            read_from_select = READ_FROM_IARG_BUFFER;
            read_address = filter_start_addr+counter;
            ram_enable = 1;
        end
        SPUT_FILTER: begin
            filter_enable = 1;
            if(filter_ready)begin
                state_next = SREAD_FILTER;
            end
        end
        SREAD_IFMAP: begin
            
        end
        SPUT_IFMAP: begin
            
        end
        SREAD_IPSUM: begin
            
        end
        SPUT_IPSUM: begin
            
        end
        SGET_OPSUM: begin
            
        end
        SWRITE_OPSUM: begin
            
        end
        SPUT_POOLING: begin
            
        end
        SGET_POOLING: begin
            
        end
        SDONE: begin
            
        end
        default: state_next = SIDLE;
    endcase
end
    
endmodule