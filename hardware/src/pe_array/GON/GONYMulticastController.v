module  GONYMulticastController
#(
    parameter ROW_LEN = 4,
    parameter ID_LEN = 5,
    parameter VALUE_LEN = 32,
    parameter MA_Y = 0  // machine address (for debug)
)
(
    input clk,
    input rst,

    input set_id,
    input [ROW_LEN-1:0] id_in,
    output reg [ROW_LEN-1:0] id, // for scan chain

    input [ROW_LEN-1:0] tag, // for compare
    input enable_in,        // from inside out
    output wire enable_out, 
    input ready_in,         // from outside in
    output wire ready_out,

    input [VALUE_LEN-1:0] value_in,
    output wire [VALUE_LEN-1:0] value_out,

    input [ID_LEN-1:0] tag_in,
    output [ID_LEN-1:0] tag_out
);
    always @(posedge clk) begin
        if(~rst)begin
            id <= 'd0;
        end
        else begin
            id <= (set_id)?id_in:id;
        end
    end

    // ready 
    assign ready_out = (tag == id)? ready_in:1'b0;

    // enable
    assign enable_out = (ready_in & (tag == id) & enable_in)? 1'b1:1'b0;

    // value
    assign value_out = (enable_out)? value_in : 'd0;
    
    // id
    assign tag_out = (ready_out)? tag_in: 'd0;

    // debug
    /*always @(posedge clk)begin
        /*if(set_id) begin
            $display("(%d) -> %d",MA_Y,id);
        end
        if(tag) begin
            $display("(%d) -> tag = %d, id = %d",MA_Y, tag, id);
        end
    end*/
endmodule