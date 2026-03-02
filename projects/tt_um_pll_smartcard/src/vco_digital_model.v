// ============================================================================
// Voltage Controlled Oscillator (VCO) - Digital Model
// ============================================================================
// Description: Behavioral model of VCO for digital simulation
//              Represents analog VCO with digital-friendly interface
//              Frequency controlled by digital control voltage input
// Technology: SkyWater 130nm
// Author: ASIC Engineer
// Date: February 2026
// NOTE: This is a digital behavioral model. Actual analog implementation
//       requires transistor-level design in analog domain
// ============================================================================

`timescale 1ps/1ps

module vco_digital_model #(
    parameter CENTER_FREQ = 54_240_000,      // Kept for interface compatibility
    parameter KVCO = 50_000_000,             // Kept for interface compatibility
    parameter VDD = 18,                      // Kept for interface compatibility (1.8V x10)
    parameter CTRL_WIDTH = 8,                // Control voltage resolution
    parameter CTRL_OFFSET = 0,               // Kept for interface compatibility
    parameter CALIB_NUM = 10000,             // Kept for interface compatibility
    parameter CALIB_DEN = 10000              // Kept for interface compatibility
)(
    input  wire                    enable,      // VCO enable
    input  wire                    reset_n,     // Active low reset
    input  wire [CTRL_WIDTH-1:0]   ctrl_voltage, // Digital control voltage
    output reg                     clk_out      // VCO output clock
);

`ifdef VCO_BEHAVIORAL
    // Simulation-only behavioral oscillator model.
    reg [31:0] half_period_ps;
    reg [CTRL_WIDTH-1:0] ctrl_eff;
    localparam [CTRL_WIDTH-1:0] CTRL_OFFSET_V = CTRL_OFFSET;

    always @(*) begin
        if (ctrl_voltage > CTRL_OFFSET_V) begin
            ctrl_eff = ctrl_voltage - CTRL_OFFSET_V;
        end else begin
            ctrl_eff = {CTRL_WIDTH{1'b0}};
        end

        if (ctrl_eff == 0) begin
            half_period_ps = 18440;
        end else if (ctrl_eff == 8'd128) begin
            half_period_ps = 9220;
        end else if (ctrl_eff == {CTRL_WIDTH{1'b1}}) begin
            half_period_ps = 6147;
        end else if (ctrl_eff < 8'd128) begin
            half_period_ps = 18440 - ((ctrl_eff * 9220) / 128);
        end else begin
            half_period_ps = 9220 - (((ctrl_eff - 8'd128) * 3073) / 127);
        end

        if (CALIB_DEN != 0) begin
            half_period_ps = (half_period_ps * CALIB_NUM) / CALIB_DEN;
        end

        if (half_period_ps < 6000) half_period_ps = 6000;
        if (half_period_ps > 19000) half_period_ps = 19000;
    end

    initial clk_out = 1'b0;

    always begin
        if (!reset_n || !enable) begin
            clk_out = 1'b0;
            @(reset_n or enable);
            #1;
        end else begin
            #(half_period_ps);
            clk_out = ~clk_out;
        end
    end
`else
    // Synthesis-safe placeholder for mixed-signal integration.
    reg [CTRL_WIDTH-1:0] ctrl_shadow;

    always @(*) begin
        ctrl_shadow = ctrl_voltage;
        clk_out = 1'b0;
    end
`endif

endmodule
