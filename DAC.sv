module DAC (
    input  logic         clk,
    input  logic         reset,  // Phase increment to control frequency
    output logic         spi_sclk,
    output logic         spi_mosi,
    output logic         spi_cs
);


wire clk_o;
pll pll_out(
	.inclk0(clk),
	.c0(clk_o));



    // Internal signals
    logic [7:0] phase;
    logic [9:0] sine;
    logic [5:0] bit_cnt;          // Bit counter (5 bits to count 0-16)
    logic [15:0] data;            // Data register
	 reg clk_out = 1'b0;
	 logic [31:0]  phase_inc = 32'd68719476;
	 logic [31:0] phase_acc;
	 
	 //logic [9:0] dac_value = 10'b1000101001;
	 
    typedef enum logic [3:0] {
        IDLE = 4'b0000,
        LOAD = 4'b0001,
        TRANSFER = 4'b0010,
        DONE = 4'b0011
    } state_t;

    state_t next_state, state;

    // Phase accumulator logic
		 // Use the top 8 bits for addressing
		 
    
	 assign phase = phase_acc[31:24];
    always_ff @(posedge clk_out or posedge reset) begin
        if (reset) begin
            phase_acc <= 32'b0;
        end else begin
            phase_acc <= phase_acc + phase_inc;
				
        end
    end
	 // Use the top 8 bits for addressing

    // Sine LUT logic
	 
    logic [9:0] LUT [0:255] = '{ 10'd512, 10'd525, 10'd537, 10'd550, 10'd562, 10'd575, 10'd587,
											10'd599, 10'd612, 10'd624, 10'd636, 10'd648, 10'd660, 10'd672,
											10'd684, 10'd696, 10'd708, 10'd719, 10'd730, 10'd742, 10'd753,
											10'd764, 10'd775, 10'd785, 10'd796, 10'd806, 10'd816, 10'd826,
											10'd836, 10'd846, 10'd855, 10'd864, 10'd873, 10'd882, 10'd891,
											10'd899, 10'd907, 10'd915, 10'd922, 10'd930, 10'd937, 10'd944,
											10'd950, 10'd957, 10'd963, 10'd968, 10'd974, 10'd979, 10'd984,
											10'd989, 10'd993, 10'd997, 10'd1001, 10'd1004, 10'd1008, 10'd1011,
											10'd1013, 10'd1015, 10'd1017, 10'd1019, 10'd1021, 10'd1022, 10'd1022,
											10'd1023, 10'd1023, 10'd1023, 10'd1022, 10'd1022, 10'd1021, 10'd1019,
											10'd1017, 10'd1015, 10'd1013, 10'd1011, 10'd1008, 10'd1004, 10'd1001,
											10'd997, 10'd993, 10'd989, 10'd984, 10'd979, 10'd974, 10'd968,
											10'd963, 10'd957, 10'd950, 10'd944, 10'd937, 10'd930, 10'd922,
											10'd915, 10'd907, 10'd899, 10'd891, 10'd882, 10'd873, 10'd864,
											10'd855, 10'd846, 10'd836, 10'd826, 10'd816, 10'd806, 10'd796,
											10'd785, 10'd775, 10'd764, 10'd753, 10'd742, 10'd730, 10'd719,
											10'd708, 10'd696, 10'd684, 10'd672, 10'd660, 10'd648, 10'd636,
											10'd624, 10'd612, 10'd599, 10'd587, 10'd575, 10'd562, 10'd550,
											10'd537, 10'd525, 10'd512, 10'd499, 10'd487, 10'd474, 10'd462,
											10'd449, 10'd437, 10'd425, 10'd412, 10'd400, 10'd388, 10'd376,
											10'd364, 10'd352, 10'd340, 10'd328, 10'd316, 10'd305, 10'd294,
											10'd282, 10'd271, 10'd260, 10'd249, 10'd239, 10'd228, 10'd218,
											10'd208, 10'd198, 10'd188, 10'd178, 10'd169, 10'd160, 10'd151,
											10'd142, 10'd133, 10'd125, 10'd117, 10'd109, 10'd102, 10'd94,
											10'd87, 10'd80, 10'd74, 10'd67, 10'd61, 10'd56, 10'd50,
											10'd45, 10'd40, 10'd35, 10'd31, 10'd27, 10'd23, 10'd20,
											10'd16, 10'd13, 10'd11, 10'd9, 10'd7, 10'd5, 10'd3,
											10'd2, 10'd2, 10'd1, 10'd1, 10'd1, 10'd2, 10'd2,
											10'd3, 10'd5, 10'd7, 10'd9, 10'd11, 10'd13, 10'd16,
											10'd20, 10'd23, 10'd27, 10'd31, 10'd35, 10'd40, 10'd45,
											10'd50, 10'd56, 10'd61, 10'd67, 10'd74, 10'd80, 10'd87,
											10'd94, 10'd102, 10'd109, 10'd117, 10'd125, 10'd133, 10'd142,
											10'd151, 10'd160, 10'd169, 10'd178, 10'd188, 10'd198, 10'd208,
											10'd218, 10'd228, 10'd239, 10'd249, 10'd260, 10'd271, 10'd282,
											10'd294, 10'd305, 10'd316, 10'd328, 10'd340, 10'd352, 10'd364,
											10'd376, 10'd388, 10'd400, 10'd412, 10'd425, 10'd437, 10'd449,
											10'd462, 10'd474, 10'd487, 10'd499
    };
    always_ff @(posedge clk_out or posedge reset) begin
        if (reset) begin
            sine <= 10'b0;
        end else begin
            sine <= LUT[phase];
        end
    end

    // State transition logic
    always_ff @(posedge clk_o or posedge reset) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @* begin
        next_state = state;
        case (state)
            IDLE: begin
                if (1'b1) begin // This condition should be adjusted based on your start criteria
                    next_state = LOAD;
                end
            end
            LOAD: begin
                next_state = TRANSFER;
            end
            TRANSFER: begin
                if (bit_cnt == 5'd0) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // Output logic and bit counter
    always_ff @(posedge clk_o or posedge reset) begin
        if (reset) begin
            spi_cs <= 1'b1;
            spi_sclk <= 1'b1;
            spi_mosi <= 1'b0;
            bit_cnt <= 5'd0;
				clk_out <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    spi_cs <= 1'b1;
                    spi_sclk <= 1'b1;
						  clk_out <= 1'b0;
                end
					 
                LOAD: begin
                    data <= {4'd0,sine,2'd0};
                    bit_cnt <= 5'd16;
                    spi_cs <= 1'b1;
						  
						  spi_sclk <= 1'b1;
                end

                TRANSFER: begin
					 
                    if (spi_sclk == 1'b1) begin  // On falling edge of spi_sclk
						      spi_cs <= 1'b0;
                        spi_mosi <= data[bit_cnt-1'b1];
                        bit_cnt <= bit_cnt - 1'b1;
                    end
						  spi_sclk <= ~spi_sclk;
                end
					 
                DONE: begin
                    //spi_cs <= 1'b1;
						  spi_sclk <= 1'b1;
						  spi_mosi <= 1'b0;
						  clk_out <= 1'b1;
						  spi_cs <= 1'b1;
                end
            endcase
        end
    end

endmodule
