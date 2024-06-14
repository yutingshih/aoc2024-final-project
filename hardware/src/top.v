`include "./src/controller/top_controller.v"
`include "./src/pe_array/MappingConfig.v"
module top #(
    parameter   SCALAR_LEN = 32,
                ADDRESS_BITWIDTH = 32,
                DATA_BITWIDTH = 32,
                XBUS_NUMS = 12,
                PE_NUMS = 14,
                IFMAP_GIN_ROW_LEN = 4,
                IFMAP_GIN_ID_LEN = 5,
                FILTER_GIN_ROW_LEN = 4,
                FILTER_GIN_ID_LEN = 5,
                IPSUM_GIN_ROW_LEN = 4,
                IPSUM_GIN_ID_LEN = 5,
                OPSUM_GON_ROW_LEN = 4,
                OPSUM_GON_ID_LEN = 5,
                CONFIG_BITWIDTH = 32,
                IFMAP_DATA_SIZE = 8,
                FILTER_DATA_SIZE = 16,
                PSUM_DATA_SIZE = 32,
                FIXPOINT_LEN = 8,
                IFMAP_NUM = 4,
                FILTER_NUM = 1,
                IPSUM_NUM = 4,
                OPSUM_NUM = 4,
                ID_LEN = 5,
                ROW_LEN = 4,
                IFMAP_SPAD_SIZE = 12,
                FILTER_SPAD_SIZE = 224,
                PSUM_SPAD_SIZE = 24,
                CONFIG_Q_BIT = 2, // channel count config
                CONFIG_P_BIT = 5, // kernel count config
                CONFIG_U_BIT = 4, // stride config
                CONFIG_S_BIT = 4, // filter width config
                CONFIG_F_BIT = 12, // ifmap width config
                CONFIG_W_BIT = 12 // ofmap width config
)( 
    input clk,
    input rst, /* reset when low */

    input start,
    output finish,


    /* scalar config */
    input [SCALAR_LEN-1:0] scalar0_config,
    input [SCALAR_LEN-1:0] scalar1_config,
    input [SCALAR_LEN-1:0] scalar2_config,
    input [SCALAR_LEN-1:0] scalar3_config,
    input [SCALAR_LEN-1:0] scalar4_config,
    input [SCALAR_LEN-1:0] scalar5_config,
    input [SCALAR_LEN-1:0] scalar6_config,
    input [SCALAR_LEN-1:0] scalar7_config,


    /* BRAM IO */
    output reg [ADDRESS_BITWIDTH-1:0] IARG_address,
    output reg[DATA_BITWIDTH-1:0] IARG_wdata,
    input [DATA_BITWIDTH-1:0] IARG_rdata,
    output reg IARG_e,
    output reg [3:0] IARG_we,

    output reg [ADDRESS_BITWIDTH-1:0] OARG_address,
    output reg [DATA_BITWIDTH-1:0] OARG_wdata,
    input [DATA_BITWIDTH-1:0] OARG_rdata,
    output reg OARG_e,
    output reg [3:0] OARG_we
);

wire enable_pe_array;
wire set_pe_info;
wire set_ln_info;
wire set_id;
wire set_row;
wire [IFMAP_GIN_ROW_LEN-1:0]   ifmap_row_id; // IFMAP X-Bus
wire [IFMAP_GIN_ID_LEN-1:0]    ifmap_col_id; // IFMAP Y-Bus PE id
wire [FILTER_GIN_ROW_LEN-1:0]  filter_row_id; // FILTER X-Bus
wire [FILTER_GIN_ID_LEN-1:0]   filter_col_id; // FILTER Y-Bus PE id
wire [IPSUM_GIN_ROW_LEN-1:0]   ipsum_row_id; // IPSUM X-Bus
wire [IPSUM_GIN_ID_LEN-1:0]    ipsum_col_id; // IPSUM Y-Bus PE id
wire [OPSUM_GON_ROW_LEN-1:0]   opsum_row_id; // OPSUM X-Bus
wire [OPSUM_GON_ID_LEN-1:0]    opsum_col_id; // OPSUM Y-Bus PE id
wire ifmap_enable, ifmap_ready;
wire filter_enable, filter_ready;
wire ipsum_enable, ipsum_ready;
wire opsum_ready, opsum_enable;


reg [DATA_BITWIDTH-1:0] read_wire, write_wrie;

wire [2:0] ctrl_read_to_select;
wire ctrl_read_from_select;
wire [ADDRESS_BITWIDTH-1:0] ctrl_read_address;
wire [1:0] ctrl_write_from_select; 
wire ctrl_write_to_select;
wire [ADDRESS_BITWIDTH-1:0] ctrl_write_address;
wire ctrl_ram_enable;
wire [3:0] ctrl_ram_we;

