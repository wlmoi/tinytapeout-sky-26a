`default_nettype none

module tt_um_william_pll (
  input  wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input  wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input  wire       ena,
  input  wire       clk,
  input  wire       rst_n
);

  wire pll_enable;
  wire pll_clk_out;
  wire pll_clk_div2;
  wire pll_clk_div4;
  wire pll_lock;
  wire pll_almost_lock;
  wire [15:0] pll_ctrl_mon;
  wire pll_pfd_up;
  wire pll_pfd_down;

  assign pll_enable = ena & ui_in[0];

  pll_smartcard_top #(
    .REF_FREQ_HZ     (13_560_000),
    .OUT_FREQ_HZ     (54_240_000),
    .DIV_RATIO       (4),
    .CTRL_WIDTH      (16),
    .DIV_WIDTH       (8),
    .LOCK_THRESHOLD  (16),
    .PROP_GAIN       (64),
    .INT_GAIN        (24)
  ) u_pll (
    .ref_clk_in      (clk),
    .reset_n         (rst_n),
    .enable          (pll_enable),
    .div_ratio_cfg   ({4'b0, ui_in[7:4]}),
    .cp_gain_cfg     (uio_in[3:0]),