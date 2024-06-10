/*
    Local Network (LN)
    
    network of psum between PEs
*/
module LN #(
    parameter CONNECT_X1 = 0,
              CONNECT_Y1 = 0,
              CONNECT_X2 = 0,
              CONNECT_Y2 = 0,
              PSUM_DATA_SIZE = 8,
              IPSUM_NUM = 4,
              OPSUM_NUM = 4;
) (
    input clk,
    input rst,

    input set_info,
    input connect_flag, // connect Local Network
    output wire connect_flag_out, // connect Local Network

    /* ipsum to PE */
    output [IPSUM_NUM*PSUM_DATA_SIZE:0] ipsum, // data + enable
    input ipsum_ready,
    /* opsum from PE */
    output opsum_ready,
    input  [OPSUM_NUM*PSUM_DATA_SIZE:0] opsum, // data + enable
    /* ipsum from bus */
    input [IPSUM_NUM*PSUM_DATA_SIZE:0] ipsum_bus, // data + enable
    output ipsum_ready_bus,
    /* opsum to  bus */
    input opsum_ready_bus,
    output [OPSUM_NUM*PSUM_DATA_SIZE:0] opsum_bus, // data + enable
);

reg connect_flag_reg;
assign connect_flag_out = connect_flag_reg

always @(posedge clk) begin
    if(~rst) begin
        connect_flag_reg <= 'd0;
    end else begin
        connect_flag_reg <= (set_info)?connect_flag:connect_flag_reg;
    end
end

/* Switch */
always @(*) begin
    if(connect_flag_reg) begin
        ipsum = opsum;
        opsum_ready = ipsum_ready;
        ipsum_ready_bus = 'd0;
        opsum_bus = 'd0;
    end else begin
        ipsum = ipsum_bus;
        ipsum_ready_bus = ipsum_ready;
        opsum_ready = opsum_ready_bus;
        opsum_bus = opsum;
    end
end

endmodule