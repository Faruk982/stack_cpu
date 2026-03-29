// 2-Digit 7-Segment Display Controller
// Multiplexes between 2 digits on Basys 3 display
// Displays decimal value (0-31) from 5-bit input

module seg_display_controller(
    input clk,
    input [4:0] value,        // 5-bit input (0-31)
    output [6:0] seg,         // cathode signals
    output reg [3:0] an       // anode signals (active-low)
);

    // Refresh counter for digit multiplexing
    // 100MHz / 2^18 = ~381Hz per digit, ~190Hz total refresh
    reg [17:0] refresh_counter = 0;
    wire digit_select;
    
    // Decimal digit extraction
    wire [3:0] ones;
    wire [3:0] tens;
    reg [3:0] current_digit;
    
    // Extract decimal digits
    assign tens = value / 10;
    assign ones = value % 10;
    
    // Refresh counter
    always @(posedge clk) begin
        refresh_counter <= refresh_counter + 1;
    end
    
    // Use MSB of counter to select digit
    assign digit_select = refresh_counter[17];
    
    // Anode control and digit selection
    // Only use AN0 (ones) and AN1 (tens), disable AN2 and AN3
    always @(*) begin
        case(digit_select)
            1'b0: begin
                an = 4'b1110;  // Enable AN0 (rightmost)
                current_digit = ones;
            end
            1'b1: begin
                an = 4'b1101;  // Enable AN1
                current_digit = tens;
            end
            default: begin
                an = 4'b1111;  // All off
                current_digit = 4'h0;
            end
        endcase
    end
    
    // Instantiate hex to 7-seg decoder
    hex_to_7seg decoder(
        .hex(current_digit),
        .seg(seg)
    );

endmodule
