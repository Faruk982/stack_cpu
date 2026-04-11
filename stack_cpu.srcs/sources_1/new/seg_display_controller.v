// ============================================================================
// 4-Digit 7-Segment Display Controller (Hexadecimal)
//
// Multiplexes across all 4 digits on the Basys 3 display.
// Digit-select update rate: 100 MHz / 2^17 ≈ 763 Hz
// Full 4-digit scan rate:   100 MHz / 2^19 ≈ 191 Hz (per-digit refresh)
// ============================================================================

module seg_display_controller (
    input  wire        clk,
    input  wire        rst,       // Synchronous reset
    input  wire [15:0] value,
    output wire [6:0]  seg,
    output reg  [3:0]  an
);

    reg [18:0] refresh_counter;
    wire [1:0] digit_select;

    wire [3:0] nibble3, nibble2, nibble1, nibble0;
    reg  [3:0] current_digit;

    assign nibble0 = value[3:0];
    assign nibble1 = value[7:4];
    assign nibble2 = value[11:8];
    assign nibble3 = value[15:12];

    always @(posedge clk) begin
        if (rst)
            refresh_counter <= 19'd0;
        else
            refresh_counter <= refresh_counter + 1;
    end

    assign digit_select = refresh_counter[18:17];

    always @(*) begin
        case (digit_select)
            2'b00: begin an = 4'b1110; current_digit = nibble0; end
            2'b01: begin an = 4'b1101; current_digit = nibble1; end
            2'b10: begin an = 4'b1011; current_digit = nibble2; end
            2'b11: begin an = 4'b0111; current_digit = nibble3; end
            default: begin an = 4'b1111; current_digit = 4'h0;  end
        endcase
    end

    hex_to_7seg decoder (
        .hex(current_digit),
        .seg(seg)
    );

endmodule