module shl1_16 (
    input  wire [15:0] a,
    output wire [15:0] result,
    output wire        carry_out
);

    assign result    = {a[14:0], 1'b0};
    assign carry_out = a[15];

endmodule
