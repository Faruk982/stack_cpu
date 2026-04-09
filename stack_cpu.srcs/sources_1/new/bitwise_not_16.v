module bitwise_not_16 (
    input  wire [15:0] a,
    output wire [15:0] result
);

    assign result = ~a;

endmodule
