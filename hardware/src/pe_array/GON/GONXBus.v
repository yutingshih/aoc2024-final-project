`include "./src/pe_array/GON/GONXMulticastController.v"

module GONXBus #(
    parameter MASTER_NUMS = 14,
    parameter ID_LEN = 5,
    parameter VALUE_LEN = 32,
    parameter MA_Y = 0
) (
    input clk,
    input rst,
    
    /* Slave I/O */
    input wire [ID_LEN:0] ready_tag,
    output [VALUE_LEN:0] enable_value,

    /* Master I/O */
    output master_ready_tag [MASTER_NUMS-1:0],
    input [VALUE_LEN:0] master_enable_data [MASTER_NUMS-1:0],

    /* config */
    input set_id,
    input [ID_LEN-1:0] id_scan_in,
    output wire [ID_LEN-1:0] id_scan_out
);

    /* split ready and tag */
    wire ready = ready_tag[ID_LEN];
    wire [ID_LEN-1:0] tag = ready_tag[ID_LEN-1:0];

    /* enable check */
    wire [MASTER_NUMS-1:0] enable_check;
    wire [VALUE_LEN-1:0] value_gather [MASTER_NUMS:0];
    wire [VALUE_LEN-1:0] value_out [MASTER_NUMS-1:0];
    assign enable_value = {|enable_check,value_gather[MASTER_NUMS]};
    assign value_gather[0] = 'd0;

    // id scan chain wire
    wire [ID_LEN-1:0] scan_chain [MASTER_NUMS:0];
    assign scan_chain[0] = id_scan_in;
    assign id_scan_out = scan_chain[MASTER_NUMS];

    /* multicast with PE/BUS */
    genvar i;
    for (i = 0;i < MASTER_NUMS; i = i + 1) begin
        GONXMulticastController #(
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
            .enable_in(master_enable_data[i][VALUE_LEN]),
            .enable_out(enable_check[i]),
            .ready_in(ready),
            .ready_out(master_ready_tag[i]),
            .value_in(master_enable_data[i][VALUE_LEN-1:0]),
            .value_out(value_out[i]) // multi-Fan-in
        );
        assign value_gather[i+1] = value_gather[i] | value_out[i];
    end

    /*integer a;
    always @(posedge clk) begin
        if(ready_tag[ID_LEN])begin
            $display("[GONXBUS] ready, col_tag = %d",ready_tag[ID_LEN-1:0]);
            for(a = 0;a<MASTER_NUMS;a=a+1)begin
                $display("[%d] %b [id] %b [enable] %b [value] %8h ",a,master_ready_tag[a], scan_chain[a+1],
                master_enable_data[a][VALUE_LEN], master_enable_data[a][VALUE_LEN-1:0]);
            end
            $display("[GONXBUS] enable_value = %9h,enable_check = %b",enable_value, enable_check);
            $display("[GONXBUS]============================");
        end
    end*/
    
endmodule