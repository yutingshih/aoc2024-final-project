module  MulticastController
#(
    parameter ID_LEN = 4,
    parameter VALUE_LEN = 32,
    parameter MA_X, // machine address (for debug)
    parameter MA_Y  // machine address (for debug)
)
(
    input clk,
    input rst,

    input set_id,
    input [ID_LEN-1:0] id_in,
    output reg [ID_LEN-1:0] id, // for scan chain

    input [ID_LEN-1:0] tag,
    input enable_in,
    output wire enable_out,
    input ready_in,
    output wire ready_out,

    input [VALUE_LEN-1:0] value_in,
    output wire [VALUE_LEN-1:0] value_out
);
    always @(posedge clk or posedge rst) begin
        if(rst)begin
            id <= 'd0;
        end
        else begin
            id <= (set_id)?id_in:id;
        end
    end

    // ready 
    assign ready_out = ready_in;

    // enable
    assign enable_out = (ready_in & (tag == id) & enable_in)? 1'b1:1'b0;

    // value
    assign value_out = (enable_out)? value_in : 'd0;
    
endmodule