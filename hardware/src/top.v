`include "./src/controller/top_controller.v"
`include "./src/pe_array/MappingConfig.v"
module top #(
    parameter   SCALAR_LEN = 32,
                ADDRESS_BITWIDTH = 32;
                DATA_BITWIDTH = 32;
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
                IFMAP_NUM = 1,
                FILTER_NUM = 4,
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
    output [ADDRESS_BITWIDTH-1:0] IARG_address,
    output [DATA_BITWIDTH-1:0] IARG_wdata,
    input [DATA_BITWIDTH-1:0] IARG_rdata,
    output IARG_e;
    output [3:0] IARG_we;

    output [ADDRESS_BITWIDTH-1:0] OARG_address,
    output [DATA_BITWIDTH-1:0] OARG_wdata,
    input [DATA_BITWIDTH-1:0] OARG_rdata,
    output OARG_e;
    output [3:0] OARG_we;
);

wire enable_pe_array;
wire set_pe_info;
wire set_ln_info;
wire set_id;
wire set_row;
wire[IFMAP_GIN_ROW_LEN-1:0]   ifmap_row_id; // IFMAP X-Bus
wire[IFMAP_GIN_ID_LEN-1:0]    ifmap_col_id; // IFMAP Y-Bus PE id
wire[FILTER_GIN_ROW_LEN-1:0]  filter_row_id; // FILTER X-Bus
wire[FILTER_GIN_ID_LEN-1:0]   filter_col_id; // FILTER Y-Bus PE id
wire[IPSUM_GIN_ROW_LEN-1:0]   ipsum_row_id; // IPSUM X-Bus
wire[IPSUM_GIN_ID_LEN-1:0]    ipsum_col_id; // IPSUM Y-Bus PE id
wire[OPSUM_GON_ROW_LEN-1:0]   opsum_row_id; // OPSUM X-Bus
wire[OPSUM_GON_ID_LEN-1:0]    opsum_col_id; // OPSUM Y-Bus PE id
wire ifmap_enable, ifmap_ready;
wire filter_enable, filter_ready;
wire ipsum_enable, ipsum_ready;
wire opsum_ready, opsum_enable;


wire [2:0] ctrl_read_to_select;
wire ctrl_read_from_select;
wire [ADDRESS_BITWIDTH-1:] ctrl_read_address;
wire [1:0] ctrl_write_from_select; 
wire ctrl_write_to_select;
wire [ADDRESS_BITWIDTH-1:] ctrl_write_address;
wire ctrl_ram_enable;
wire [3:0] ctrl_ram_we;

wire [ID_LEN-1:0] id_scan_in;
wire [ROW_LEN-1:0] row_scan_in;
wire [`CONFIG_BIT:0] pe_config_in;
wire [XBUS_NUMS-1:0] LN_config_in;


reg [DATA_BITWIDTH-1:0] read_buffer;
reg [DATA_BITWIDTH-1:0] write_buffer;

reg [IFMAP_DATA_SIZE*IFMAP_NUM-1:0] ifmap_value;
reg [FILTER_DATA_SIZE*FILTER_NUM-1:0] filter_value;
reg [PSUM_DATA_SIZE*FILTER_NUM-1:0] ipsum_value;

/* Read Wrtie Mux */


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
    .ADDRESS_BITWIDTH(ADDRESS_BITWIDTH),
)controller_0(
    .rst(rst),
    .clk(clk),
    /* Signal */
    .start(start), 
    .finish(finish),
    .enable_pe_array(enable_pe_array),
    /* scalar configuration */
    .computation_config(scalar0_config),
    .convolution_param1(scalar1_config),
    .convolution_param2(scalar2_config),
    .address_ifmap(scalar3_config),
    .address_filter(scalar4_config),
    .address_ipsum(scalar5_config),
    .address_opsum(scalar6_config),
    .address_scan_chain(scalar7_config),
    /* scan chain information */
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
    ./* PE param */
    .IFMAP_SPAD_SIZE(IFMAP_SPAD_SIZE),
    .FILTER_SPAD_SIZE(FILTER_SPAD_SIZE),
    .PSUM_SPAD_SIZE(PSUM_SPAD_SIZE),
    .CONFIG_Q_BIT(CONFIG_Q_BIT), // channel count config
    .CONFIG_P_BIT(CONFIG_P_BIT), // kernel count config
    .CONFIG_U_BIT(CONFIG_U_BIT), // stride config
    .CONFIG_S_BIT(CONFIG_S_BIT), // filter width config
    .CONFIG_F_BIT(CONFIG_F_BIT), // ifmap width config
    .CONFIG_W_BIT(CONFIG_W_BIT), // ofmap width config
)PEArray_0(
    .rst(rst),
    .clk(clk),
    /* Scan Chain */
    .set_id(set_id),
    .id_scan_in(id_scan_in),
    .id_scan_out()
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
    .ifmap_value(read_buffer),
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
    .opsum_enable,
    .opsum_ready,
    .opsum_row_tag,
    .opsum_col_tag,
    .opsum_value,

    /* PE config */
    .enable(enable_pe_array),
    .set_info(set_pe_info),
    .config_q(),
    .config_p(),
    .config_U(),
    .config_S(),
    .config_F(),
    .config_W(),
);


/* Pooling */


    
endmodule