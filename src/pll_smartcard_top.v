`default_nettype none

module pll_smartcard_top #(
    parameter REF_FREQ_HZ = 13_560_000,
    parameter OUT_FREQ_HZ = 54_240_000,
    parameter DIV_RATIO = 4,
    parameter CTRL_WIDTH = 16,
    parameter DIV_WIDTH = 8,
    parameter LOCK_THRESHOLD = 16,
    parameter PROP_GAIN = 64,
    parameter INT_GAIN = 16
)(
    input  wire                     ref_clk_in,
    input  wire                     reset_n,
    input  wire                     enable,
    input  wire [DIV_WIDTH-1:0]     div_ratio_cfg,
    input  wire [3:0]               cp_gain_cfg,
    output wire                     clk_out,
    output wire                     clk_div2,
    output wire                     clk_div4,
    output wire                     lock,
    output wire                     almost_lock,
    output wire [CTRL_WIDTH-1:0]    vco_ctrl_mon,
    output wire                     pfd_up_mon,
    output wire                     pfd_down_mon
);

    wire pfd_up, pfd_down;
    wire cp_up, cp_down;
    wire [3:0] cp_gain;
    wire [CTRL_WIDTH-1:0] ctrl_voltage;
    wire vco_clk;
    wire [7:0] vco_ctrl_scaled;
    wire fb_clk;
    wire div_enable;
    wire ref_clk_buf;
    wire vco_clk_buf;

    assign ref_clk_buf = ref_clk_in;