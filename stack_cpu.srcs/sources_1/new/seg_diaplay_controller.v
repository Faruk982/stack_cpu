// ============================================================================
// 4-Digit 7-Segment Display Controller (Hexadecimal)
//
// Multiplexes across all 4 digits on the Basys 3 display.
// Displays a 16-bit value as 4 hex digits (0x0000 – 0xFFFF).
//
// Uses the existing hex_to_7seg decoder for each nibble.
// Refresh rate: 100 MHz / 2^18 ≈ 381 Hz per digit ≈ 95 Hz total
// ============================================================================

module seg_display_controller (
    input  wire        clk,         // 100 MHz system clock
    input  wire [15:0] value,       // 16-bit input value (from OUT_REG)
    output wire [6:0]  seg,         // 7-segment cathode signals
    output reg  [3:0]  an          // 7-segment anode signals (active-low)
);

    // Refresh counter for digit multiplexing
    reg [18:0] refresh_counter = 0;
    wire [1:0] digit_select;

    // Nibble extraction
    wire [3:0] nibble3, nibble2, nibble1, nibble0;
    reg  [3:0] current_digit;

    // Extract 4 hex nibbles from 16-bit value
    assign nibble0 = value[3:0];    // Rightmost digit (AN0)
    assign nibble1 = value[7:4];    // Second digit    (AN1)
    assign nibble2 = value[11:8];   // Third digit     (AN2)
    assign nibble3 = value[15:12];  // Leftmost digit  (AN3)

    // Refresh counter — free-running
    always @(posedge clk) begin
        refresh_counter <= refresh_counter + 1;
    end

    // Use top 2 bits of counter to select which digit to display
    assign digit_select = refresh_counter[18:17];

    // Anode control and digit selection
    always @(*) begin
        case (digit_select)
            2'b00: begin
                an = 4'b1110;           // Enable AN0 (rightmost)
                current_digit = nibble0;
            end
            2'b01: begin
                an = 4'b1101;           // Enable AN1
                current_digit = nibble1;
            end
            2'b10: begin
                an = 4'b1011;           // Enable AN2
                current_digit = nibble2;
            end
            2'b11: begin
                an = 4'b0111;           // Enable AN3 (leftmost)
                current_digit = nibble3;
            end
            default: begin
                an = 4'b1111;           // All off
                current_digit = 4'h0;
            end
        endcase
    end

    // Instantiate hex-to-7-segment decoder
    hex_to_7seg decoder (
        .hex(current_digit),
        .seg(seg)
    );

endmodule
