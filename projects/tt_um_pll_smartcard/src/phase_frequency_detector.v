// ============================================================================
// Phase Frequency Detector (PFD)
// ============================================================================
// Description: Phase-Frequency Detector for PLL
//              Detects both phase and frequency differences between
//              reference clock (13.56 MHz carrier) and feedback clock
// Technology: SkyWater 130nm
// Author: ASIC Engineer
// Date: February 2026
// ============================================================================

module phase_frequency_detector (
    input  wire ref_clk,        // Reference clock (13.56 MHz from carrier)
    input  wire fb_clk,         // Feedback clock from divider
    input  wire reset_n,        // Active low reset
    output reg  up,             // UP signal to charge pump
    output reg  down            // DOWN signal to charge pump
);

    // Standard PFD: set on edges, async reset when both high
    reg up_ff, down_ff;
    wire rst_pfd_n;

    assign rst_pfd_n = reset_n & ~(up_ff & down_ff);

    always @(posedge ref_clk or negedge rst_pfd_n) begin
        if (!rst_pfd_n) begin
            up_ff <= 1'b0;
        end else begin
            up_ff <= 1'b1;
        end
    end

    always @(posedge fb_clk or negedge rst_pfd_n) begin
        if (!rst_pfd_n) begin
            down_ff <= 1'b0;
        end else begin
            down_ff <= 1'b1;
        end
    end

    always @(*) begin
        up = up_ff;
        down = down_ff;
    end

endmodule
