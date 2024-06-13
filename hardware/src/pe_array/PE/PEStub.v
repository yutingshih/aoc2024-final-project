`define OUTPUT_PATH "./output"

module PEStub #(
    parameter IFMAP_SPAD_SIZE = 12,
              FILTER_SPAD_SIZE = 224,
              PSUM_SPAD_SIZE = 24,
              IFMAP_DATA_SIZE = 8,
              FILTER_DATA_SIZE = 8,
              PSUM_DATA_SIZE = 8,
              IFMAP_NUM = 1,
              FILTER_NUM = 4,
              IPSUM_NUM = 1,
              OPSUM_NUM = 1,
              CONFIG_Q_BIT = 3, // channel count config
              CONFIG_P_BIT = 5, // kernel count config
              CONFIG_U_BIT = 4, // stride config
              CONFIG_S_BIT = 4, // filter width config
              CONFIG_F_BIT = 8, // ifmap width config
              CONFIG_W_BIT = 8, // ofmap width config
              MA_X = 0,
              MA_Y = 0
) (
    input clk,
    input rst,
    input enable,
    /* Data Flow */
    input   [(IFMAP_NUM*IFMAP_DATA_SIZE)-1:0]     ifmap,
    input   [(FILTER_NUM*FILTER_DATA_SIZE)-1:0]    filter,
    input   [(IPSUM_NUM*PSUM_DATA_SIZE)-1:0]     ipsum,
    output  [(OPSUM_NUM*PSUM_DATA_SIZE)-1:0]     opsum,
    /* Control Signal */
    input ifmap_enable,
    output wire ifmap_ready,
    input filter_enable,
    output filter_ready,
    input ipsum_enable,
    output ipsum_ready,
    output opsum_enable,
    input opsum_ready,
    /* Control Signal */
    input set_info,
    input [CONFIG_Q_BIT-1:0] config_q,
    input [CONFIG_P_BIT-1:0] config_p,
    input [CONFIG_U_BIT-1:0] config_U,
    input [CONFIG_S_BIT-1:0] config_S,
    input [CONFIG_F_BIT-1:0] config_F,
    input [CONFIG_W_BIT-1:0] config_W
    /* 
        q(channel, 2b),
        p(kernel, 5b),
        U(stride, 4b), 
        S(filter width, 4b),
        F(ofmap width, 8b),
        W(ifmap width, 8b),
    */
);
assign ifmap_ready = 1'b1;
assign filter_ready = 1'b1;
wire ifmap_get = (ifmap_enable & ifmap_ready);
wire filter_get = (filter_enable & filter_ready);


assign opsum_enable = 1'b1;
wire [7:0] d = MA_X+MA_Y+3;
assign opsum = {d,d,d,d};

/* stub for debug */
string fname;
integer fd;
initial begin
    $sformat(fname,"%s/PE_STUB_Y%02d_X%02d.log",`OUTPUT_PATH,MA_Y,MA_X);
    fd = $fopen(fname,"w");
    $fdisplay(fd, "======= PE STUB =======");
    $fdisplay(fd, " X = %2d", MA_X);
    $fdisplay(fd, " Y = %2d", MA_Y);
    $fdisplay(fd, "=======================");
    $fclose(fd);
end

always @(posedge clk or posedge rst) begin
    if(ifmap_get) begin
        $sformat(fname,"%s/PE_STUB_Y%02d_X%02d.log",`OUTPUT_PATH,MA_Y,MA_X);
        fd = $fopen(fname,"a");
        $fdisplay(fd, "[ifmap_get] data = %8h", ifmap);
        $fclose(fd);  
    end
    if(set_info) begin
        $sformat(fname,"%s/PE_STUB_Y%02d_X%02d.log",`OUTPUT_PATH,MA_Y,MA_X);
        fd = $fopen(fname,"a");
        $fdisplay(fd, "[set_info] config_q = %5d", config_q);
        $fdisplay(fd, "[set_info] config_p = %5d", config_p);
        $fdisplay(fd, "[set_info] config_U = %5d", config_U);
        $fdisplay(fd, "[set_info] config_S = %5d", config_S);
        $fdisplay(fd, "[set_info] config_F = %5d", config_F);
        $fdisplay(fd, "[set_info] config_W = %5d", config_W);        
        $fclose(fd);  
    end
    if(filter_get) begin
        $sformat(fname,"%s/PE_STUB_Y%02d_X%02d.log",`OUTPUT_PATH,MA_Y,MA_X);
        fd = $fopen(fname,"a");
        $fdisplay(fd, "[filter_get] data = %5d %5d %5d %5d", 
            $signed(filter[FILTER_DATA_SIZE-1:0]),
            $signed(filter[FILTER_DATA_SIZE*2-1:FILTER_DATA_SIZE]),
            $signed(filter[FILTER_DATA_SIZE*3-1:FILTER_DATA_SIZE*2]),
            $signed(filter[FILTER_DATA_SIZE*4-1:FILTER_DATA_SIZE*3])
            );
        //$display("[filter_get] data = %5d [x] %2d [y] %2d", filter,MA_X,MA_Y);
        $fclose(fd);  
    end
end

endmodule