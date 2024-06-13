`timescale 1ns/10ps
`include "./src/pe_array/PEArray.v"
`include "./src/pe_array/MappingConfig.v"

`define CYCLE 2

module PE_array_tb;

parameter XBUS_NUMS = 12,
              PE_NUMS = 14,
              IFMAP_DATA_SIZE = 8,
              FILTER_DATA_SIZE = 8,
              PSUM_DATA_SIZE = 32,
              IFMAP_NUM = 1,
              FILTER_NUM = 4,
              IPSUM_NUM = 4,
              OPSUM_NUM = 4,
              ID_LEN = 5,
              ROW_LEN = 4,
              /* PE param */
              IFMAP_SPAD_SIZE = 12,
              FILTER_SPAD_SIZE = 224,
              PSUM_SPAD_SIZE = 24,
              CONFIG_Q_BIT = 3, // channel count config
              CONFIG_P_BIT = 5, // kernel count config
              CONFIG_U_BIT = 4, // stride config
              CONFIG_S_BIT = 4, // filter width config
              CONFIG_F_BIT = 12, // ifmap width config
              CONFIG_W_BIT = 12; // ofmap width config

parameter filter_start_addr = 0,
          ifmap_start_addr = 1152,
          scan_chain_start_addr = 51328,
          EOF_addr = 52064;

logic clk;
logic rst;

logic [31:0] addr;

/* Scan Chain */
logic set_id;
logic [ID_LEN-1:0] id_scan_in;
logic  [ID_LEN-1:0] id_scan_out;

logic set_row;
logic [ROW_LEN-1:0] row_scan_in;
logic  [ROW_LEN-1:0] row_scan_out;

logic set_ln_info;
logic [XBUS_NUMS-1:0] LN_config_in;

/* Data Flow in - ifmap */
logic ifmap_enable;
logic  ifmap_ready;
logic [ROW_LEN-1:0] ifmap_row_tag;
logic [ID_LEN-1:0] ifmap_col_tag;
logic [IFMAP_DATA_SIZE*IFMAP_NUM-1:0] ifmap_value;
/* Data Flow in - filter */
logic filter_enable;
logic  filter_ready;
logic [ROW_LEN-1:0] filter_row_tag;
logic [ID_LEN-1:0] filter_col_tag;
logic [FILTER_DATA_SIZE*FILTER_NUM-1:0] filter_value;
/* Data Flow in - ipsum */
logic ipsum_enable;
logic  ipsum_ready;
logic [ROW_LEN-1:0] ipsum_row_tag;
logic [ID_LEN-1:0] ipsum_col_tag;
logic [PSUM_DATA_SIZE*IPSUM_NUM-1:0] ipsum_value;
/* Data Flow out - opsum */
logic  opsum_enable;
logic opsum_ready;
logic [ROW_LEN-1:0] opsum_row_tag;
logic [ID_LEN-1:0] opsum_col_tag;
logic  [PSUM_DATA_SIZE*OPSUM_NUM-1:0] opsum_value;

/* PE config */
logic enable;
logic set_pe_info;
logic [CONFIG_Q_BIT-1:0] config_q;
logic [CONFIG_P_BIT-1:0] config_p;
logic [CONFIG_U_BIT-1:0] config_U;
logic [CONFIG_S_BIT-1:0] config_S;
logic [CONFIG_F_BIT-1:0] config_F;
logic [CONFIG_W_BIT-1:0] config_W;

logic [7:0] config_H;
logic [7:0] config_E;
logic [11:0] config_C;
logic [11:0] config_M;
logic [3:0] config_t;
logic [3:0] config_r;



logic [31:0] pe_config [2:0];

PEArray #(
)PEArray_0(
    .clk(clk),
    .rst(rst),

    /* Scan Chain */
    .set_id(set_id),
    .id_scan_in(id_scan_in),
    .id_scan_out(id_scan_out),

    .set_row(set_row),
    .row_scan_in(row_scan_in),
    .row_scan_out(row_scan_out),

    .set_ln_info(set_ln_info),
    .LN_config_in(LN_config_in),

    /* Data Flow in - ifmap */
    .ifmap_enable(ifmap_enable),
    .ifmap_ready(ifmap_ready),
    .ifmap_row_tag(ifmap_row_tag),
    .ifmap_col_tag(ifmap_col_tag),
    .ifmap_value(ifmap_value),

    /* Data Flow in - filter */
    .filter_enable(filter_enable),
    .filter_ready(filter_ready),
    .filter_row_tag(filter_row_tag),
    .filter_col_tag(filter_col_tag),
    .filter_value(filter_value),

    /* Data Flow in - ipsum */
    .ipsum_enable(ipsum_enable),
    .ipsum_ready(ipsum_ready),
    .ipsum_row_tag(ipsum_row_tag),
    .ipsum_col_tag(ipsum_col_tag),
    .ipsum_value(ipsum_value),

    /* Data Flow out - opsum */
    .opsum_enable(opsum_enable),
    .opsum_ready(opsum_ready),
    .opsum_row_tag(opsum_row_tag),
    .opsum_col_tag(opsum_col_tag),
    .opsum_value(opsum_value),

    /* PE config */
    .enable(enable),
    .set_pe_info(set_pe_info),
    .config_q(config_q),
    .config_p(config_p),
    .config_U(config_U),
    .config_S(config_S),
    .config_F(config_F),
    .config_W(config_W)
);

