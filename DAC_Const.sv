module DAC (
    input  logic         clk,
    input  logic         reset,  // Phase increment to control frequency
    output logic         spi_sclk,
    output logic         spi_mosi,
    output logic         spi_cs
);

pll pll_tb(
	.inclk0(clk),
	.c0(clk_out));

    // Internal signals
    //logic [7:0] phase;
    //logic [7:0] sine;
    logic [5:0] bit_cnt;          // Bit counter (5 bits to count 0-16)
    logic [9:0] data;            // Data register
	 //reg clk_out = 1'b0;
	 //logic [31:0]  phase_inc = 32'd34359738;
	 
	 logic [15:0] dac_value = 16'b0000111000000000;
	 
    typedef enum logic [3:0] {
        IDLE = 4'b0000,
        LOAD = 4'b0001,
        TRANSFER = 4'b0010,
        DONE = 4'b0011
    } state_t;

    state_t next_state, state;

    // Phase accumulator logic
    //logic [31:0] phase_acc;

    //assign phase = phase_acc[31:24]; // Use the top 8 bits for addressing


    // State transition logic
    always_ff @(posedge clk_out or posedge reset) begin
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
                next_state = TRANSFER;
            end
        endcase
    end

    // Output logic and bit counter
    always_ff @(posedge clk_out or posedge reset) begin
        if (reset) begin
            spi_cs <= 1'b1;
            spi_sclk <= 1'b1;
            spi_mosi <= 1'b1;
            bit_cnt <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    spi_cs <= 1'b1;
                    spi_sclk <= 1'b1;
                end
					 
                LOAD: begin
                    //data <= dac_value;
                    bit_cnt <= 5'd16;
                    spi_cs <= 1'b1;
						  
						  //spi_sclk <= 1'b0;
                end

                TRANSFER: begin
					 
                    if (spi_sclk == 1'b1) begin  // On falling edge of spi_sclk
						      spi_cs <= 1'b0;
                        spi_mosi <= dac_value[bit_cnt-1'b1];
                        bit_cnt <= bit_cnt - 1'b1;
                    end
						  spi_sclk <= ~spi_sclk;
                end
					 
                DONE: begin
                    spi_cs <= 1'b1;
						  spi_sclk <= 1'b1;
						  spi_mosi <= 1'b1;
						  bit_cnt <= 5'd16;
                end
            endcase
        end
    end

endmodule
