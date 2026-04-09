module ripple_adder_16 (
    input  wire [15:0] x,
    input  wire [15:0] y,
    input  wire        cin,
    output wire [15:0] sum,
    output wire        cout
);

    wire [16:0] c;

    assign c[0] = cin;
    assign cout = c[16];

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_fa
            full_adder fa (
                .a   (x[i]),
                .b   (y[i]),
                .cin (c[i]),
                .sum (sum[i]),
                .cout(c[i+1])
            );
        end
    endgenerate

endmodule
