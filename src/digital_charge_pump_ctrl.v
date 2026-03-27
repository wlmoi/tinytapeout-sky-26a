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