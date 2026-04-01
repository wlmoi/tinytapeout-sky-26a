// ----- src/project.v -----
`default_nettype none

module tt_um_william_pll (
  input  wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input  wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input  wire       ena,
  input  wire       clk,
    input  wire       rst_n,
  input  wire       VPWR,
  input  wire       VGND
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
    .clk_out         (pll_clk_out),
    .clk_div2        (pll_clk_div2),
    .clk_div4        (pll_clk_div4),
    .lock            (pll_lock),
    .almost_lock     (pll_almost_lock),
    .vco_ctrl_mon    (pll_ctrl_mon),
    .pfd_up_mon      (pll_pfd_up),
    .pfd_down_mon    (pll_pfd_down)
  );

  assign uo_out[0] = pll_lock;
  assign uo_out[1] = pll_almost_lock;
  assign uo_out[2] = pll_clk_div4;
  assign uo_out[3] = pll_clk_div2;
  assign uo_out[4] = pll_clk_out;
  assign uo_out[5] = pll_pfd_up;
  assign uo_out[6] = pll_pfd_down;
  assign uo_out[7] = pll_enable;

  assign uio_out[7:4] = pll_ctrl_mon[3:0];
  assign uio_out[3:0] = 4'b0;

  assign uio_oe = 8'b11110000;

  // Keep lint clean for intentionally unused control bits.
  wire _unused = &{ui_in[3:1], uio_in[7:4], 1'b0};
  wire _unused_power = &{VPWR, VGND, 1'b0};

endmodule

// ----- src/pll_smartcard_top.v -----
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

    phase_frequency_detector u_pfd (
        .ref_clk    (ref_clk_buf),
        .fb_clk     (fb_clk),
        .reset_n    (reset_n & enable),
        .up         (pfd_up),
        .down       (pfd_down)
    );

    digital_charge_pump_ctrl u_cp_ctrl (
        .clk        (ref_clk_buf),
        .reset_n    (reset_n & enable),
        .up         (pfd_up),
        .down       (pfd_down),
        .cp_up      (cp_up),
        .cp_down    (cp_down),
        .cp_gain    (cp_gain)
    );

    loop_filter #(
        .CTRL_WIDTH (CTRL_WIDTH),
        .PROP_GAIN  (PROP_GAIN),
        .INT_GAIN   (INT_GAIN),
        .CTRL_BIAS  (-8)
    ) u_loop_filter (
        .clk            (ref_clk_buf),
        .reset_n        (reset_n & enable),
        .cp_up          (cp_up),
        .cp_down        (cp_down),
        .cp_gain        (cp_gain),
        .ctrl_voltage   (ctrl_voltage)
    );

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

    assign vco_clk_buf = vco_clk;
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

    assign clk_out = vco_clk_buf;

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

    assign vco_ctrl_mon = ctrl_voltage;
    assign pfd_up_mon = pfd_up;
    assign pfd_down_mon = pfd_down;

    wire _unused = &{cp_gain_cfg, 1'b0};

endmodule

// ----- src/phase_frequency_detector.v -----
`default_nettype none

module phase_frequency_detector (
    input  wire ref_clk,
    input  wire fb_clk,
    input  wire reset_n,
    output reg  up,
    output reg  down
);

    reg up_ff, down_ff;

    always @(posedge ref_clk or negedge reset_n) begin
        if (!reset_n) begin
            up_ff <= 1'b0;
        end else if (down_ff) begin
            up_ff <= 1'b0;
        end else begin
            up_ff <= 1'b1;
        end
    end

    always @(posedge fb_clk or negedge reset_n) begin
        if (!reset_n) begin
            down_ff <= 1'b0;
        end else if (up_ff) begin
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