wire [ID_LEN-1:0] id_scan_in;
wire [ROW_LEN-1:0] row_scan_in;
wire [XBUS_NUMS-1:0] LN_config_in;

reg [CONFIG_BITWIDTH-1:0] pe_config_reg [2:0];

wire [2:0]  config_q = pe_config_reg[2][2:0];
wire [4:0]  config_p = pe_config_reg[2][7:3];
wire [4:0]  config_U = pe_config_reg[0][31:28];
wire [4:0]  config_S = pe_config_reg[1][31:28];
wire [7:0]  config_F = pe_config_reg[1][7:0];
wire [7:0]  config_W = pe_config_reg[0][7:0];
wire [7:0]  config_H = pe_config_reg[0][15:8];
wire [7:0]  config_E = pe_config_reg[1][15:8];
wire [11:0]  config_C = pe_config_reg[0][27:16];
wire [11:0]  config_M = pe_config_reg[1][27:16];
wire [4:0]  config_t = pe_config_reg[2][11:8];
wire [4:0]  config_r = pe_config_reg[2][15:12];

/* Read Wrtie Mux */
parameter   READ_TO_PE_CONFIG = 0,
            READ_TO_SCAN_ID = 1,
            READ_TO_SCAN_ROW = 2,
            READ_TO_SCAN_LN = 3,
            READ_TO_IFMAPGIN = 4,
            READ_TO_FILTERGIN = 5,
            READ_TO_IPSUMGIN = 6,
            READ_TO_POOLING = 7;

parameter   READ_FROM_IARG_BUFFER = 0,
            READ_FROM_OARG_BUFFER = 1;

parameter   WRITE_FROM_OPSUMGON = 0,
            WRITE_FROM_RELU = 1,
            WRITE_FROM_POOLING = 2;

parameter   WRITE_TO_OARG_BUFFER = 0,
            WRITE_TO_IARG_BUFFER = 1;

wire [3:0] ctrl_ifmap_buffer_select; // one-hot encode
wire [3:0] ctrl_ipsum_buffer_select; // one-hot encode
wire [1:0] ctrl_opsum_buffer_select; // index
wire ctrl_padding;
wire [1:0] ctrl_pe_config_id;

reg [IFMAP_DATA_SIZE-1:0] ifmap_value_reg [IFMAP_NUM-1:0];
reg [FILTER_DATA_SIZE-1:0] filter_value_reg [FILTER_NUM-1:0];
reg [PSUM_DATA_SIZE-1:0] ipsum_value_reg [IPSUM_NUM-1:0];
reg [PSUM_DATA_SIZE-1:0] opsum_value_reg [OPSUM_NUM-1:0];

wire [IFMAP_DATA_SIZE*IFMAP_NUM-1:0] ifmap_value = {ifmap_value_reg[0],ifmap_value_reg[1],ifmap_value_reg[2],ifmap_value_reg[3]};
wire [FILTER_DATA_SIZE*FILTER_NUM-1:0] filter_value = filter_value_reg[0];
wire [PSUM_DATA_SIZE*IPSUM_NUM-1:0] ipsum_value = {ipsum_value_reg[0],ipsum_value_reg[1],ipsum_value_reg[2],ipsum_value_reg[3]};
wire [PSUM_DATA_SIZE*IPSUM_NUM-1:0] opsum_value;



always @(*) begin
    IARG_address = (ctrl_read_from_select==READ_FROM_IARG_BUFFER)? ctrl_read_address:0;
    IARG_wdata = 0;
    IARG_e = (ctrl_read_from_select==READ_FROM_IARG_BUFFER)?1:0;
    IARG_we = 0;

    read_wire = (ctrl_padding)?0:IARG_address;

    OARG_address = ctrl_write_address;
    OARG_we = ctrl_ram_we;
    OARG_e = (ctrl_write_to_select==WRITE_TO_OARG_BUFFER)?1:0;
    OARG_wdata = opsum_value_reg[ctrl_opsum_buffer_select];
end

