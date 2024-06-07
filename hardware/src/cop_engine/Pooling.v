module Pooling #(
    parameter DATA_BITWIDTH = 8,
              INFO_BITWIDTH = 8;
              ADDRESS_BITWIDTH = 12,
)(
    input clk,
    input rst,
    input enable, // work when enable
    /* set info */
    input set_info, // set_info before start
    input [1:0] kernel_size, // 2x2 or 3x3
    input type, // Po;;ing type: (0) MaxPooling2D (1) Average Pooling2D
    /* Data flow */
    input [ADDRESS_BITWIDTH-1:0] e_in, // input height (max 56)
    input [ADDRESS_BITWIDTH-1:0] f_in, // input width  (max 256)
    input [DATA_BITWIDTH-1:0] data_in, // input data
    output write_ready, // ready to outside
    input write_valid,  // valid means data is prepared

    input [ADDRESS_BITWIDTH-1:0] e_out, // output height (max 56)
    input [ADDRESS_BITWIDTH-1:0] f_out, // output width  (max 256)
    output [DATA_BITWIDTH-1:0] data_out,    // output data
    output read_valid,  // valid means data is prepared
    input read_ready    // ready means data is read from outside
);
    
endmodule