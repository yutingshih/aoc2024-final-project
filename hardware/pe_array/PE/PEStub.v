`define OUTPUT_PATH "./output"

module PEStub #(
    parameter IFMAP_SPAD_SIZE = 12,
              FILTER_SPAD_SIZE = 224,
              PSUM_SPAD_SIZE = 24,
              DATA_SIZE = 8,
              IFMAP_NUM = 1,
              FILTER_NUM = 4,
              IPSUM_NUM = 1,
              OPSUM_NUM = 1,
              CONFIG_Q_BIT = 2, // channel count config
              CONFIG_P_BIT = 5, // kernel count config
              CONFIG_U_BIT = 4, // stride config
              CONFIG_S_BIT = 4, // filter width config
              CONFIG_F_BIT = 12, // ifmap width config
              CONFIG_W_BIT = 12, // ofmap width config
              MA_X = 0,
              MA_Y = 0
) (
    input clk,
    input rst,
    input enable,
    /* Data Flow */
    input   [(IFMAP_NUM*DATA_SIZE)-1:0]     ifmap,
    input   [(FILTER_NUM*DATA_SIZE)-1:0]    filter,
    input   [(IPSUM_NUM*DATA_SIZE)-1:0]     ipsum,
    output  [(OPSUM_NUM*DATA_SIZE)-1:0]     opsum,
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
        F(ofmap width, 12b),
        W(ifmap width, 12b),
    */
);
assign ifmap_ready = 1'b1;
wire ifmap_get = (ifmap_enable & ifmap_ready);

/* stub for debug */
string fname;
integer fd;
initial begin
    $sformat(fname,"%s/PE_STUB_X%02d_Y%02d.log",`OUTPUT_PATH,MA_X,MA_Y);
    fd = $fopen(fname,"a");
    $fdisplay(fd, "======= PE STUB =======");
    $fdisplay(fd, " X = %2d", MA_X);
    $fdisplay(fd, " Y = %2d", MA_Y);
    $fdisplay(fd, "=======================");
    $fclose(fd);
end

always @(posedge clk or posedge rst) begin
    if(ifmap_get) begin
        fd = $fopen(fname,"a");
        $fdisplay(fd, "[ifmap_get] data = %5d", ifmap);
        $fclose(fd);
    end
end


endmodule