// ----- src/digital_charge_pump_ctrl.v -----
`default_nettype none

module digital_charge_pump_ctrl (
    input  wire       clk,
    input  wire       reset_n,
    input  wire       up,
    input  wire       down,
    output reg        cp_up,
    output reg        cp_down,
    output reg  [3:0] cp_gain
);

    parameter DEFAULT_GAIN = 4'b1000;
    parameter MIN_PULSE_WIDTH = 2;

    reg [3:0] up_counter;
    reg [3:0] down_counter;
    reg up_active, down_active;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            up_counter <= 4'b0;
            down_counter <= 4'b0;
            up_active <= 1'b0;
            down_active <= 1'b0;
            cp_up <= 1'b0;
            cp_down <= 1'b0;
            cp_gain <= DEFAULT_GAIN;
        end else begin
            if (up) begin
                up_active <= 1'b1;
                up_counter <= MIN_PULSE_WIDTH;
                cp_up <= 1'b1;
            end else if (up_counter > 0) begin
                up_counter <= up_counter - 1'b1;
                cp_up <= 1'b1;
            end else begin
                up_active <= 1'b0;
                cp_up <= 1'b0;
            end

            if (down) begin
                down_active <= 1'b1;
                down_counter <= MIN_PULSE_WIDTH;
                cp_down <= 1'b1;
            end else if (down_counter > 0) begin
                down_counter <= down_counter - 1'b1;
                cp_down <= 1'b1;
            end else begin
                down_active <= 1'b0;
                cp_down <= 1'b0;
            end

            if (up && down) begin
                cp_up <= 1'b0;
                cp_down <= 1'b0;
            end
        end
    end

    reg [1:0] gain_state;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            gain_state <= 2'b00;
        end else begin
            case (gain_state)
                2'b00: gain_state <= 2'b00;
                2'b01: gain_state <= 2'b01;
                2'b10: gain_state <= 2'b10;
                2'b11: gain_state <= 2'b11;
            endcase
        end
    end

    wire _unused = &{up_active, down_active, 1'b0};

endmodule

// ----- src/loop_filter.v -----
`default_nettype none

