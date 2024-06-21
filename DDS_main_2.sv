module DDS_main (
    input wire clk,           // System clock
    input wire reset,         // System reset
    output reg W_CLK,         // AD9850 W_CLK pin
    output reg FQ_UD,         // AD9850 FQ_UD pin
    output reg DATA,          // AD9850 DATA pin (single bit for serial)
    output reg RESET         // AD9850 RESET pin
          // LED output for debugging
           // LED output for debugging
);

    // Parameters
    localparam REF_CLK = 125000000; // Reference clock frequency (125 MHz)
    localparam TUNING_WORD_WIDTH = 32;
    localparam freq = 20000000;
	 reg update_prog = 1'b0;

    // Calculate frequency tuning word
    reg [TUNING_WORD_WIDTH-1:0] tuning_word;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tuning_word <= 0;
        end else begin
            // Calculate tuning word: freq * 2^32 / REF_CLK
            // Using a 64-bit register to avoid overflow
            reg [63:0] tuning_word_64;
            tuning_word_64 = (freq * 64'd4294967295) / REF_CLK;
            tuning_word <= tuning_word_64[TUNING_WORD_WIDTH-1:0];
        end
    end

    // FSM state definitions
typedef enum logic [3:0] {
    IDLE = 4'b0000,
    RESET_PULSE_HIGH = 4'b0001,
	  RESET_PULSE_LOW = 4'b0010,
	  
    FQ_PULSE_HIGH = 4'b0011,
	  FQ_PULSE_LOW = 4'b0100,

	  WCLK_HIGH = 4'b0101,
	  WCLK_LOW = 4'b0110,
	  
    SEND_TW = 4'b0111 ,
	 
	 //FQ_PULSE_HIGH_LOAD = 4'b1000,
	 //FQ_PULSE_LOW_LOAD = 4'b1001,
	 
    SEND_CTRL_BYTE = 4'b1000,
    UPDATE_FREQ = 4'b1001
} state_t;

state_t state, next_state;


    // Bit counter for serial communication
    reg [5:0] bit_count;

    // Clock divider to slow down the clock for AD9850
    reg clk_out;
    integer counter = 0;
    localparam integer DIVISOR = 5; // Hardcoded division factor

    // Clock generation
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 0;
            clk_out <= 0;
        end else begin
            if (counter == (DIVISOR - 1)) begin
                counter <= 0;
                clk_out <= ~clk_out; // Toggle the output clock
            end else begin
                counter <= counter + 1;
            end
        end
    end

    // FSM: State transitions
    always @(posedge clk_out or posedge reset) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            state <= next_state; 
        end
    end

	     always @* begin
         // Default to current state
        case (state)
            IDLE: next_state = RESET_PULSE_HIGH;
            RESET_PULSE_HIGH: next_state = RESET_PULSE_LOW;
            RESET_PULSE_LOW: next_state = WCLK_HIGH;
				WCLK_HIGH: next_state = WCLK_LOW;
				WCLK_LOW: next_state = FQ_PULSE_HIGH;
            FQ_PULSE_HIGH: next_state = FQ_PULSE_LOW;
            FQ_PULSE_LOW: next_state = SEND_TW;
            SEND_TW: next_state = (bit_count == 6'd31) ? SEND_CTRL_BYTE : SEND_TW;
            SEND_CTRL_BYTE: next_state = (bit_count == 6'd39) ? UPDATE_FREQ : SEND_CTRL_BYTE;
            UPDATE_FREQ: next_state = RESET_PULSE_LOW;
            default: next_state = IDLE;
        endcase
    end
	 


    // FSM: Output logic
    always @(posedge clk_out or posedge reset) begin
        if (reset) begin
            W_CLK <= 1'b0;
            FQ_UD <= 1'b0;
            DATA <= 1'b0;
            RESET <= 1'b0; // Active low reset
            bit_count <= 6'd0;
        end else begin
            case (state)
                IDLE: begin
                    RESET <= 1'b0;
                    bit_count <= 6'd0;
                    W_CLK <= 1'b0;
                    FQ_UD <= 1'b0;
                end
                RESET_PULSE_HIGH: begin
                    RESET <= 1'b1;
                    bit_count <= 6'd0; // Reset bit counter
                    W_CLK <= 1'b0;
                    FQ_UD <= 1'b0;
                end
					 RESET_PULSE_LOW: begin
                    RESET <= 1'b0;
                    //bit_count <= 6'd0; // Reset bit counter
                    W_CLK <= 1'b0;
                    FQ_UD <= 1'b0;
						  DATA <= 1'b0;
						  bit_count <= 6'd0;
                end					 
					 WCLK_HIGH: begin
                    RESET <= 1'b0;
                    //bit_count <= 6'd0; // Reset bit counter
                    W_CLK <= 1'b1;
                    FQ_UD <= 1'b0;
                end
					 WCLK_LOW: begin
                    RESET <= 1'b0;
                    //bit_count <= 6'd0; // Reset bit counter
                    W_CLK <= 1'b0;
                    FQ_UD <= 1'b0;
                end
                FQ_PULSE_HIGH: begin
                    RESET <= 1'b0;
                    W_CLK <= 1'b0;
                    FQ_UD <= 1'b1;
                end
					 FQ_PULSE_LOW: begin
                    RESET <= 1'b0;
                    W_CLK <= 1'b0;
                    FQ_UD <= 1'b0;
                end
                SEND_TW: begin
                    RESET <= 1'b0;
                    FQ_UD <= 1'b0;
                    // Send each bit of tuning word
                    if (W_CLK == 1'b0) begin
                        DATA <= tuning_word[bit_count];
                        bit_count <= bit_count + 1; // Increment bit counter on W_CLK falling edge
                    end
                    W_CLK <= ~W_CLK; // Toggle W_CLK
                end
                SEND_CTRL_BYTE: begin
                    // Send control byte (usually 0x00, 8 bits)
                    if (W_CLK == 1'b0) begin
                        DATA <= 1'b0;
                        bit_count <= bit_count + 1; // Increment bit counter on W_CLK falling edge
                    end
                    W_CLK <= ~W_CLK; // Toggle W_CLK
                end
                UPDATE_FREQ: begin
                    FQ_UD <= 1'b1; // Pulse FQ_UD to update frequency
                    //W_CLK <= 1'b0;
						  W_CLK <= 0;
						  //update_prog <= 1'b1;
                end
            endcase
        end
    end
endmodule
