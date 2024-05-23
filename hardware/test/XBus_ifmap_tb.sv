`timescale 1ns/10ps
`include "./pe_array/XBus.v"
`define CYCLE 2

module XBus_ifmap_tb;

parameter  PE_NUMS = 14,
           ID_LEN = 5,
           VALUE_LEN = 32,
           PSUM_WIDTH = 32;

logic clk;
logic rst;
logic enable;
logic ready;
logic [VALUE_LEN+ID_LEN-1:0] tag_value;
logic set_id;
logic [ID_LEN-1:0] id_scan_in;
logic [ID_LEN-1:0] id_scan_out;

/* vertical connection */
logic [PSUM_WIDTH-1:0] opsum [PE_NUMS-1:0]; 
logic opsum_enable [PE_NUMS-1:0];
logic opsum_ready [PE_NUMS-1:0];


XBus #(
    .PE_NUMS(PE_NUMS),
    .ID_LEN(ID_LEN),
    .VALUE_LEN(VALUE_LEN),
    .PSUM_WIDTH(PSUM_WIDTH)
)XBus_0(
    .clk(clk),
    .rst(rst),
    
    .enable(enable),
    .ready(ready),
    .tag_value(tag_value),

    .set_id(set_id),
    .id_scan_in(id_scan_in),
    .id_scan_out(id_scan_out),

    /* vertical connection */
    .opsum(opsum), 
    .opsum_enable(opsum_enable),
    .opsum_ready(opsum_ready)
);

/* clock */
always begin
    #(`CYCLE/2) clk = ~clk;
end

/* rst  and set_id*/
initial begin 
    clk = 0;
    rst = 0;
    set_id = 0;
    #`CYCLE rst = 1;
    #(`CYCLE * 3) rst = 0;
    #`CYCLE set_id = 1; id_scan_in = PE_NUMS-1;
    for(int i = PE_NUMS-2;i>=0;i=i-1) begin
        #`CYCLE  id_scan_in = i;
    end
    #`CYCLE set_id = 0;
    $display("test xbus done.");
    $finish;
end

initial begin
    $fsdbDumpfile("xbus_tb.fsdb");
    $fsdbDumpvars;
    $fsdbDumpMDA();
end
    
endmodule