module adder_subtractor_16 (
    input  wire [15:0] a,
    input  wire [15:0] b,
    input  wire        sub_en,
    output wire [15:0] result,
    output wire        carry_out,
    output wire        overflow
);

    wire [15:0] b_eff;
    wire        adder_cout;

    assign b_eff = sub_en ? ~a : a;

    ripple_adder_16 u_ripple (
        .x   (b),
        .y   (b_eff),
        .cin (sub_en),
        .sum (result),
        .cout(adder_cout)
    );

    // Carry flag convention:
    // - ADD : C=1 on unsigned carry-out.
    // - SUB/CMP (b-a): C=1 on borrow, so invert adder carry-out.
    assign carry_out = sub_en ? ~adder_cout : adder_cout;

    assign overflow = sub_en ? ((~b[15] &  a[15] & result[15]) |
                                ( b[15] & ~a[15] & ~result[15])) :
                               ((~b[15] & ~a[15] & result[15]) |
                                ( b[15] &  a[15] & ~result[15]));

endmodule
