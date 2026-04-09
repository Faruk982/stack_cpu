module full_adder (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire cout
);

    wire sum_ab;
    wire carry_ab;
    wire carry_cin;

    half_adder ha0 (
        .a(a),
        .b(b),
        .sum(sum_ab),
        .carry(carry_ab)
    );

    half_adder ha1 (
        .a(sum_ab),
        .b(cin),
        .sum(sum),
        .carry(carry_cin)
    );

    assign cout = carry_ab | carry_cin;

endmodule
