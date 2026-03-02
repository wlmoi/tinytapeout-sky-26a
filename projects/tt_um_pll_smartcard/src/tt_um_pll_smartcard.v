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
    wire [7:0] div_ratio_cfg;
    wire [3:0] cp_gain_cfg;

    wire clk_out;
    wire clk_div2;
    wire clk_div4;
    wire lock;
    wire almost_lock;
    wire [15:0] vco_ctrl_mon;
    wire pfd_up_mon;
    wire pfd_down_mon;

    assign pll_enable = ena & ui_in[0];
    assign cp_gain_cfg = ui_in[4:1];
    assign div_ratio_cfg = uio_in;

    pll_smartcard_top #(
        .REF_FREQ_HZ(13_560_000),
        .OUT_FREQ_HZ(54_240_000),
        .DIV_RATIO(4),
        .CTRL_WIDTH(16),
        .DIV_WIDTH(8),
        .LOCK_THRESHOLD(16),
        .PROP_GAIN(64),
        .INT_GAIN(16)
    ) u_pll_smartcard_top (
        .ref_clk_in(clk),
        .reset_n(rst_n),
        .enable(pll_enable),
        .div_ratio_cfg(div_ratio_cfg),
        .cp_gain_cfg(cp_gain_cfg),
        .clk_out(clk_out),
        .clk_div2(clk_div2),
        .clk_div4(clk_div4),
        .lock(lock),
        .almost_lock(almost_lock),
        .vco_ctrl_mon(vco_ctrl_mon),
        .pfd_up_mon(pfd_up_mon),
        .pfd_down_mon(pfd_down_mon)
    );

    assign uo_out[0] = lock;
    assign uo_out[1] = almost_lock;
    assign uo_out[2] = clk_out;
    assign uo_out[3] = clk_div2;
    assign uo_out[4] = clk_div4;
    assign uo_out[5] = pfd_up_mon;
    assign uo_out[6] = pfd_down_mon;
    assign uo_out[7] = vco_ctrl_mon[15];

    assign uio_out = 8'h00;
    assign uio_oe = 8'h00;

endmodule
