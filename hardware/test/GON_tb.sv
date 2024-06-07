`timescale 1ns/10ps
`include "./src/pe_array/GON/GON.v"
`include "./src/pe_array/PEWrapper.v"
`include "./src/pe_array/MappingConfig.v"

`define CYCLE 2

module GON_tb;

parameter   XBUS_NUMS = 12,
            PE_NUMS = 14,
            ID_LEN = 5,
            ROW_LEN = 4,
            VALUE_LEN = 32;

logic clk;
logic rst;
wire enable;
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

wire pe_ready [PE_NUMS*XBUS_NUMS-1:0];
wire [VALUE_LEN:0] pe_enable_data [PE_NUMS*XBUS_NUMS-1:0];

// GON
GON #(
    .XBUS_NUMS(XBUS_NUMS),
    .PE_NUMS(PE_NUMS),
    .ID_LEN(ID_LEN),
    .ROW_LEN(ROW_LEN),
    .VALUE_LEN(VALUE_LEN)
)GON_0(
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
            .OPSUM_NUM(4),
            .MA_X(j),
            .MA_Y(i)
        )PEWrapper_0(
            .clk(clk),
            .rst(rst),
            .enable(),
            /* Wrapper */
            .ifmap_in(), // data + enable
            .ifmap_ready(),

            .filter_in(), // data + enable
            .filter_ready(),

            .ipsum_in(), // data + enable
            .ipsum_ready(),

            .opsum_ready(pe_ready[i*PE_NUMS+j]),
            .opsum_out(pe_enable_data[i*PE_NUMS+j]), // data + enable

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
integer a,b,r,c;
reg [VALUE_LEN-1:0] ifmap_mem [224*60-1:0];
/* rst  and set_id*/
initial begin 
    clk = 0;
    rst = 1;
    set_id = 0;
    set_row = 0;
    ready = 0;
    row_scan_in = 0;
    id_scan_in = 0;
    $display("[GON] reset.");
    #`CYCLE rst = 0;
    #(`CYCLE * 3) rst = 1;

    $display("[GON] set ROW.");
    for(a = XBUS_NUMS-1;a>=0;a=a-1) begin
        set_row = 1;  row_scan_in = a;
        #`CYCLE;
    end
    set_row = 0;

    #`CYCLE;
    $display("[GON] set ID.");
    for(a = 0;a<XBUS_NUMS;a=a+1) begin
        for(b = PE_NUMS-1;b>=0;b=b-1) begin
            set_id = 1;  id_scan_in = b;
            #`CYCLE;
        end
    end
    set_id = 0; 

    $display("[GON] set ROW/ID done.");
    #(`CYCLE * 3) $display("[GON] test opsum.");
    for(r = 0; r < XBUS_NUMS; r = r + 1) begin
        for(c = 0; c < PE_NUMS; c = c + 1) begin
            $display("[GON] row_tag = %2d, col_tag = %2d, ",r,c);
            #`CYCLE ready = 1; row_tag = r; col_tag = c;
            wait(enable);
            $display(" [value] %8h [time] %d\n", value, $time);
        end
    end
    #`CYCLE ready = 0;
    $display("[GON] test opsum multicast done.\n\n");
    $finish;
end


initial begin
    $fsdbDumpfile("GON_tb.fsdb");
    $fsdbDumpvars;
    $fsdbDumpMDA();
end

    
endmodule