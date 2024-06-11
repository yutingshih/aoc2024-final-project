/*
    PEArray

    (Eyeriss based)
    
    Scan Chain 
    |- set Row  : FILTER(GIN) / IFMAP(GIN) / IPSUM(GIN) / OPSUM (GON)
    |- set ID   : FILTER(GIN) / IFMAP(GIN) / IPSUM(GIN) / OPSUM (GON)

*/
`include "./src/pe_array/GIN/GIN.v"
`include "./src/pe_array/GON/GON.v"
`include "./src/pe_array/LN/LN.v"
`include "./src/pe_array/PEWrapper.v"
`include "./src/pe_array/MappingConfig.v"

module PEArray #(
              /* BUS-PE param */
    parameter XBUS_NUMS = 12,
              PE_NUMS = 14,
              IFMAP_DATA_SIZE = 8,
              FILTER_DATA_SIZE = 8,
              PSUM_DATA_SIZE = 32,
              IFMAP_NUM = 1,
              FILTER_NUM = 4,
              IPSUM_NUM = 4,
              OPSUM_NUM = 4,
              ID_LEN = 5,
              ROW_LEN = 4,
              /* PE param */
              IFMAP_SPAD_SIZE = 12,
              FILTER_SPAD_SIZE = 224,
              PSUM_SPAD_SIZE = 24,
              CONFIG_Q_BIT = 3, // channel count config
              CONFIG_P_BIT = 5, // kernel count config
              CONFIG_U_BIT = 4, // stride config
              CONFIG_S_BIT = 4, // filter width config
              CONFIG_F_BIT = 12, // ifmap width config
              CONFIG_W_BIT = 12 // ofmap width config
) (
    input clk,
    input rst,
    
    /* Scan Chain */
    input set_id,
    input [ID_LEN-1:0] id_scan_in,
    output wire [ID_LEN-1:0] id_scan_out,

    input set_row,
    input [ROW_LEN-1:0] row_scan_in,
    output wire [ROW_LEN-1:0] row_scan_out,

    input set_ln_info,
    input [XBUS_NUMS-1:0] LN_config_in,

    /* Data Flow in - ifmap */
    input ifmap_enable,
    output wire ifmap_ready,
    input [ROW_LEN-1:0] ifmap_row_tag,
    input [ID_LEN-1:0] ifmap_col_tag,
    input [IFMAP_DATA_SIZE*IFMAP_NUM-1:0] ifmap_value,
    /* Data Flow in - filter */
    input filter_enable,
    output wire filter_ready,
    input [ROW_LEN-1:0] filter_row_tag,
    input [ID_LEN-1:0] filter_col_tag,
    input [FILTER_DATA_SIZE*FILTER_NUM-1:0] filter_value,
    /* Data Flow in - ipsum */
    input ipsum_enable,
    output wire ipsum_ready,
    input [ROW_LEN-1:0] ipsum_row_tag,
    input [ID_LEN-1:0] ipsum_col_tag,
    input [PSUM_DATA_SIZE*IPSUM_NUM-1:0] ipsum_value,
    /* Data Flow out - opsum */
    output wire opsum_enable,
    input opsum_ready,
    input [ROW_LEN-1:0] opsum_row_tag,
    input [ID_LEN-1:0] opsum_col_tag,
    output wire [PSUM_DATA_SIZE*OPSUM_NUM-1:0] opsum_value,

    /* PE config */
    input enable,
    input set_pe_info,
    input [CONFIG_Q_BIT-1:0] config_q,
    input [CONFIG_P_BIT-1:0] config_p,
    input [CONFIG_U_BIT-1:0] config_U,
    input [CONFIG_S_BIT-1:0] config_S,
    input [CONFIG_F_BIT-1:0] config_F,
    input [CONFIG_W_BIT-1:0] config_W
);

/* scan chain */
wire [ID_LEN-1:0] id_scan_ifmapGIN_to_filterGIN;
wire [ID_LEN-1:0] id_scan_filterGIN_to_ipsumGIN;
wire [ID_LEN-1:0] id_scan_ipsumGIN_to_opsumGON;

wire [ROW_LEN-1:0] row_scan_ifmapGIN_to_filterGIN;
wire [ROW_LEN-1:0] row_scan_filterGIN_to_ipsumGIN;
wire [ROW_LEN-1:0] row_scan_ipsumGIN_to_opsumGON;

/* PE-BUS wire */
wire ifmap_bus_ready[PE_NUMS*XBUS_NUMS-1:0] ;
wire [IFMAP_DATA_SIZE*IFMAP_NUM:0] ifmap_bus_enable_data [XBUS_NUMS*PE_NUMS - 1:0];

wire filter_bus_ready[PE_NUMS*XBUS_NUMS-1:0] ;
wire [FILTER_DATA_SIZE*FILTER_NUM:0] filter_bus_enable_data [XBUS_NUMS*PE_NUMS - 1:0];

wire ipsum_bus_ready[PE_NUMS*XBUS_NUMS-1:0]; 
wire [PSUM_DATA_SIZE*IPSUM_NUM:0] ipsum_bus_enable_data [XBUS_NUMS*PE_NUMS - 1:0];

wire opsum_bus_ready[PE_NUMS*XBUS_NUMS-1:0] ;
wire [PSUM_DATA_SIZE*OPSUM_NUM:0] opsum_bus_enable_data [XBUS_NUMS*PE_NUMS - 1:0];

/* PE-Local Network wire */
wire ipsum_LN_ready[PE_NUMS*XBUS_NUMS-1:0]; 
wire [PSUM_DATA_SIZE*IPSUM_NUM:0] ipsum_LN_enable_data [XBUS_NUMS*PE_NUMS - 1:0];

wire opsum_LN_ready[PE_NUMS*XBUS_NUMS-1:0] ;
wire [PSUM_DATA_SIZE*OPSUM_NUM:0] opsum_LN_enable_data [XBUS_NUMS*PE_NUMS - 1:0];

/* IFMAP GIN */
GIN #(
    .XBUS_NUMS(XBUS_NUMS),
    .PE_NUMS(PE_NUMS),
    .ID_LEN(ID_LEN),
    .ROW_LEN(ROW_LEN),
    .VALUE_LEN(IFMAP_DATA_SIZE*IFMAP_NUM)
) IFMAP_GIN(
    .clk(clk),
    .rst(rst),
    
    .enable(ifmap_enable),
    .ready(ifmap_ready),
    .row_tag(ifmap_row_tag),
    .col_tag(ifmap_col_tag),
    .value(ifmap_value),

    /* config */
    .set_id(set_id),
    .id_scan_in(id_scan_in),
    .id_scan_out(id_scan_ifmapGIN_to_filterGIN),

    .set_row(set_row),
    .row_scan_in(row_scan_in),
    .row_scan_out(row_scan_ifmapGIN_to_filterGIN),

    /* PE IO */
    .pe_ready(ifmap_bus_ready),
    .pe_enable_data(ifmap_bus_enable_data)
);

/* FILTER GIN */
GIN #(
    .XBUS_NUMS(XBUS_NUMS),
    .PE_NUMS(PE_NUMS),
    .ID_LEN(ID_LEN),
    .ROW_LEN(ROW_LEN),
    .VALUE_LEN(FILTER_DATA_SIZE*FILTER_NUM)
) FILTER_GIN(
    .clk(clk),
    .rst(rst),
    
    .enable(filter_enable),
    .ready(filter_ready),
    .row_tag(filter_row_tag),
    .col_tag(filter_col_tag),
    .value(filter_value),

    /* config */
    .set_id(set_id),
    .id_scan_in(id_scan_ifmapGIN_to_filterGIN),
    .id_scan_out(id_scan_filterGIN_to_ipsumGIN),

    .set_row(set_row),
    .row_scan_in(row_scan_ifmapGIN_to_filterGIN),
    .row_scan_out(row_scan_filterGIN_to_ipsumGIN),

    /* PE IO */
    .pe_ready(filter_bus_ready),
    .pe_enable_data(filter_bus_enable_data)
    
);
/* IPSUM GIN */
GIN #(
    .XBUS_NUMS(XBUS_NUMS),
    .PE_NUMS(PE_NUMS),
    .ID_LEN(ID_LEN),
    .ROW_LEN(ROW_LEN),
    .VALUE_LEN(PSUM_DATA_SIZE*IPSUM_NUM)
) IPSUM_GIN(
    .clk(clk),
    .rst(rst),
    
    .enable(ipsum_enable),
    .ready(ipsum_ready),
    .row_tag(ipsum_row_tag),
    .col_tag(ipsum_col_tag),
    .value(ipsum_value),

    /* config */
    .set_id(set_id),
    .id_scan_in(id_scan_filterGIN_to_ipsumGIN),
    .id_scan_out(id_scan_ipsumGIN_to_opsumGON),

    .set_row(set_row),
    .row_scan_in(row_scan_filterGIN_to_ipsumGIN),
    .row_scan_out(row_scan_ipsumGIN_to_opsumGON),

    /* PE IO */
    .pe_ready(ipsum_bus_ready),
    .pe_enable_data(ipsum_bus_enable_data)
    
);
/* OPSUM GON */
GON #(
    .XBUS_NUMS(XBUS_NUMS),
    .PE_NUMS(PE_NUMS),
    .ID_LEN(ID_LEN),
    .ROW_LEN(ROW_LEN),
    .VALUE_LEN(PSUM_DATA_SIZE*OPSUM_NUM)
) OPSUM_GON(
    .clk(clk),
    .rst(rst),
    
    .enable(opsum_enable),
    .ready(opsum_ready),
    .row_tag(opsum_row_tag),
    .col_tag(opsum_col_tag),
    .value(opsum_value),

    /* config */
    .set_id(set_id),
    .id_scan_in(id_scan_ipsumGIN_to_opsumGON),
    .id_scan_out(id_scan_out),

    .set_row(set_row),
    .row_scan_in(row_scan_ipsumGIN_to_opsumGON),
    .row_scan_out(row_scan_out),

    /* PE IO */
    .pe_ready(opsum_bus_ready),
    .pe_enable_data(opsum_bus_enable_data)
);

/* Local Network */
genvar i,j;
for (i = 0;i < XBUS_NUMS-1; i = i + 1) begin
    for (j = 0;j < PE_NUMS; j = j + 1) begin
        LN #(
                .CONNECT_X1(j),
                .CONNECT_Y1(i),
                .CONNECT_X2(j),
                .CONNECT_Y2(i+1),
                .PSUM_DATA_SIZE(PSUM_DATA_SIZE),
                .IPSUM_NUM(IPSUM_NUM),
                .OPSUM_NUM(OPSUM_NUM) /* (j,i+1) -> (j,i)*/
        )LN_0(
            .clk(clk),
            .rst(rst),

            .set_info(set_ln_info),
            .connect_flag(LN_config_in[i]), // connect Local Network

            /* ipsum to PE */
            .ipsum(ipsum_LN_enable_data[i*PE_NUMS+j]), // data + enable
            .ipsum_ready(ipsum_LN_ready[i*PE_NUMS+j]),
            /* opsum from PE */
            .opsum_ready(opsum_LN_ready[(i+1)*PE_NUMS+j]),
            .opsum(opsum_LN_enable_data[(i+1)*PE_NUMS+j]), // data + enable
            /* ipsum from bus */
            .ipsum_bus(ipsum_bus_enable_data[i*PE_NUMS+j]), // data + enable
            .ipsum_ready_bus(ipsum_bus_ready[i*PE_NUMS+j]),
            /* opsum to  bus */
            .opsum_ready_bus(opsum_bus_ready[(i+1)*PE_NUMS+j]),
            .opsum_bus(opsum_bus_enable_data[(i+1)*PE_NUMS+j]) // data + enable
        );
    end
end

/* PEs */
for (i = 0;i < XBUS_NUMS; i = i + 1) begin
    for (j = 0;j < PE_NUMS; j = j + 1) begin
        PEWrapper #(
            .IFMAP_SPAD_SIZE(IFMAP_SPAD_SIZE),
            .FILTER_SPAD_SIZE(FILTER_SPAD_SIZE),
            .PSUM_SPAD_SIZE(PSUM_SPAD_SIZE),
            .IFMAP_DATA_SIZE(IFMAP_DATA_SIZE),
            .FILTER_DATA_SIZE(FILTER_DATA_SIZE),
            .PSUM_DATA_SIZE(PSUM_DATA_SIZE),
            .IFMAP_NUM(IFMAP_NUM),
            .FILTER_NUM(FILTER_NUM),
            .IPSUM_NUM(IPSUM_NUM),
            .OPSUM_NUM(OPSUM_NUM),
            .CONFIG_Q_BIT(CONFIG_Q_BIT), // channel count config
            .CONFIG_P_BIT(CONFIG_P_BIT), // kernel count config
            .CONFIG_U_BIT(CONFIG_U_BIT), // stride config
            .CONFIG_S_BIT(CONFIG_S_BIT), // filter width config
            .CONFIG_F_BIT(CONFIG_F_BIT), // ifmap width config
            .CONFIG_W_BIT(CONFIG_W_BIT), // ofmap width config
            .MA_X(j),
            .MA_Y(i)
        )PEWrapper_0(
            .clk(clk),
            .rst(rst),
            .enable(enable),
            /* Wrapper */
            .ifmap_in(ifmap_bus_enable_data[i*PE_NUMS+j]), // data + enable
            .ifmap_ready(ifmap_bus_ready[i*PE_NUMS+j]),

            .filter_in(filter_bus_enable_data[i*PE_NUMS+j]), // data + enable
            .filter_ready(filter_bus_ready[i*PE_NUMS+j]),

            .ipsum_in(ipsum_LN_enable_data[i*PE_NUMS+j]), // data + enable
            .ipsum_ready(ipsum_LN_ready[i*PE_NUMS+j]),

            .opsum_ready(opsum_LN_ready[i*PE_NUMS+j]),
            .opsum_out(opsum_LN_enable_data[i*PE_NUMS+j]), // data + enable

            .config_in({set_pe_info,config_W,config_F,config_S,config_U,config_p,config_q}) // concat
        );
    end
end
    
endmodule