always @(posedge clk) begin
    if(~rst) begin
        filter_value_reg[0] <= 0;
        ifmap_value_reg[0] <= 0;
        ifmap_value_reg[1] <= 0;
        ifmap_value_reg[2] <= 0;
        ifmap_value_reg[3] <= 0;
        ipsum_value_reg[0] <= 0;
        ipsum_value_reg[1] <= 0;
        ipsum_value_reg[2] <= 0;
        ipsum_value_reg[3] <= 0;
        pe_config_reg[0] <= 0;
        pe_config_reg[1] <= 0;
        pe_config_reg[2] <= 0;
    end else begin
        if(ctrl_read_to_select == READ_TO_PE_CONFIG) begin
            pe_config_reg[ctrl_pe_config_id] <= read_wire;
        end
        if(ctrl_read_to_select == READ_TO_FILTERGIN) begin
            filter_value_reg[0] <= read_wire;
        end
        if(ctrl_read_to_select == READ_TO_IFMAPGIN) begin
            ifmap_value_reg[0] <= (ctrl_ifmap_buffer_select[0])?read_wire[IFMAP_DATA_SIZE-1:0]:ifmap_value_reg[0];
            ifmap_value_reg[1] <= (ctrl_ifmap_buffer_select[1])?read_wire[IFMAP_DATA_SIZE-1:0]:ifmap_value_reg[1];
            ifmap_value_reg[2] <= (ctrl_ifmap_buffer_select[2])?read_wire[IFMAP_DATA_SIZE-1:0]:ifmap_value_reg[2];
            ifmap_value_reg[3] <= (ctrl_ifmap_buffer_select[3])?read_wire[IFMAP_DATA_SIZE-1:0]:ifmap_value_reg[3];
        end
        if(ctrl_read_to_select == READ_TO_IPSUMGIN) begin
            ipsum_value_reg[0] <= (ctrl_ipsum_buffer_select[0])?read_wire[IFMAP_DATA_SIZE-1:0]:ipsum_value_reg[0];
            ipsum_value_reg[1] <= (ctrl_ipsum_buffer_select[1])?read_wire[IFMAP_DATA_SIZE-1:0]:ipsum_value_reg[1];
            ipsum_value_reg[2] <= (ctrl_ipsum_buffer_select[2])?read_wire[IFMAP_DATA_SIZE-1:0]:ipsum_value_reg[2];
            ipsum_value_reg[3] <= (ctrl_ipsum_buffer_select[3])?read_wire[IFMAP_DATA_SIZE-1:0]:ipsum_value_reg[3];
        end
        if(ctrl_write_from_select == WRITE_FROM_OPSUMGON) begin
            opsum_value_reg[0] <= opsum_value[PSUM_DATA_SIZE-1:0];
            opsum_value_reg[1] <= opsum_value[PSUM_DATA_SIZE*2-1:PSUM_DATA_SIZE];
            opsum_value_reg[2] <= opsum_value[PSUM_DATA_SIZE*3-1:PSUM_DATA_SIZE*2];
            opsum_value_reg[3] <= opsum_value[PSUM_DATA_SIZE*4-1:PSUM_DATA_SIZE*3];
        end
    end
end

controller #(
    .XBUS_NUMS(XBUS_NUMS),
    .PE_NUMS(PE_NUMS),
    .IFMAP_GIN_ROW_LEN(IFMAP_GIN_ROW_LEN),
    .IFMAP_GIN_ID_LEN(IFMAP_GIN_ID_LEN),
    .FILTER_GIN_ROW_LEN(FILTER_GIN_ROW_LEN),
    .FILTER_GIN_ID_LEN(FILTER_GIN_ID_LEN),
    .IPSUM_GIN_ROW_LEN(IPSUM_GIN_ROW_LEN),
    .IPSUM_GIN_ID_LEN(IPSUM_GIN_ID_LEN),
    .OPSUM_GON_ROW_LEN(OPSUM_GON_ROW_LEN),
    .OPSUM_GON_ID_LEN(OPSUM_GON_ID_LEN),
    .CONFIG_BITWIDTH(CONFIG_BITWIDTH),
    .ADDRESS_BITWIDTH(ADDRESS_BITWIDTH)
)controller_0(
    .rst(rst),
    .clk(clk),
    /* Signal */
    .start(start), 
    .finish(finish),
    .enable_pe_array(enable_pe_array),
    /* scalar configuration */
    .computation_config(scalar0_config),
    .address_ifmap(scalar1_config),
    .address_filter(scalar2_config),
    .address_ipsum(scalar3_config),
    .address_opsum(scalar4_config),
    .address_scan_chain(scalar5_config),
    /* scan chain information */
    .pe_config_id(ctrl_pe_config_id),
    .set_pe_info(set_pe_info),
    .set_ln_info(set_ln_info),
    .set_id(set_id),
    .set_row(set_row),
    /* NoC Control */
    .ifmap_row_id(ifmap_row_id), // IFMAP X-Bus
    .ifmap_col_id(ifmap_col_id), // IFMAP Y-Bus PE id
    .filter_row_id(filter_row_id), // FILTER X-Bus
    .filter_col_id(filter_col_id), // FILTER Y-Bus PE id
    .ipsum_row_id(ipsum_row_id), // IPSUM X-Bus
    .ipsum_col_id(ipsum_col_id), // IPSUM Y-Bus PE id
    .opsum_row_id(opsum_row_id), // OPSUM X-Bus
    .opsum_col_id(opsum_col_id), // OPSUM Y-Bus PE id
    .ifmap_enable(ifmap_enable),
    .filter_enable(filter_enable),
    .ipsum_enable(ipsum_enable),
    .opsum_ready(opsum_ready),
    .ifmap_ready(ifmap_ready),
    .filter_ready(filter_ready),
    .ipsum_ready(ipsum_ready),
    .opsum_enable(opsum_enable),
    .read_to_select(ctrl_read_to_select),
    .read_from_select(ctrl_read_from_select),
    .read_address(ctrl_read_address),
    .write_from_select(ctrl_write_from_select), 
    .write_to_select(ctrl_write_to_select),
    .write_address(ctrl_write_address),
    .ram_enable(ctrl_ram_enable),
    .ram_we(ctrl_ram_we),

    .ifmap_buffer_select(ctrl_ifmap_buffer_select), // one-hot encode
    .ipsum_buffer_select(ctrl_ipsum_buffer_select), // one-hot encode
    .opsum_buffer_select(ctrl_opsum_buffer_select), // index
    .padding(ctrl_padding),

    .config_q(config_q),
    .config_p(config_p),
    .config_U(config_U),
    .config_S(config_S),
    .config_F(config_F),
    .config_W(config_W),
    .config_H(config_H),
    .config_E(config_E),
    .config_C(config_C),
    .config_M(config_M),
    .config_t(config_t),
    .config_r(config_r)
);

