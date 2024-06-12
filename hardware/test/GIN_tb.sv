`timescale 1ns/10ps
`include "./src/pe_array/GIN/GIN.v"
`include "./src/pe_array/PEWrapper.v"
`include "./src/pe_array/MappingConfig.v"

`define CYCLE 2

module GIN_tb;

parameter   XBUS_NUMS = 12,
            PE_NUMS = 14,
            ID_LEN = 5,
            ROW_LEN = 4,
            VALUE_LEN = 8,
            PSUM_WIDTH = 32;

logic clk;
logic rst;
logic enable;
logic ready;

logic [ROW_LEN-1:0] row_tag;
logic [ID_LEN-1:0] col_tag;
logic [VALUE_LEN-1:0] value;

logic set_id;
logic [ID_LEN-1:0] id_scan_in;
logic [ID_LEN-1:0] id_scan_out;

logic set_row;
logic [ROW_LEN-1:0] row_scan_in;
logic [ROW_LEN-1:0] row_scan_out;

wire [PE_NUMS*XBUS_NUMS-1:0] pe_ready;
wire [(VALUE_LEN+1)*PE_NUMS*XBUS_NUMS-1:0] pe_enable_data;

// GIN
GIN #(
    .XBUS_NUMS(XBUS_NUMS),
    .PE_NUMS(PE_NUMS),
    .ID_LEN(ID_LEN),
    .ROW_LEN(ROW_LEN),
    .VALUE_LEN(VALUE_LEN)
)GIN_0(
    .clk(clk),
    .rst(rst),
    
    .enable(enable),
    .ready(ready),
    .row_tag(row_tag),
    .col_tag(col_tag),
    .value(value),

    /* config */
    .set_id(set_id),
    .id_scan_in(id_scan_in),
    .id_scan_out(id_scan_out),

    .set_row(set_row),
    .row_scan_in(row_scan_in),
    .row_scan_out(row_scan_out),

    /* PE IO */
    .pe_ready(pe_ready),
    .pe_enable_data(pe_enable_data)
    
);

// PE - 12*14
genvar i,j;
for (i = 0;i < XBUS_NUMS; i = i + 1) begin
    for (j = 0;j < PE_NUMS; j = j + 1) begin
        PEWrapper #(
            .MA_X(j),
            .MA_Y(i)
        )PEWrapper_0(
            .clk(clk),
            .rst(rst),
            .enable(),
            /* Wrapper */
            .ifmap_in(pe_enable_data[(i*PE_NUMS+j+1)*(VALUE_LEN+1)-1:(i*PE_NUMS+j)*(VALUE_LEN+1)]), // data + enable
            .ifmap_ready(pe_ready[i*PE_NUMS+j]),

            .filter_in(), // data + enable
            .filter_ready(),

            .ipsum_in(), // data + enable
            .ipsum_ready(),

            .opsum_ready(),
            .opsum_out(), // data + enable

            .config_in()
        );
    end
end


/* clock */
always begin
    #(`CYCLE/2) clk = ~clk;
end

integer scan_file;
integer data_file;
integer read_data;
integer a,r,c;
reg [VALUE_LEN-1:0] ifmap_mem [224*60-1:0];
/* rst  and set_id*/
initial begin 
    clk = 0;
    rst = 1;
    set_id = 0;
    set_row = 0;
    enable = 0;
    row_scan_in = 0;
    id_scan_in = 0;
    $display("[GIN] reset.");
    #`CYCLE rst = 0;
    #(`CYCLE * 3) rst = 1;

    $display("[GIN] set ROW.");
    data_file = $fopen("./output/GIN_Test_ROW.txt", "r");
    for(a = 0;a<XBUS_NUMS;a=a+1) begin
        scan_file = $fscanf(data_file, "%02x\n", read_data); 
        set_row = 1;  row_scan_in = read_data;
        #`CYCLE;
    end
    $fclose(data_file);
    set_row = 0;

    #`CYCLE;
    $display("[GIN] set ID.");
    data_file = $fopen("./output/GIN_Test_ID.txt", "r");
    for(a = 0;a<XBUS_NUMS*PE_NUMS;a=a+1) begin
        scan_file = $fscanf(data_file, "%02x\n", read_data); 
        set_id = 1;  id_scan_in = read_data;
        #`CYCLE;
    end
    $fclose(data_file);
    set_id = 0; 

    $display("[GIN] set ROW/ID done.");
    #(`CYCLE * 3) $display("[GIN] test ifmap.");
    $readmemh("./output/GIN_Test_IFMAP.txt", ifmap_mem); // load test data
    for(c = 0; c < 224; c = c + 1) begin
        for(r = 0; r < 60; r = r + 1) begin
            //$write("[GIN] r = %3d, c = %3d, row_tag = %2d, col_tag = %2d [value] %d",r,c,r/14,r%14,ifmap_mem[r*224 + c]);
            #`CYCLE enable = 1; row_tag = r/30; col_tag = r%30; value = ifmap_mem[r*224 + c];
            wait(ready); //$write(" [ready] ready time = %d\n", $time);
        end
    end
    #`CYCLE enable = 0;
    $display("[GIN] test ifmap multicast done.\n\n");
    $finish;
end


initial begin
    $fsdbDumpfile("GIN_tb.fsdb");
    $fsdbDumpvars;
    $fsdbDumpMDA();
end

    
endmodule