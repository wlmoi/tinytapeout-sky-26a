// ============================================================================
// PLL Top-Level Module for Smart Card Clock Generator
// ============================================================================
// Description: Complete Phase-Locked Loop system
//              Generates stable internal clock from 13.56 MHz carrier
//              Compliant with ISO/IEC 14443 smart card standard
// Technology: SkyWater 130nm PDK
// Author: ASIC Engineer
// Date: February 2026
// ============================================================================

module pll_smartcard_top #(
    // PLL Configuration Parameters
    parameter REF_FREQ_HZ = 13_560_000,       // Reference frequency (ISO 14443)
    parameter OUT_FREQ_HZ = 54_240_000,       // Output frequency (4x ref)
    parameter DIV_RATIO = 4,                  // Feedback divider ratio
    parameter CTRL_WIDTH = 16,                // Control voltage resolution
    parameter DIV_WIDTH = 8,                  // Divider width
    parameter LOCK_THRESHOLD = 16,            // Lock detection threshold
    
    // Loop Filter Parameters
    parameter PROP_GAIN = 64,                 // Proportional gain
    parameter INT_GAIN = 16                   // Integral gain
)(
    // System Interface
    input  wire                     ref_clk_in,      // 13.56 MHz reference from carrier
    input  wire                     reset_n,         // Active low reset
    input  wire                     enable,          // PLL enable
    
    // Configuration Interface
    input  wire [DIV_WIDTH-1:0]     div_ratio_cfg,   // Programmable division ratio
    input  wire [3:0]               cp_gain_cfg,     // Charge pump gain config
    
    // Output Interface
    output wire                     clk_out,         // PLL output clock
    output wire                     clk_div2,        // Clock/2 output
    output wire                     clk_div4,        // Clock/4 output
    output wire                     lock,            // Lock indicator
    output wire                     almost_lock,     // Almost lock indicator
    
    // Debug/Monitor Interface
    output wire [CTRL_WIDTH-1:0]    vco_ctrl_mon,    // VCO control voltage monitor
    output wire                     pfd_up_mon,      // PFD UP monitor
    output wire                     pfd_down_mon     // PFD DOWN monitor
);

    // ========================================================================
    // Internal Signals
    // ========================================================================
    
    // Phase Frequency Detector signals
    wire pfd_up, pfd_down;
    
    // Charge Pump signals
    wire cp_up, cp_down;
    wire [3:0] cp_gain;
    
    // Loop Filter signals
    wire [CTRL_WIDTH-1:0] ctrl_voltage;
    
    // VCO signals
    wire vco_clk;
    wire [7:0] vco_ctrl_scaled;
    
    // Frequency Divider signals
    wire fb_clk;              // Feedback clock
    wire div_enable;
    
    // Clock domain signals
    wire ref_clk_buf;
    wire vco_clk_buf;
    
    // ========================================================================
    // Input Clock Buffering
    // ========================================================================
    
    // Buffer reference clock
    assign ref_clk_buf = ref_clk_in;
    
    // ========================================================================
    // Phase Frequency Detector (PFD)
    // ========================================================================
    
    phase_frequency_detector u_pfd (
        .ref_clk    (ref_clk_buf),
        .fb_clk     (fb_clk),
        .reset_n    (reset_n & enable),
        .up         (pfd_up),
        .down       (pfd_down)
    );
    
    // ========================================================================
    // Digital Charge Pump Controller
    // ========================================================================
    
    digital_charge_pump_ctrl u_cp_ctrl (
        .clk        (ref_clk_buf),
        .reset_n    (reset_n & enable),
        .up         (pfd_up),
        .down       (pfd_down),
        .cp_up      (cp_up),
        .cp_down    (cp_down),
        .cp_gain    (cp_gain)
    );
    
    // ========================================================================
    // Loop Filter
    // ========================================================================
    
    loop_filter #(
        .CTRL_WIDTH (CTRL_WIDTH),
        .PROP_GAIN  (PROP_GAIN),
        .INT_GAIN   (INT_GAIN),
        .CTRL_BIAS  (-8) // Tuned to minimize frequency error
    ) u_loop_filter (
        .clk            (ref_clk_buf),
        .reset_n        (reset_n & enable),
        .cp_up          (cp_up),
        .cp_down        (cp_down),
        .cp_gain        (cp_gain),
        .ctrl_voltage   (ctrl_voltage)
    );
    
    // ========================================================================
    // VCO (Voltage Controlled Oscillator)
    // ========================================================================
    
    // Scale control voltage to VCO input width
    assign vco_ctrl_scaled = ctrl_voltage[CTRL_WIDTH-1:CTRL_WIDTH-8];
    
    vco_digital_model #(
        .CENTER_FREQ    (OUT_FREQ_HZ),
        .KVCO           (50_000_000),
        .VDD            (18),
        .CTRL_WIDTH     (8),
        .CTRL_OFFSET    (0),
        .CALIB_NUM      (10058),
        .CALIB_DEN      (10000)
    ) u_vco (
        .enable         (enable),
        .reset_n        (reset_n),
        .ctrl_voltage   (vco_ctrl_scaled),
        .clk_out        (vco_clk)
    );
    
    // Buffer VCO output
    assign vco_clk_buf = vco_clk;
    
    // ========================================================================
    // Feedback Divider
    // ========================================================================
    
    assign div_enable = enable & reset_n;
    
    frequency_divider #(
        .DIV_WIDTH      (DIV_WIDTH),
        .DEFAULT_DIV    (DIV_RATIO)
    ) u_feedback_divider (
        .clk_in         (vco_clk_buf),
        .reset_n        (reset_n),
        .div_ratio      (div_ratio_cfg),
        .enable         (div_enable),
        .clk_out        (fb_clk)
    );
    
    // ========================================================================
    // Output Clock Dividers
    // ========================================================================
    
    // Main output
    assign clk_out = vco_clk_buf;
    
    // Divide by 2 output
    frequency_divider #(
        .DIV_WIDTH      (8),
        .DEFAULT_DIV    (2)
    ) u_div2 (
        .clk_in         (vco_clk_buf),
        .reset_n        (reset_n),
        .div_ratio      (8'd2),
        .enable         (div_enable),
        .clk_out        (clk_div2)
    );
    
    // Divide by 4 output
    frequency_divider #(
        .DIV_WIDTH      (8),
        .DEFAULT_DIV    (4)
    ) u_div4 (
        .clk_in         (vco_clk_buf),
        .reset_n        (reset_n),
        .div_ratio      (8'd4),
        .enable         (div_enable),
        .clk_out        (clk_div4)
    );
    
    // ========================================================================
    // Lock Detector
    // ========================================================================
    
    lock_detector #(
        .LOCK_THRESHOLD     (LOCK_THRESHOLD),
        .UNLOCK_THRESHOLD   (4)
    ) u_lock_detector (
        .clk            (ref_clk_buf),
        .reset_n        (reset_n & enable),
        .up             (pfd_up),
        .down           (pfd_down),
        .ref_clk        (ref_clk_buf),
        .fb_clk         (fb_clk),
        .lock           (lock),
        .almost_lock    (almost_lock)
    );
    
    // ========================================================================
    // Debug/Monitor Outputs
    // ========================================================================
    
    assign vco_ctrl_mon = ctrl_voltage;
    assign pfd_up_mon = pfd_up;
    assign pfd_down_mon = pfd_down;