PEArray #(
    /* BUS-PE param */
    .XBUS_NUMS(XBUS_NUMS),
    .PE_NUMS(PE_NUMS),
    .IFMAP_DATA_SIZE(IFMAP_DATA_SIZE),
    .FILTER_DATA_SIZE(FILTER_DATA_SIZE),
    .PSUM_DATA_SIZE(PSUM_DATA_SIZE),
    .IFMAP_NUM(IFMAP_NUM),
    .FILTER_NUM(FILTER_NUM),
    .IPSUM_NUM(IPSUM_NUM),
    .OPSUM_NUM(OPSUM_NUM),
    .ID_LEN(ID_LEN),
    .ROW_LEN(ROW_LEN),
    .IFMAP_SPAD_SIZE(IFMAP_SPAD_SIZE),
    .FILTER_SPAD_SIZE(FILTER_SPAD_SIZE),
    .PSUM_SPAD_SIZE(PSUM_SPAD_SIZE),
    .CONFIG_Q_BIT(CONFIG_Q_BIT), // channel count config
    .CONFIG_P_BIT(CONFIG_P_BIT), // kernel count config
    .CONFIG_U_BIT(CONFIG_U_BIT), // stride config
    .CONFIG_S_BIT(CONFIG_S_BIT), // filter width config
    .CONFIG_F_BIT(CONFIG_F_BIT), // ifmap width config
    .CONFIG_W_BIT(CONFIG_W_BIT) // ofmap width config
)PEArray_0(
    .rst(rst),
    .clk(clk),
    /* Scan Chain */
    .set_id(set_id),
    .id_scan_in(id_scan_in),
    .id_scan_out(),
    .set_row(set_row),
    .row_scan_in(row_scan_in),
    .row_scan_out(),
    .set_pe_info(set_pe_info),
    .pe_config_in(pe_config_in),
    .set_ln_info(set_ln_info),
    .LN_config_in(LN_config_in),

    /* Data Flow in - ifmap */
    .ifmap_enable(ifmap_enable),
    .ifmap_ready(ifmap_ready),
    .ifmap_row_tag(ifmap_row_id),
    .ifmap_col_tag(ifmap_col_id),
    .ifmap_value(ifmap_value),
    /* Data Flow in - filter */
    .filter_enable(filter_enable),
    .filter_ready(filter_ready),
    .filter_row_tag(filter_row_id),
    .filter_col_tag(filter_col_id),
    .filter_value(filter_value),
    /* Data Flow in - ipsum */
    .ipsum_enable(ipsum_enable),
    .ipsum_ready(ipsum_ready),
    .ipsum_row_tag(ipsum_row_id),
    .ipsum_col_tag(ipsum_col_id),
    .ipsum_value(ipsum_value),
    /* Data Flow out - opsum */
    .opsum_enable(opsum_enable),
    .opsum_ready(opsum_ready),
    .opsum_row_tag(opsum_row_id),
    .opsum_col_tag(opsum_col_id),
    .opsum_value(opsum_value),

    /* PE config */
    .enable(enable_pe_array),
    .set_pe_info(set_pe_info),
    .config_q(config_q),
    .config_p(config_p),
    .config_U(config_U),
    .config_S(config_S),
    .config_F(config_F),
    .config_W(config_W)
);





/* Pooling */


    
endmodule