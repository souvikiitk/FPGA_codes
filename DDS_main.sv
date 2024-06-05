module DDS_main (
    input wire clk,           // System clock
    input wire reset,         // System reset
       // Desired frequency tuning word
    output reg W_CLK,         // AD9850 W_CLK pin
    output reg FQ_UD,         // AD9850 FQ_UD pin
    output reg DATA,          // AD9850 DATA pin (single bit for serial)
    output reg RESET,	 // AD9850 RESET pin
	 output reg led1 = 0,
	 output reg led2 = 0
	 
);

    // Parameters
    localparam REF_CLK = 125000000; // Reference clock frequency (125 MHz)
    localparam TUNING_WORD_WIDTH = 32;
	 localparam freq = 200000;
	
		
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
    typedef enum logic [2:0] {
        IDLE = 3'b000,
        RESET_PULSE = 3'b001,
        SEND_TW = 3'b010,
        SEND_CTRL_BYTE = 3'b011,
        UPDATE_FREQ = 3'b100
    } state_t;

    state_t state, next_state;

    // Bit counter for serial communication
    reg [5:0] bit_count;

    // Clock divider to slow down the clock for AD9850
    reg [7:0] clk_div;
    wire slow_clk = clk_div[7];
	 reg update_prog = 1'b0;
	 //reg [63:0] counter=0;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            clk_div <= 8'b0;
        end else begin
            clk_div <= clk_div + 1;
        end
    end
	 


    // FSM: State transitions
    always @(posedge slow_clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
        end else if(!update_prog) begin
            state <= next_state;
				led1 <=~ led1; 
        end
    end

    // FSM: Next state logic
    always @(*) begin
        next_state = state; // Default to current state
        case (state)
            IDLE: next_state = RESET_PULSE;
            RESET_PULSE: next_state = SEND_TW;
            SEND_TW: next_state = (bit_count == 6'd31) ? SEND_CTRL_BYTE : SEND_TW;
            SEND_CTRL_BYTE: next_state = (bit_count == 6'd39) ? UPDATE_FREQ : SEND_CTRL_BYTE;
            UPDATE_FREQ: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // FSM: Output logic
    always @(posedge slow_clk or posedge reset) begin
        if (reset) begin
            W_CLK <= 1'b0;
            FQ_UD <= 1'b0;
            DATA <= 1'b0;
				//led2 <= 1'b0;
				
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
                RESET_PULSE: begin
                    RESET <= 1'b1;
						  //led1 <= 1'b1;
                    bit_count <= 6'd0; // Reset bit counter
                    W_CLK <= 1'b0;
						  
                end
                SEND_TW: begin
                    RESET <= 1'b0;
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
                    W_CLK <= 1'b0;
						  update_prog <= 1'b1;
						  led2<= 1'b1;
                end
            endcase
        end
    end
endmodule