/*
    PEArray

    (Eyeriss based)
*/
`include "./src/pe_array/GIN/GINXBus.v"
`include "./src/pe_array/GON/GONXBus.v"

module PEArray #(
    parameter XBUS_NUMS = 12,
              PE_NUMS = 14,
) (
    input clk,
    input rst,
);

/* IFMAP GIN */
GIN #(
    .XBUS_NUMS(XBUS_NUMS),
    .PE_NUMS(PE_NUMS)
    ID_LEN = 5,
    ROW_LEN = 4,
    VALUE_LEN = 32
) IFMAP_GIN(
    .clk(clk),
    .rst(rst),
    
    input enable,
    output wire ready,
    input [ROW_LEN-1:0] row_tag,
    input [ID_LEN-1:0] col_tag,
    input [VALUE_LEN-1:0] value,

    /* config */
    input set_id,
    input [ID_LEN-1:0] id_scan_in,
    output wire [ID_LEN-1:0] id_scan_out,

    input set_row,
    input [ROW_LEN-1:0] row_scan_in,
    output wire [ROW_LEN-1:0] row_scan_out,

    /* PE IO */
    input pe_ready [PE_NUMS*XBUS_NUMS-1:0],
    output [VALUE_LEN:0] pe_enable_data [PE_NUMS*XBUS_NUMS-1:0]
    
);

/* FILTER GIN */
GIN #(
    .XBUS_NUMS(XBUS_NUMS),
    .PE_NUMS(PE_NUMS)
    ID_LEN = 5,
    ROW_LEN = 4,
    VALUE_LEN = 32
) FILTER_GIN(
    .clk(clk),
    .rst(rst),
    
    input enable,
    output wire ready,
    input [ROW_LEN-1:0] row_tag,
    input [ID_LEN-1:0] col_tag,
    input [VALUE_LEN-1:0] value,

    /* config */
    input set_id,
    input [ID_LEN-1:0] id_scan_in,
    output wire [ID_LEN-1:0] id_scan_out,

    input set_row,
    input [ROW_LEN-1:0] row_scan_in,
    output wire [ROW_LEN-1:0] row_scan_out,

    /* PE IO */
    input pe_ready [PE_NUMS*XBUS_NUMS-1:0],
    output [VALUE_LEN:0] pe_enable_data [PE_NUMS*XBUS_NUMS-1:0]
    
);
/* IPSUM GIN */
GIN #(
    .XBUS_NUMS(XBUS_NUMS),
    .PE_NUMS(PE_NUMS)
    ID_LEN = 5,
    ROW_LEN = 4,
    VALUE_LEN = 32
) IPSUM_GIN(
    .clk(clk),
    .rst(rst),
    
    input enable,
    output wire ready,
    input [ROW_LEN-1:0] row_tag,
    input [ID_LEN-1:0] col_tag,
    input [VALUE_LEN-1:0] value,

    /* config */
    input set_id,
    input [ID_LEN-1:0] id_scan_in,
    output wire [ID_LEN-1:0] id_scan_out,

    input set_row,
    input [ROW_LEN-1:0] row_scan_in,
    output wire [ROW_LEN-1:0] row_scan_out,

    /* PE IO */
    input pe_ready [PE_NUMS*XBUS_NUMS-1:0],
    output [VALUE_LEN:0] pe_enable_data [PE_NUMS*XBUS_NUMS-1:0]
    
);
/* OPSUM GON */
GON #(
    parameter   XBUS_NUMS = 12,
                PE_NUMS = 14,
                ID_LEN = 5,
                ROW_LEN = 4,
                VALUE_LEN = 32
) OPSUM_GON(
    input clk,
    input rst,
    
    output wire enable,
    input ready,
    input [ROW_LEN-1:0] row_tag,
    input [ID_LEN-1:0] col_tag,
    output wire [VALUE_LEN-1:0] value,

    /* config */
    input set_id,
    input [ID_LEN-1:0] id_scan_in,
    output wire [ID_LEN-1:0] id_scan_out,

    input set_row,
    input [ROW_LEN-1:0] row_scan_in,
    output wire [ROW_LEN-1:0] row_scan_out,

    /* PE IO */
    output pe_ready [PE_NUMS*XBUS_NUMS-1:0],
    input [VALUE_LEN:0] pe_enable_data [PE_NUMS*XBUS_NUMS-1:0]
    
);
/* Local Network */

genvar i,j;
for (i = 0;i < XBUS_NUMS-1; i = i + 1) begin
    for (j = 0;j < PE_NUMS; j = j + 1) begin
        LN #(
                .CONNECT_X1(j),
                .CONNECT_Y1(i),
                .CONNECT_X2(j),
                .CONNECT_Y2(i+1);
        )LN_0(
            .clk(clk),
            .rst(rst),

            .set_info(set_info),
            .connect_flag(), // connect Local Network

            /* ipsum to PE */
            output [IPSUM_NUM*DATA_SIZE:0] ipsum, // data + enable
            input ipsum_ready,
            /* opsum from PE */
            output opsum_ready,
            input  [OPSUM_NUM*DATA_SIZE:0] opsum, // data + enable
            /* ipsum from bus */
            input [IPSUM_NUM*DATA_SIZE:0] ipsum_bus, // data + enable
            output ipsum_ready_bus,
            /* ipsum to  bus */
            input opsum_ready_bus,
            output [OPSUM_NUM*DATA_SIZE:0] opsum_bus, // data + enable
        );
    end
end

/* PEs */
genvar i,j;
for (i = 0;i < XBUS_NUMS; i = i + 1) begin
    for (j = 0;j < PE_NUMS; j = j + 1) begin
        PEWrapper #(
            .MA_X(j),
            .MA_Y(i)
        )PEWrapper_0(
            .clk(clk),
            .rst(rst),
            .enable(),
            /* Wrapper */
            .ifmap_in(pe_enable_data[i*PE_NUMS+j]), // data + enable
            .ifmap_ready(pe_ready[i*PE_NUMS+j]),

            .filter_in(), // data + enable
            .filter_ready(),

            .ipsum_in(), // data + enable
            .ipsum_ready(),

            .opsum_ready(),
            .opsum_out(), // data + enable

            .config_in()
        );
    end
end
    
endmodule