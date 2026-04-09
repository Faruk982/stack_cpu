module shr1_16 (
    input  wire [15:0] a,
    output wire [15:0] result,
    output wire        carry_out
);

    assign result    = {1'b0, a[15:1]};
    assign carry_out = a[0];

endmodule
