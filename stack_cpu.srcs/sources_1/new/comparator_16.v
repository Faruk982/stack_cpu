module comparator_16 (
    input  wire [15:0] a,
    input  wire [15:0] b,
    output wire        eq,
    output wire        sign,
    output wire        signed_gt,
    output wire        signed_ng
);

    wire [15:0] diff;
    wire        c_sub;
    wire        v_sub;
    wire        n_sub;
    wire        z_sub;

    adder_subtractor_16 u_cmp_sub (
        .a        (a),
        .b        (b),
        .sub_en   (1'b1),
        .result   (diff),
        .carry_out(c_sub),
        .overflow (v_sub)
    );

    assign z_sub     = (diff == 16'd0);
    assign n_sub     = diff[15];
    assign eq        = z_sub;
    assign sign      = n_sub;
    assign signed_gt = !z_sub && (n_sub == v_sub);
    assign signed_ng =  z_sub || (n_sub != v_sub);

endmodule
