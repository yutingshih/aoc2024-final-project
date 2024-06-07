/*
    Accelerator Controller

    Author: Eason Yeh
    Version: 1.0

    Support Operation: Convolution2D / ReLU / MaxPooling2D / AvgPooling2D
*/
module controller #(
    parameter IFMAP_GIN_ROW_LEN = 4,
              IFMAP_GIN_ID_LEN = 4,
              FILTER_GIN_ROW_LEN = 4,
              FILTER_GIN_ID_LEN = 4,
              IPSUM_GIN_ROW_LEN = 4,
              IPSUM_GIN_ID_LEN = 4,
              OPSUM_GON_ROW_LEN = 4,
              OPSUM_GON_ID_LEN = 4,
              CONFIG_BITWIDTH = 32,
              ADDRESS_BITWIDTH = 32
)(
    input rst,
    input clk,
    /* Signal */
    input start,
    
    output finish,

    /* scalar configuration */
    input [CONFIG_BITWIDTH-1:0] computation_config,
    input [CONFIG_BITWIDTH-1:0] address_scan_chain,
    input [CONFIG_BITWIDTH-1:0] address_ifmap,
    input [CONFIG_BITWIDTH-1:0] address_filter,
    input [CONFIG_BITWIDTH-1:0] address_ipsum,
    input [CONFIG_BITWIDTH-1:0] address_opsum,
    input [CONFIG_BITWIDTH-1:0] size_ifmap,
    input [CONFIG_BITWIDTH-1:0] size_filter,
    input [CONFIG_BITWIDTH-1:0] size_ipsum,
    input [CONFIG_BITWIDTH-1:0] size_opsum,

    /* scan chain information */
    output set_info,

    /* NoC Control */
    output [IFMAP_GIN_ROW_LEN-1:0]   ifmap_row_id, // IFMAP X-Bus
    output [IFMAP_GIN_ID_LEN-1:0]    ifmap_col_id, // IFMAP Y-Bus PE id
    output [FILTER_GIN_ROW_LEN-1:0]  filter_col_id, // FILTER X-Bus
    output [FILTER_GIN_ID_LEN-1:0]   filter_col_id, // FILTER Y-Bus PE id
    output [IPSUM_GIN_ROW_LEN-1:0]   ipsum_col_id, // IPSUM X-Bus
    output [IPSUM_GIN_ID_LEN-1:0]    ipsum_col_id, // IPSUM Y-Bus PE id
    output [OPSUM_GON_ROW_LEN-1:0]   opsum_col_id, // OPSUM X-Bus
    output [OPSUM_GON_ID_LEN-1:0]    opsum_col_id, // OPSUM Y-Bus PE id

    output ifmap_enable,
    output filter_enable,
    output ipsum_enable,
    output opsum_ready,

    input ifmap_ready,
    input filter_ready,
    input ipsum_ready,
    input opsum_enable,

    /* 
        *** Read Data To Mux ***
        0: Scan-chain network (only when set info)
        1: IFMAP GIN
        2: FILTER GIN
        3: OFMAP GIN
    */
    output [1:0] read_to_select,
    /* 
        *** Read Data From Mux ***
        0: IARG-Buffer (BRAM)
        1: OARG-Buffer (BRAM)
    */
    output read_from_select,

    output [ADDRESS_BITWIDTH-1:] read_address,
    output read_ce,
    output [3:0] read_we, // zero
    /* 
        *** Read Data Mux ***
        0: OPSUM GON
        1: RELU OUPUT
        2: Pooling Engine
        3: (Reserved)
    */
    output [1:0] write_select, 
    output read_ce,
    output [3:0] read_we,
);
    
endmodule