endmodule

// ============================================================================
// PLL Smart Card Wrapper with Standard Interface
// ============================================================================

module pll_smartcard_wrapper (
    // Standard Interface
    input  wire         ref_clk_13_56mhz,   // ISO 14443 carrier input
    input  wire         rst_n,               // Reset
    input  wire         pll_en,              // PLL enable
    
    // Primary Outputs
    output wire         clk_54mhz,           // Main 54 MHz output
    output wire         clk_27mhz,           // 27 MHz output
    output wire         clk_13mhz,           // ~13 MHz output
    output wire         locked,              // Lock status
    
    // Status
    output wire [15:0]  status_reg
);

    wire almost_lock_int;
    wire [15:0] vco_ctrl_mon;
    wire pfd_up, pfd_down;
    
    // Instantiate PLL top module
    pll_smartcard_top #(
        .REF_FREQ_HZ        (13_560_000),
        .OUT_FREQ_HZ        (54_240_000),
        .DIV_RATIO          (4),
        .CTRL_WIDTH         (16),
        .PROP_GAIN          (64),
        .INT_GAIN           (24)
    ) u_pll (
        .ref_clk_in         (ref_clk_13_56mhz),
        .reset_n            (rst_n),
        .enable             (pll_en),
        .div_ratio_cfg      (8'd4),
        .cp_gain_cfg        (4'h8),
        .clk_out            (clk_54mhz),
        .clk_div2           (clk_27mhz),
        .clk_div4           (clk_13mhz),
        .lock               (locked),
        .almost_lock        (almost_lock_int),
        .vco_ctrl_mon       (vco_ctrl_mon),
        .pfd_up_mon         (pfd_up),
        .pfd_down_mon       (pfd_down)
    );
    
    // Status register
    assign status_reg = {
        12'b0,
        pfd_down,
        pfd_up,
        almost_lock_int,
        locked
    };

endmodule
