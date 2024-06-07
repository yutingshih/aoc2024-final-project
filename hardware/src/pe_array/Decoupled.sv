modport Decoupled_IN #(
    parameter VALUE_LEN = 32;
)(
    input enable,
    input [VALUE_LEN-1:0]data,
    output ready
);

modport Decoupled_OUT #(
    parameter VALUE_LEN = 32;
)(
    output enable,
    output [VALUE_LEN-1:0]data,
    input  ready
);