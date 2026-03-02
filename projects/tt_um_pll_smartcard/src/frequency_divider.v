// ============================================================================
// Programmable Frequency Divider
// ============================================================================
// Description: Multi-modulus frequency divider for PLL feedback path
//              Supports integer and fractional-N division ratios
//              Configurable division ratio for flexible output frequencies
// Technology: SkyWater 130nm
// Author: ASIC Engineer
// Date: February 2026
// ============================================================================

module frequency_divider #(
    parameter DIV_WIDTH = 8,            // Division ratio width
    parameter DEFAULT_DIV = 8'd4        // Default division ratio
)(
    input  wire                 clk_in,     // Input clock from VCO
    input  wire                 reset_n,    // Active low reset
    input  wire [DIV_WIDTH-1:0] div_ratio,  // Programmable division ratio
    input  wire                 enable,     // Enable signal
    output reg                  clk_out     // Divided output clock
);

    // Internal counter
    reg [DIV_WIDTH-1:0] counter;
    reg [DIV_WIDTH-1:0] div_value;
    reg                 phase;          // 0 = low phase, 1 = high phase
    reg [DIV_WIDTH-1:0] high_count;
    reg [DIV_WIDTH-1:0] low_count;

    // Clock generation logic
    // Generates a true divide-by-N clock (not divide-by-2N).
    // For odd N, duty cycle is approximate by alternating high/low counts.
    always @(posedge clk_in or negedge reset_n) begin
        if (!reset_n) begin
            counter   <= {DIV_WIDTH{1'b0}};
            clk_out   <= 1'b0;
            div_value <= DEFAULT_DIV;
            phase     <= 1'b0;
            high_count <= DEFAULT_DIV >> 1;
            low_count  <= (DEFAULT_DIV + 1) >> 1;
        end else if (enable) begin
            // Update division ratio only at boundary
            if (counter == 0 && phase == 0) begin
                div_value <= (div_ratio == 0) ? DEFAULT_DIV : div_ratio;
                // Split N cycles into high/low portions
                // low_count = floor(N/2), high_count = ceil(N/2)
                low_count  <= (( (div_ratio == 0) ? DEFAULT_DIV : div_ratio )) >> 1;
                high_count <= (( (div_ratio == 0) ? DEFAULT_DIV : div_ratio ) + 1'b1) >> 1;
                if (((div_ratio == 0) ? DEFAULT_DIV : div_ratio) == 1) begin
                    // Divide-by-1: pass through (best effort in sequential logic)
                    high_count <= 1;
                    low_count  <= 0;
                end
            end

            // Divide-by-1 passthrough
            if (div_value == 1) begin
                clk_out <= clk_in;
                counter <= 0;
                phase   <= 0;
            end else if (div_value == 2) begin
                // Special case for divide-by-2: simple toggle
                clk_out <= ~clk_out;
                counter <= 0;
                phase   <= 0;
            end else begin
                // Determine how long to stay in current phase
                // phase=0 -> count low_count cycles then go high
                // phase=1 -> count high_count cycles then go low
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

// ============================================================================
// Multi-Modulus Divider (MMD) for Fractional-N PLL
// ============================================================================

module multi_modulus_divider #(
    parameter DIV_WIDTH = 8
)(
    input  wire                 clk_in,         // Input clock from VCO
    input  wire                 reset_n,        // Active low reset
    input  wire [DIV_WIDTH-1:0] div_n,          // N divider value
    input  wire [DIV_WIDTH-1:0] div_n_plus_1,   // N+1 divider value
    input  wire                 modulus_ctrl,    // 0=divide by N, 1=divide by N+1
    output reg                  clk_out          // Divided output clock
);

    reg [DIV_WIDTH-1:0] counter;
    reg [DIV_WIDTH-1:0] current_div;
    reg                 phase;
    reg [DIV_WIDTH-1:0] high_count;
    reg [DIV_WIDTH-1:0] low_count;

    always @(posedge clk_in or negedge reset_n) begin
        if (!reset_n) begin
            counter     <= {DIV_WIDTH{1'b0}};
            clk_out     <= 1'b0;
            current_div <= div_n;
            phase       <= 1'b0;
            high_count  <= {DIV_WIDTH{1'b0}};
            low_count   <= {DIV_WIDTH{1'b0}};
        end else begin
            // Select division ratio based on modulus control
            if (counter == 0) begin
                current_div <= modulus_ctrl ? div_n_plus_1 : div_n;
                high_count  <= (( (modulus_ctrl ? div_n_plus_1 : div_n) ) + 1'b1) >> 1;
                low_count   <= (( (modulus_ctrl ? div_n_plus_1 : div_n) )) >> 1;
                if ((modulus_ctrl ? div_n_plus_1 : div_n) == 1) begin
                    high_count <= 1;
                    low_count  <= 0;
                end
            end

            if (current_div == 1) begin
                clk_out <= clk_in;
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
        end
    end

endmodule

// ============================================================================
// Dual Modulus Prescaler (High-Speed Divider)
// ============================================================================

module dual_modulus_prescaler (
    input  wire clk_in,         // High-speed input from VCO
    input  wire reset_n,        // Active low reset
    input  wire modulus_ctrl,   // 0=divide by 4, 1=divide by 5
    output reg  clk_out         // Prescaled output
);

    reg [2:0] counter;
    reg [2:0] div_value;
    reg       phase;
    reg [2:0] high_count;
    reg [2:0] low_count;

    always @(posedge clk_in or negedge reset_n) begin
        if (!reset_n) begin
            counter    <= 3'b0;
            clk_out    <= 1'b0;
            div_value  <= 3'd4;
            phase      <= 1'b0;
            high_count <= 3'd2;
            low_count  <= 3'd2;
        end else begin
            if (counter == 0) begin
                div_value  <= modulus_ctrl ? 3'd5 : 3'd4;
                high_count <= ((modulus_ctrl ? 3'd5 : 3'd4) + 3'd1) >> 1;
                low_count  <= ((modulus_ctrl ? 3'd5 : 3'd4)) >> 1;
            end

            if (!phase) begin
                if (counter == (low_count - 1)) begin
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
    end

endmodule
