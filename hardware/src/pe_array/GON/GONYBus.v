`include "./src/pe_array/GON/GONYMulticastController.v"

module GONYBus #(
    parameter MASTER_NUMS = 14,
              ID_LEN = 5,
              ROW_LEN = 4,
              VALUE_LEN = 32,
              MA_X = 0
) (
    input clk,
    input rst,
    
    /* Slave I/O */
    input wire [ROW_LEN+ID_LEN:0] ready_tag,
    output wire [VALUE_LEN:0] enable_value,

    /* Master I/O */
    output [ID_LEN:0] master_ready_tag [MASTER_NUMS-1:0],
    input [VALUE_LEN:0] master_enable_data [MASTER_NUMS-1:0],

    /* config */
    input set_id,
    input [ROW_LEN-1:0] id_scan_in,
    output wire [ROW_LEN-1:0] id_scan_out
);

    /* split ready and tag */
    wire ready = ready_tag[ID_LEN+ROW_LEN];
    wire [ROW_LEN-1:0] tag = ready_tag[ID_LEN+ROW_LEN-1:ID_LEN];
    wire [ID_LEN-1:0] id = ready_tag[ID_LEN-1:0];

    /* enable check */
    wire [MASTER_NUMS-1:0] enable_check;
    wire [VALUE_LEN-1:0] value_gather [MASTER_NUMS:0];
    wire [VALUE_LEN-1:0] value_out [MASTER_NUMS-1:0];
    wire enable_chk = |enable_check;
    assign enable_value = {enable_chk,value_gather[MASTER_NUMS]};
    assign value_gather[0] = 'd0;
    

    // id scan chain wire
    wire [ROW_LEN-1:0] scan_chain [MASTER_NUMS:0];
    assign scan_chain[0] = id_scan_in;
    assign id_scan_out = scan_chain[MASTER_NUMS];

    /* multicast with PE/BUS */
    genvar i;
    for (i = 0;i < MASTER_NUMS; i = i + 1) begin
        GONYMulticastController #(
            .ID_LEN(ID_LEN),
            .ROW_LEN(ROW_LEN),
            .VALUE_LEN(VALUE_LEN),
            .MA_Y(i)
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
            .ready_out(master_ready_tag[i][ID_LEN]),
            .value_in(master_enable_data[i][VALUE_LEN-1:0]),
            .value_out(value_out[i]), // multi-Fan-in
            .tag_in(id),
            .tag_out(master_ready_tag[i][ID_LEN-1:0])
        );
        assign value_gather[i+1] = value_gather[i] | value_out[i];
    end

    /*integer a;
    always @(posedge clk) begin
        if(ready_tag[ID_LEN+ROW_LEN])begin
            $display("[GONYBUS] ready, row_tag = %d, col_tag = %d", ready_tag[ROW_LEN+ID_LEN-1:ID_LEN] ,ready_tag[ID_LEN-1:0]);
            for(a = 0;a<MASTER_NUMS;a=a+1)begin
                $display("[%d] %b [id] %b [enable] %b [value] %8h [value_out] %8h",a,master_ready_tag[a][ID_LEN], scan_chain[a+1],
                master_enable_data[a][VALUE_LEN], master_enable_data[a][VALUE_LEN-1:0], value_gather[a+1]);
            end
            $display("[GONYBUS] enable_value = %9h,enable_check = %b",enable_value, enable_check);
            $display("[GONYBUS]============================");
        end
    end*/
    
endmodule