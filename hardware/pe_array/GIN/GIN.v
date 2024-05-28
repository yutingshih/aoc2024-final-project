`include "./pe_array/GIN/GINBus.v"

module GIN #(
    parameter   XBUS_NUMS = 12,
                PE_NUMS = 14,
                ID_LEN = 5,
                ROW_LEN = 4,
                VALUE_LEN = 32
) (
    input clk,
    input rst,
    
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

    /* gather value and tag to YBus */
    wire [ROW_LEN+ID_LEN+VALUE_LEN:0] enable_tag_value = {enable, row_tag, col_tag, value};

    /* YBus - XBus connections */
    wire xbus_ready [XBUS_NUMS-1:0];
    wire [ID_LEN+VALUE_LEN:0] xbus_enable_data [XBUS_NUMS-1:0];

    /* YBus */
    GINBus #(
        .MASTER_NUMS(XBUS_NUMS),
        .ID_LEN(ROW_LEN),
        .VALUE_LEN(ID_LEN+VALUE_LEN)
    )YBus_0(
        .clk(clk),
        .rst(rst),
        
        /* Slave I/O */
        .ready(ready),
        .enable_tag_value(enable_tag_value),

        /* Master IO (to XBus)*/
        .master_ready(xbus_ready),
        .master_enable_data(xbus_enable_data),
        
        /* config */
        .set_id(set_row),
        .id_scan_in(row_scan_in),
        .id_scan_out(row_scan_out)
    );

    // id scan chain wire
    wire [ID_LEN-1:0] scan_chain [XBUS_NUMS:0];
    assign scan_chain[0] = id_scan_in;
    assign id_scan_out = scan_chain[XBUS_NUMS];

    /* XBuses */
    genvar i;
    for (i = 0;i < XBUS_NUMS; i = i + 1) begin
        GINBus #(
        .MASTER_NUMS(PE_NUMS),
        .ID_LEN(ID_LEN),
        .VALUE_LEN(VALUE_LEN),
        .MA_Y(i)
        )XBus_0(
            .clk(clk),
            .rst(rst),
            
            /* Slave I/O */
            .ready(xbus_ready[i]),
            .enable_tag_value(xbus_enable_data[i]),

            /* Master IO (to PEs)*/
            .master_ready(pe_ready[(i+1)*PE_NUMS-1:i*PE_NUMS]),
            .master_enable_data(pe_enable_data[(i+1)*PE_NUMS-1:i*PE_NUMS]),
            
            /* config */
            .set_id(set_id),
            .id_scan_in(scan_chain[i]),
            .id_scan_out(scan_chain[i+1])
        );

    end
    
endmodule