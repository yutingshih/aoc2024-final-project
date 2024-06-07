`include "./src/pe_array/GIN/GINMulticastController.v"

module GINBus #(
    parameter MASTER_NUMS = 14,
    parameter ID_LEN = 5,
    parameter VALUE_LEN = 32,
    parameter MA_Y = 0
) (
    input clk,
    input rst,
    
    /* Slave I/O */
    output wire ready,
    input [VALUE_LEN+ID_LEN:0] enable_tag_value,

    /* Master IO */
    input master_ready [MASTER_NUMS-1:0],
    output [VALUE_LEN:0] master_enable_data [MASTER_NUMS-1:0],

    /* config */
    input set_id,
    input [ID_LEN-1:0] id_scan_in,
    output wire [ID_LEN-1:0] id_scan_out
);

    /* split value and tag */
    wire enable = enable_tag_value[VALUE_LEN+ID_LEN];
    wire [ID_LEN-1:0] tag = enable_tag_value[VALUE_LEN+ID_LEN-1:VALUE_LEN];
    wire [VALUE_LEN-1:0] value = enable_tag_value[VALUE_LEN-1:0];

    // ready check
    wire [MASTER_NUMS-1:0] ready_check;
    assign ready = &ready_check; // and together

    // id scan chain wire
    wire [ID_LEN-1:0] scan_chain [MASTER_NUMS:0];
    assign scan_chain[0] = id_scan_in;
    assign id_scan_out = scan_chain[MASTER_NUMS];

    /* multicast with PE */
    genvar i;
    for (i = 0;i < MASTER_NUMS; i = i + 1) begin
        GINMulticastController #(
            .ID_LEN(ID_LEN), 
            .VALUE_LEN(VALUE_LEN),
            .MA_X(i),
            .MA_Y(MA_Y)
        ) mc (
            .clk(clk),
            .rst(rst),
            .set_id(set_id),
            .id_in(scan_chain[i]),
            .id(scan_chain[i+1]), // for scan chain
            .tag(tag),
            .enable_in(enable),
            .enable_out(master_enable_data[i][VALUE_LEN]),
            .ready_in(master_ready[i]),
            .ready_out(ready_check[i]),
            .value_in(value),
            .value_out(master_enable_data[i][VALUE_LEN-1:0])
        );
    end
    
endmodule