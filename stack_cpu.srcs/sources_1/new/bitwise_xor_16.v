module bitwise_xor_16 (
    input  wire [15:0] a,
    input  wire [15:0] b,
    output wire [15:0] result
);

    assign result = b ^ a;

endmodule