module loop_filter #(
    parameter CTRL_WIDTH = 16,
    parameter PROP_GAIN = 8'd64,
    parameter INT_GAIN = 8'd16,
    parameter CTRL_BIAS = 0
)(
    input  wire                    clk,
    input  wire                    reset_n,
    input  wire                    cp_up,
    input  wire                    cp_down,
    input  wire [3:0]              cp_gain,
    output reg  [CTRL_WIDTH-1:0]   ctrl_voltage
);

    reg signed [CTRL_WIDTH+7:0] integrator;
    reg signed [CTRL_WIDTH+7:0] proportional;
    reg signed [CTRL_WIDTH+7:0] filter_output;
    wire signed [CTRL_WIDTH+7:0] mid_scale;
    assign mid_scale = (1 <<< (CTRL_WIDTH-1)) + CTRL_BIAS;

    wire signed [7:0] phase_error;
    assign phase_error = cp_up ? $signed(cp_gain) :
                        cp_down ? -$signed(cp_gain) : 8'sd0;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            integrator <= {(CTRL_WIDTH+8){1'b0}};
            proportional <= {(CTRL_WIDTH+8){1'b0}};
            filter_output <= mid_scale;
            ctrl_voltage <= mid_scale[CTRL_WIDTH-1:0];
        end else begin
            proportional <= phase_error * PROP_GAIN;

            if (integrator < ((1 << (CTRL_WIDTH+6)) - 1) &&
                integrator > -(1 << (CTRL_WIDTH+6))) begin
                integrator <= integrator + (phase_error * INT_GAIN);
            end else if (phase_error < 0 && integrator > 0) begin
                integrator <= integrator + (phase_error * INT_GAIN);
            end else if (phase_error > 0 && integrator < 0) begin
                integrator <= integrator + (phase_error * INT_GAIN);
            end

            filter_output <= mid_scale + proportional + (integrator >>> 6);

            if (filter_output < 0) begin
                ctrl_voltage <= {CTRL_WIDTH{1'b0}};
            end else if (filter_output >= (1 << CTRL_WIDTH)) begin
                ctrl_voltage <= {CTRL_WIDTH{1'b1}};
            end else begin
                ctrl_voltage <= filter_output[CTRL_WIDTH-1:0];
            end
        end
    end

endmodule

// ----- src/vco_digital_model.v -----
`default_nettype none

module vco_digital_model #(
    parameter CENTER_FREQ = 54_240_000,
    parameter KVCO = 50_000_000,
    parameter VDD = 18,
    parameter CTRL_WIDTH = 8,
    parameter CTRL_OFFSET = 0,
    parameter CALIB_NUM = 10000,
    parameter CALIB_DEN = 10000
)(
    input  wire                    enable,
    input  wire                    reset_n,
    input  wire [CTRL_WIDTH-1:0]   ctrl_voltage,
    output reg                     clk_out
);

`ifdef VCO_BEHAVIORAL
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
    always @(*) begin
        clk_out = enable & reset_n & 1'b0;
    end

    wire _unused = &{ctrl_voltage, CENTER_FREQ, KVCO, VDD, CALIB_NUM, CALIB_DEN, 1'b0};
`endif

endmodule

// ----- src/frequency_divider.v -----
`default_nettype none

module frequency_divider #(
    parameter DIV_WIDTH = 8,
    parameter DEFAULT_DIV = 8'd4
)(
    input  wire                 clk_in,
    input  wire                 reset_n,
    input  wire [DIV_WIDTH-1:0] div_ratio,
    input  wire                 enable,
    output reg                  clk_out
);

    reg [DIV_WIDTH-1:0] counter;
    reg [DIV_WIDTH-1:0] div_value;
    reg                 phase;
    reg [DIV_WIDTH-1:0] high_count;
    reg [DIV_WIDTH-1:0] low_count;

    always @(posedge clk_in or negedge reset_n) begin
        if (!reset_n) begin
            counter   <= {DIV_WIDTH{1'b0}};
            clk_out   <= 1'b0;
            div_value <= DEFAULT_DIV;
            phase     <= 1'b0;
            high_count <= DEFAULT_DIV >> 1;
            low_count  <= (DEFAULT_DIV + 1) >> 1;
        end else if (enable) begin
            if (counter == 0 && phase == 0) begin
                div_value <= (div_ratio == 0) ? DEFAULT_DIV : div_ratio;
                low_count  <= (((div_ratio == 0) ? DEFAULT_DIV : div_ratio)) >> 1;
                high_count <= (((div_ratio == 0) ? DEFAULT_DIV : div_ratio) + 1'b1) >> 1;
                if (((div_ratio == 0) ? DEFAULT_DIV : div_ratio) == 1) begin
                    high_count <= 1;
                    low_count  <= 0;
                end
            end

            if (div_value == 1) begin
                clk_out <= clk_in;
                counter <= 0;
                phase   <= 0;
            end else if (div_value == 2) begin
                clk_out <= ~clk_out;
                counter <= 0;
                phase   <= 0;
            end else begin
                if (!phase) begin
                    if (low_count == 0) begin
                        phase   <= 1'b1;
                        clk_out <= 1'b1;
                        counter <= 0;
                    end else if (counter == (low_count - 1)) begin
                        phase   <= 1'b1;
                        clk_out <= 1'b1;
                        counter <= 0;
                    end else begin
                        counter <= counter + 1'b1;
                    end
                end else begin
                    if (counter == (high_count - 1)) begin
                        phase   <= 1'b0;
                        clk_out <= 1'b0;
                        counter <= 0;
                    end else begin
                        counter <= counter + 1'b1;
                    end
                end
            end
        end else begin
            counter <= {DIV_WIDTH{1'b0}};
            clk_out <= 1'b0;
            phase   <= 1'b0;
        end
    end

endmodule

// ----- src/lock_detector.v -----
`default_nettype none

module lock_detector #(
    parameter LOCK_THRESHOLD = 8'd16,
    parameter UNLOCK_THRESHOLD = 8'd4
)(
    input  wire clk,
    input  wire reset_n,
    input  wire up,
    input  wire down,
    input  wire ref_clk,
    input  wire fb_clk,
    output reg  lock,
    output reg  almost_lock
);

    reg [7:0] stable_count;
    reg [7:0] error_count;
    reg [3:0] phase_error;

    localparam UNLOCKED      = 2'b00;
    localparam ACQUIRING     = 2'b01;
    localparam ALMOST_LOCKED = 2'b10;
    localparam LOCKED        = 2'b11;

    reg [1:0] lock_state;

    reg up_d, down_d;
    wire up_edge, down_edge;

    assign up_edge = up && !up_d;
    assign down_edge = down && !down_d;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            up_d <= 1'b0;
            down_d <= 1'b0;
        end else begin
            up_d <= up;
            down_d <= down;
        end
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            phase_error <= 4'b0;
        end else begin
            if (up_edge || down_edge) begin
                if (phase_error < 4'd15)
                    phase_error <= phase_error + 1'b1;
            end else begin
                if (phase_error > 0)
                    phase_error <= phase_error - 1'b1;
            end
        end
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            lock_state <= UNLOCKED;
            stable_count <= 8'b0;
            error_count <= 8'b0;
            lock <= 1'b0;
            almost_lock <= 1'b0;
        end else begin
            case (lock_state)
                UNLOCKED: begin
                    lock <= 1'b0;
                    almost_lock <= 1'b0;
                    if (phase_error < 4'd2) begin
                        stable_count <= stable_count + 1'b1;
                        if (stable_count >= (LOCK_THRESHOLD >> 2)) begin
                            lock_state <= ACQUIRING;
                            stable_count <= 8'b0;
                        end
                    end else begin
                        stable_count <= 8'b0;
                    end
                end

                ACQUIRING: begin
                    almost_lock <= 1'b0;
                    if (phase_error < 4'd2) begin
                        stable_count <= stable_count + 1'b1;
                        error_count <= 8'b0;
                        if (stable_count >= (LOCK_THRESHOLD >> 1)) begin
                            lock_state <= ALMOST_LOCKED;
                            stable_count <= 8'b0;
                        end
                    end else begin
                        error_count <= error_count + 1'b1;
                        if (error_count >= UNLOCK_THRESHOLD) begin
                            lock_state <= UNLOCKED;
                            error_count <= 8'b0;
                            stable_count <= 8'b0;
                        end
                    end
                end

                ALMOST_LOCKED: begin
                    almost_lock <= 1'b1;
                    if (phase_error < 4'd1) begin
                        stable_count <= stable_count + 1'b1;
                        error_count <= 8'b0;
                        if (stable_count >= LOCK_THRESHOLD) begin
                            lock_state <= LOCKED;
                            stable_count <= 8'b0;
                        end
                    end else if (phase_error > 4'd3) begin
                        error_count <= error_count + 1'b1;
                        if (error_count >= UNLOCK_THRESHOLD) begin
                            lock_state <= ACQUIRING;
                            error_count <= 8'b0;
                            stable_count <= 8'b0;
                        end
                    end
                end

                LOCKED: begin
                    lock <= 1'b1;
                    almost_lock <= 1'b1;
                    if (phase_error > 4'd2) begin
                        error_count <= error_count + 1'b1;
                        if (error_count >= UNLOCK_THRESHOLD) begin
                            lock_state <= ALMOST_LOCKED;
                            lock <= 1'b0;
                            error_count <= 8'b0;
                        end
                    end else begin
                        error_count <= 8'b0;
                    end
                end

                default: lock_state <= UNLOCKED;
            endcase
        end
    end

    wire _unused = &{ref_clk, fb_clk, 1'b0};

endmodule