reg [7:0] glb [1024*64:0]; //64KB
reg [7:0] output_buffer [1024*16:0]; //16KB

/* clock */
always begin
    #(`CYCLE/2) clk = ~clk;
end

integer a,c,r,q,s,p;
/* rst  and set_id*/
initial begin 
    // read memory
    $readmemh("./output/PEarray_Test_MEM.txt",glb);
    $display("[READ Memory] PEarray_Test_MEM to global_buffer");
    clk = 0;
    rst = 1;
    set_id = 0;
    set_row = 0;
    enable = 0;
    row_scan_in = 0;
    id_scan_in = 0;
    $display("[PEarray] reset.");
    #`CYCLE rst = 0;
    #(`CYCLE * 3) rst = 1; enable=1;

    $display("[PEarray] Read PE config");
    addr = scan_chain_start_addr;
    pe_config[0] = {glb[addr+3],glb[addr+2],glb[addr+1],glb[addr]};
    addr = addr+4;
    #`CYCLE;
    pe_config[1] = {glb[addr+3],glb[addr+2],glb[addr+1],glb[addr]};
    addr = addr+4;
    #`CYCLE;
    pe_config[2] = {glb[addr+3],glb[addr+2],glb[addr+1],glb[addr]};
    addr = addr+4;
    $display("[PEarray] Set PE config");
    config_q = pe_config[2][2:0];
    config_p = pe_config[2][7:3];
    config_U = pe_config[0][31:28];
    config_S = pe_config[1][31:28];
    config_F = pe_config[1][7:0];
    config_W = pe_config[0][7:0];
    config_H = pe_config[0][15:8];
    config_E = pe_config[1][15:8];
    config_C = pe_config[0][27:16];
    config_M = pe_config[1][27:16];
    config_t = pe_config[2][11:8];
    config_r = pe_config[2][15:12];
    set_pe_info = 1;
    #`CYCLE;
    set_pe_info = 0;

    $display("[PEarray] set ROW.");
    for(a = 0;a<XBUS_NUMS*4;a=a+1) begin
        set_row = 1;  row_scan_in = glb[addr]; 
        addr = addr+1;
        #`CYCLE;
    end
    set_row = 0;


    #`CYCLE;
    $display("[PEarray] set ID.");
    for(a = 0;a<XBUS_NUMS*PE_NUMS*4;a=a+1) begin
        set_id = 1;  id_scan_in = glb[addr]; 
        addr = addr+1;
        #`CYCLE;
    end
    set_id = 0; 
    $display("[PEarray] set ROW/ID done.");
    #`CYCLE;
    $display("[PEarray] set LN.");
    set_ln_info = 1;  LN_config_in = {glb[addr+3],glb[addr+2],glb[addr+1],glb[addr]};
    addr = addr+4;
    #`CYCLE;
    set_ln_info = 0; 
    $display("[PEarray] addr = %d ,EOF = %d",addr,EOF_addr);

    addr = filter_start_addr;
    #(`CYCLE * 3) $display("[PEarray] READ filter."); 
    /* 
        filter :
            (p,R,S,q) 
            
            for loop C_tile: 
                for loop S:
                    row_tag = C//q * q
                    col_tag = R
    */
    for(c = 0; c < config_C; c = c + config_q) begin
        for(r = 0; r < config_S; r = r + 1) begin
            for(p = 0;p < config_p; p = p + 1) begin
                for(s = 0;s <config_S;s = s+1) begin
                    //$display("[filter] (%3d,%3d,%3d,%3d)",p,r,s,c);
                    #`CYCLE filter_enable = 1; 
                    filter_row_tag = c; 
                    filter_col_tag = r; 
                    filter_value = {
                        glb[addr + (((p*config_C + r)*config_S + s)*config_C) + c ],
                        glb[addr + (((p*config_C + r)*config_S + s)*config_C) + c + 1],
                        glb[addr + (((p*config_C + r)*config_S + s)*config_C) + c + 2],
                        glb[addr + (((p*config_C + r)*config_S + s)*config_C) + c + 3]};
                    wait(filter_ready);
                end
            end
        end
    end
    #`CYCLE enable = 0;
    $display("[PEarray] READ filter done.\n\n");
    $finish;
end


initial begin
    $fsdbDumpfile("GIN_tb.fsdb");
    $fsdbDumpvars;
    $fsdbDumpMDA();
end

    
endmodule