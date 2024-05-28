`timescale 1ns/10ps
`include "./pe_array/GIN/GINBus.v"
`include "./pe_array/PEWrapper.v"
`include "./pe_array/MappingConfig.v"

`define CYCLE 2

module XBus_tb;

parameter   PE_NUMS = 14,
            ID_LEN = 4,
            VALUE_LEN = 8,
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


wire pe_ready [PE_NUMS-1:0];
wire [VALUE_LEN:0] pe_data [PE_NUMS-1:0];

// X GINBus - 1
GINBus #(
    .MASTER_NUMS(PE_NUMS),
    .ID_LEN(ID_LEN),
    .VALUE_LEN(VALUE_LEN)
)XBus_0(
    .clk(clk),
    .rst(rst),
    
    .ready(ready),
    .enable_tag_value({enable,tag_value}),

    /* PE IO */
    .master_ready(pe_ready),
    .master_enable_data(pe_data),

    .set_id(set_id),
    .id_scan_in(id_scan_in),
    .id_scan_out(id_scan_out)
);
// PE - 14
genvar i;
for (i = 0;i < PE_NUMS; i = i + 1) begin
    PEWrapper #(
        .MA_X(i)
    )PEWrapper_0(
        .clk(clk),
        .rst(rst),
        .enable(enable),
        /* Wrapper */
        .ifmap_in(pe_data[i]), // data + enable
        .ifmap_ready(pe_ready[i]),

        .filter_in(), // data + enable
        .filter_ready(),

        .ipsum_in(), // data + enable
        .ipsum_ready(),

        .opsum_ready(),
        .opsum_out(), // data + enable

        .config_in()
    );
end


/* clock */
always begin
    #(`CYCLE/2) clk = ~clk;
end

/* rst  and set_id*/
initial begin 
    clk = 0;
    rst = 0;
    set_id = 0;
    enable = 0;
    $display("[xbus] set ID.");
    #`CYCLE rst = 1;
    #(`CYCLE * 3) rst = 0;
    #`CYCLE set_id = 1; id_scan_in = (PE_NUMS/2)-1;
    for(int i = (PE_NUMS/2)-2;i>=0;i=i-1) begin
        #`CYCLE  id_scan_in = i;
    end
    #`CYCLE  id_scan_in = (PE_NUMS/2)-1;
    for(int i = (PE_NUMS/2)-2;i>=0;i=i-1) begin
        #`CYCLE  id_scan_in = i;
    end
    #`CYCLE set_id = 0;
    $display("[xbus] set ID done.");
    #(`CYCLE * 3) $display("[xbus] test ifmap multicast.");
    #`CYCLE enable = 1;
    #`CYCLE tag_value = {ID_LEN'('d0), VALUE_LEN'('h00)}; wait(ready); $display("[Ready] time = %d", $time);
    #`CYCLE tag_value = {ID_LEN'('d1), VALUE_LEN'('h01)}; wait(ready); $display("[Ready] time = %d", $time);
    #`CYCLE tag_value = {ID_LEN'('d2), VALUE_LEN'('h02)}; wait(ready); $display("[Ready] time = %d", $time);
    #`CYCLE tag_value = {ID_LEN'('d3), VALUE_LEN'('h03)}; wait(ready); $display("[Ready] time = %d", $time);
    #`CYCLE tag_value = {ID_LEN'('d4), VALUE_LEN'('h04)}; wait(ready); $display("[Ready] time = %d", $time);
    #`CYCLE tag_value = {ID_LEN'('d5), VALUE_LEN'('h05)}; wait(ready); $display("[Ready] time = %d", $time);
    #`CYCLE tag_value = {ID_LEN'('d6), VALUE_LEN'('h06)}; wait(ready); $display("[Ready] time = %d", $time);
    #`CYCLE tag_value = {ID_LEN'('d0), VALUE_LEN'('hff)}; wait(ready); $display("[Ready] time = %d", $time);
    #`CYCLE tag_value = {ID_LEN'('d1), VALUE_LEN'('hfe)}; wait(ready); $display("[Ready] time = %d", $time);
    #`CYCLE tag_value = {ID_LEN'('d2), VALUE_LEN'('hfd)}; wait(ready); $display("[Ready] time = %d", $time);
    #`CYCLE tag_value = {ID_LEN'('d3), VALUE_LEN'('hfc)}; wait(ready); $display("[Ready] time = %d", $time);
    #`CYCLE tag_value = {ID_LEN'('d4), VALUE_LEN'('hfb)}; wait(ready); $display("[Ready] time = %d", $time);
    #`CYCLE tag_value = {ID_LEN'('d5), VALUE_LEN'('hfa)}; wait(ready); $display("[Ready] time = %d", $time);
    #`CYCLE tag_value = {ID_LEN'('d6), VALUE_LEN'('hf9)}; wait(ready); $display("[Ready] time = %d", $time);
    #`CYCLE enable = 0;
    $display("[xbus] test ifmap multicast done.");
    $finish;
end

initial begin
    $fsdbDumpfile("xbus_tb.fsdb");
    $fsdbDumpvars;
    $fsdbDumpMDA();
end
    
endmodule