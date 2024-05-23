`include "./pe_array/MulitcastController.v"

module XBus #(
    parameter PE_NUMS = 14,
    parameter ID_LEN = 5,
    parameter VALUE_LEN = 32,
    parameter PSUM_WIDTH = 32
) (
    input clk,
    input rst,
    
    input enable,
    output wire ready,
    input [VALUE_LEN+ID_LEN-1:0] tag_value,

    /* config */
    input set_id,
    input [ID_LEN-1:0] id_scan_in,
    output wire [ID_LEN-1:0] id_scan_out,

    /* PE IO */
    input pe_ready [PE_NUMS-1:0],
    output [VALUE_LEN:0] pe_data [PE_NUMS-1:0]
    
);

    /* split value and tag */
    wire [ID_LEN-1:0] tag = tag_value[VALUE_LEN+ID_LEN-1:VALUE_LEN];
    wire [VALUE_LEN-1:0] value = tag_value[VALUE_LEN-1:0];

    // ready check
    wire [PE_NUMS-1:0] ready_check;
    assign ready = |ready_check; // or together

    // id scan chain wire
    wire [ID_LEN-1:0] scan_chain [PE_NUMS:0];
    assign scan_chain[0] = id_scan_in;
    assign id_scan_out = scan_chain[PE_NUMS];

    /* multicast with PE */
    genvar i;
    for (i = 0;i < PE_NUMS; i = i + 1) begin
        MulitcastController #(
            .ID_LEN(ID_LEN), 
            .VALUE_LEN(VALUE_LEN),
            .MA_X(i),
            .MA_Y(0)
        ) mc (
            .clk(clk),
            .rst(rst),
            .set_id(set_id),
            .id_in(scan_chain[i]),
            .id(scan_chain[i+1]), // for scan chain
            .tag(tag),
            .enable_in(enable),
            .enable_out(pe_data[i][VALUE_LEN]),
            .ready_in(pe_ready[i]),
            .ready_out(ready_check[i]),
            .value_in(value),
            .value_out(pe_data[i][VALUE_LEN-1:0])
        );
    end
    
endmodule