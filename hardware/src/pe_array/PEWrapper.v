`include "./src/pe_array/PE/PEStub.v"
`include "./src/pe_array/MappingConfig.v"

module PEWrapper #(
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
    /* Wrapper */
    input [IFMAP_NUM*IFMAP_DATA_SIZE:0] ifmap_in, // data + enable
    output ifmap_ready,

    input [FILTER_NUM*FILTER_DATA_SIZE:0] filter_in, // data + enable
    output filter_ready,

    input [IPSUM_NUM*PSUM_DATA_SIZE:0] ipsum_in, // data + enable
    output ipsum_ready,

    input opsum_ready,
    output wire [OPSUM_NUM*PSUM_DATA_SIZE:0] opsum_out, // data + enable

    input [`CONFIG_BIT:0] config_in
);

/* Control Signal */
wire ifmap_enable = ifmap_in[IFMAP_NUM*IFMAP_DATA_SIZE];
wire filter_enable = filter_in[FILTER_NUM*FILTER_DATA_SIZE];
wire ipsum_enable = ipsum_in[IPSUM_NUM*PSUM_DATA_SIZE];
wire opsum_enable;

/* Data Flow */
wire   [(IFMAP_NUM*IFMAP_DATA_SIZE)-1:0]    ifmap = ifmap_in[(IFMAP_NUM*IFMAP_DATA_SIZE)-1:0];
wire   [(FILTER_NUM*FILTER_DATA_SIZE)-1:0]  filter = filter_in[(FILTER_NUM*FILTER_DATA_SIZE)-1:0];
wire   [(IPSUM_NUM*PSUM_DATA_SIZE)-1:0]     ipsum = ipsum_in[(IPSUM_NUM*PSUM_DATA_SIZE)-1:0];
wire   [(OPSUM_NUM*PSUM_DATA_SIZE)-1:0]     opsum;

assign opsum_out = {opsum_enable,opsum};

/* Control Signal */
wire set_info = config_in[`CONFIG_BIT];
wire [CONFIG_Q_BIT-1:0] config_q = config_in[`CONFIG_Q_START + CONFIG_Q_BIT - 1:`CONFIG_Q_START];
wire [CONFIG_P_BIT-1:0] config_p = config_in[`CONFIG_P_START + CONFIG_P_BIT - 1:`CONFIG_P_START];
wire [CONFIG_U_BIT-1:0] config_U = config_in[`CONFIG_U_START + CONFIG_U_BIT - 1:`CONFIG_U_START];
wire [CONFIG_S_BIT-1:0] config_S = config_in[`CONFIG_S_START + CONFIG_S_BIT - 1:`CONFIG_S_START];
wire [CONFIG_F_BIT-1:0] config_F = config_in[`CONFIG_F_START + CONFIG_F_BIT - 1:`CONFIG_F_START];
wire [CONFIG_W_BIT-1:0] config_W = config_in[`CONFIG_W_START + CONFIG_W_BIT - 1:`CONFIG_W_START];


`ifdef USE_STUB
PEStub #(
    .IFMAP_SPAD_SIZE(IFMAP_SPAD_SIZE),
    .FILTER_SPAD_SIZE(FILTER_SPAD_SIZE),
    .PSUM_SPAD_SIZE(PSUM_SPAD_SIZE),
    .DATA_SIZE(DATA_SIZE),
    .DATA_SIZE(DATA_SIZE),
    .DATA_SIZE(DATA_SIZE),
    .IFMAP_NUM(IFMAP_NUM),
    .FILTER_NUM(FILTER_NUM),
    .IPSUM_NUM(IPSUM_NUM),
    .OPSUM_NUM(OPSUM_NUM),
    .CONFIG_Q_BIT(CONFIG_Q_BIT), // channel count config
    .CONFIG_P_BIT(CONFIG_P_BIT), // kernel count config
    .CONFIG_U_BIT(CONFIG_U_BIT), // stride config
    .CONFIG_S_BIT(CONFIG_S_BIT), // filter width config
    .CONFIG_F_BIT(CONFIG_F_BIT), // ifmap width config
    .CONFIG_W_BIT(CONFIG_W_BIT), // ofmap width config
    .MA_X(MA_X),
    .MA_Y(MA_Y)
)PEStub_0(
    .clk(clk),
    .rst(rst),
    .enable(enable),
    /* Data Flow */
    .ifmap(ifmap),
    .filter(filter),
    .ipsum(ipsum),
    .opsum(opsum),
    /* Control Signal */
    .ifmap_enable(ifmap_enable),
    .ifmap_ready(ifmap_ready),
    .filter_enable(filter_enable),
    .filter_ready(filter_ready),
    .ipsum_enable(ipsum_enable),
    .ipsum_ready(ipsum_ready),
    .opsum_enable(opsum_enable),
    .opsum_ready(opsum_ready),
    /* Control Signal */
    .set_info(set_info),
    .config_p(config_p),
    .config_U(config_U),
    .config_q(config_q),
    .config_S(config_S),
    .config_F(config_F),
    .config_W(config_W)
    /* 
        q(channel, 2b),
        p(kernel, 5b),
        U(stride, 4b), 
        S(filter width, 4b),
        F(ofmap width, 12b),
        W(ifmap width, 12b),
    */
);
`endif
    
endmodule
