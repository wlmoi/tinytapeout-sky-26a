// ============================================================================
// Loop Filter - Digital Control
// ============================================================================
// Description: Digital representation of analog loop filter
//              Implements proportional-integral control for PLL
//              Generates control voltage for VCO
// Technology: SkyWater 130nm
// Author: ASIC Engineer
// Date: February 2026
// ============================================================================

module loop_filter #(
    parameter CTRL_WIDTH = 16,         // Control voltage width
    parameter PROP_GAIN = 8'd64,       // Proportional gain (Kp)
    parameter INT_GAIN = 8'd16,        // Integral gain (Ki)
    parameter CTRL_BIAS = 0            // Signed bias to center VCO control
)(
    input  wire                    clk,          // System clock
    input  wire                    reset_n,      // Active low reset
    input  wire                    cp_up,        // Charge pump UP
    input  wire                    cp_down,      // Charge pump DOWN
    input  wire [3:0]              cp_gain,      // Charge pump gain
    output reg  [CTRL_WIDTH-1:0]   ctrl_voltage  // Control voltage to VCO
);

    // Internal registers
    reg signed [CTRL_WIDTH+7:0] integrator;
    reg signed [CTRL_WIDTH+7:0] proportional;
    reg signed [CTRL_WIDTH+7:0] filter_output;
    wire signed [CTRL_WIDTH+7:0] mid_scale;
    assign mid_scale = (1 <<< (CTRL_WIDTH-1)) + CTRL_BIAS;
    
    // Phase error calculation
    wire signed [7:0] phase_error;
    assign phase_error = cp_up ? $signed(cp_gain) : 
                        cp_down ? -$signed(cp_gain) : 8'sd0;
    
    // Loop filter implementation (PI controller)
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            integrator <= {(CTRL_WIDTH+8){1'b0}};
            proportional <= {(CTRL_WIDTH+8){1'b0}};
            filter_output <= mid_scale;  // Mid-scale bias
            ctrl_voltage <= mid_scale[CTRL_WIDTH-1:0];
        end else begin
            // Proportional term
            proportional <= phase_error * PROP_GAIN;
            
            // Integral term (accumulator with saturation)
            if (integrator < ((1 << (CTRL_WIDTH+6)) - 1) && 
                integrator > -(1 << (CTRL_WIDTH+6))) begin
                integrator <= integrator + (phase_error * INT_GAIN);
            end else if (phase_error < 0 && integrator > 0) begin
                integrator <= integrator + (phase_error * INT_GAIN);
            end else if (phase_error > 0 && integrator < 0) begin
                integrator <= integrator + (phase_error * INT_GAIN);
            end
            
            // Combine proportional and integral terms with mid-scale bias
            filter_output <= mid_scale + proportional + (integrator >>> 6);
            
            // Saturate and convert to unsigned
            if (filter_output < 0) begin
                ctrl_voltage <= {CTRL_WIDTH{1'b0}};
            end else if (filter_output >= (1 << CTRL_WIDTH)) begin
                ctrl_voltage <= {CTRL_WIDTH{1'b1}};
            end else begin
                ctrl_voltage <= filter_output[CTRL_WIDTH-1:0];
            end
        end
    end
    
    // Optional: Adaptive bandwidth control
    reg [1:0] bandwidth_mode;
    reg [7:0] adaptive_prop_gain;
    reg [7:0] adaptive_int_gain;
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            bandwidth_mode <= 2'b00;
            adaptive_prop_gain <= PROP_GAIN;
            adaptive_int_gain <= INT_GAIN;
        end else begin
            case (bandwidth_mode)
                2'b00: begin  // Acquisition mode - high bandwidth
                    adaptive_prop_gain <= PROP_GAIN << 1;
                    adaptive_int_gain <= INT_GAIN << 1;
                end
                2'b01: begin  // Tracking mode - normal bandwidth
                    adaptive_prop_gain <= PROP_GAIN;
                    adaptive_int_gain <= INT_GAIN;
                end
                2'b10: begin  // Hold mode - low bandwidth
                    adaptive_prop_gain <= PROP_GAIN >> 1;
                    adaptive_int_gain <= INT_GAIN >> 1;
                end
                default: begin
                    adaptive_prop_gain <= PROP_GAIN;
                    adaptive_int_gain <= INT_GAIN;
                end
            endcase
        end
    end

endmodule
