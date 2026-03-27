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