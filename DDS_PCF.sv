	module DDS (
    input  logic         clk,
    input  logic         reset,
    input  logic [31:0]  phase_inc,

    output reg           ack,
    output reg           scl,
    output  reg          sda
);

    // Internal signals
    logic [7:0] phase;
    logic [7:0] sine_wave;
	 logic clk_out = 1'b0;
	 

    // Phase accumulator
    logic [31:0] phase_acc;
	 
    always_ff @(posedge clk_out or posedge reset) begin
        if (reset) begin
            phase_acc <= 32'b0;
        end else begin
            phase_acc <= phase_acc + phase_inc;
        end
    end
    assign phase = phase_acc[31:24]; // Use the top 8 bits for addressing

    // Sine LUT
    logic [7:0] LUT [0:255] = '{ 
		  8'd128, 8'd131, 8'd134, 8'd137, 8'd140, 8'd144, 8'd147, 8'd150,
        8'd153, 8'd156, 8'd159, 8'd162, 8'd165, 8'd168, 8'd171, 8'd174,
        8'd177, 8'd179, 8'd182, 8'd185, 8'd188, 8'd191, 8'd193, 8'd196,
        8'd199, 8'd201, 8'd204, 8'd206, 8'd209, 8'd211, 8'd213, 8'd216,
        8'd218, 8'd220, 8'd222, 8'd224, 8'd226, 8'd228, 8'd230, 8'd232,
        8'd234, 8'd235, 8'd237, 8'd239, 8'd240, 8'd241, 8'd243, 8'd244,
        8'd245, 8'd246, 8'd248, 8'd249, 8'd250, 8'd250, 8'd251, 8'd252,
        8'd253, 8'd253, 8'd254, 8'd254, 8'd254, 8'd255, 8'd255, 8'd255,
        8'd255, 8'd255, 8'd255, 8'd255, 8'd254, 8'd254, 8'd254, 8'd253,
        8'd253, 8'd252, 8'd251, 8'd250, 8'd250, 8'd249, 8'd248, 8'd246,
        8'd245, 8'd244, 8'd243, 8'd241, 8'd240, 8'd239, 8'd237, 8'd235,
        8'd234, 8'd232, 8'd230, 8'd228, 8'd226, 8'd224, 8'd222, 8'd220,
        8'd218, 8'd216, 8'd213, 8'd211, 8'd209, 8'd206, 8'd204, 8'd201,
        8'd199, 8'd196, 8'd193, 8'd191, 8'd188, 8'd185, 8'd182, 8'd179,
        8'd177, 8'd174, 8'd171, 8'd168, 8'd165, 8'd162, 8'd159, 8'd156,
        8'd153, 8'd150, 8'd147, 8'd144, 8'd140, 8'd137, 8'd134, 8'd131,
        8'd128, 8'd125, 8'd122, 8'd119, 8'd116, 8'd112, 8'd109, 8'd106,
        8'd103, 8'd100, 8'd97, 8'd94, 8'd91, 8'd88, 8'd85, 8'd82,
        8'd79, 8'd77, 8'd74, 8'd71, 8'd68, 8'd65, 8'd63, 8'd60,
        8'd57, 8'd55, 8'd52, 8'd50, 8'd47, 8'd45, 8'd43, 8'd40,
        8'd38, 8'd36, 8'd34, 8'd32, 8'd30, 8'd28, 8'd26, 8'd24,
        8'd22, 8'd21, 8'd19, 8'd17, 8'd16, 8'd15, 8'd13, 8'd12,
        8'd11, 8'd10, 8'd8, 8'd7, 8'd6, 8'd6, 8'd5, 8'd4,
        8'd3, 8'd3, 8'd2, 8'd2, 8'd2, 8'd1, 8'd1, 8'd1,
        8'd1, 8'd1, 8'd1, 8'd1, 8'd2, 8'd2, 8'd2, 8'd3,
        8'd3, 8'd4, 8'd5, 8'd6, 8'd6, 8'd7, 8'd8, 8'd10,
        8'd11, 8'd12, 8'd13, 8'd15, 8'd16, 8'd17, 8'd19, 8'd21,
        8'd22, 8'd24, 8'd26, 8'd28, 8'd30, 8'd32, 8'd34, 8'd36,
        8'd38, 8'd40, 8'd43, 8'd45, 8'd47, 8'd50, 8'd52, 8'd55,
        8'd57, 8'd60, 8'd63, 8'd65, 8'd68, 8'd71, 8'd74, 8'd77,
        8'd79, 8'd82, 8'd85, 8'd88, 8'd91, 8'd94, 8'd97, 8'd100,
        8'd103, 8'd106, 8'd109, 8'd112, 8'd116, 8'd119, 8'd122, 8'd125
	};
	
    always_ff @(posedge clk_out or posedge reset) begin
        if (reset) begin
            sine_wave <= 8'b0;
        end else begin
            sine_wave <= LUT[phase];
        end
    end
	 
	 

    // I2C master signals
    logic start = 1'b1;
    logic stop = 1'b0;
    logic write;
    logic [7:0] data;
	 //reg [2:0] bit_cnt;
	 logic [3:0] bit_cnt; 
	 reg [7:0] address = 8'b10011011 ;
	 
	 //logic bit_cnt;

    // State machine states
    typedef enum logic [3:0] {
        IDLE = 4'b0000,
        START_HIGH = 4'b0001,
		  START_LOW = 4'b0010, // use this as LOAD 
        ADDR = 4'b0011 ,
        ACK = 4'b0100,
		  //ACK_LOW  = 4'b0101,
		  LOAD = 4'b0110,
		  DATA = 4'b0111,
		  DONE = 4'b1000,
		  WAIT = 4'b1001,
		  STOP = 4'b1010
    } state_t;

    state_t next_state, state;
	 
    // State machine
    // State transition logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end


    // State transitions
    // Next state logic
    always @* begin
        next_state = state;
        case (state)
            IDLE: begin
                 // This condition should be adjusted based on your start criteria
                //if (start) next_state = START_HIGH;
                //else if (stop) next_state = STOP;
					 next_state <= START_HIGH;
                
            end
            START_HIGH: begin
                next_state = START_LOW;
            end
            START_LOW: begin
                next_state = ADDR;
            end
            ADDR: begin
                if (bit_cnt == 4'd0) next_state = DONE;
            end
				
				ACK: begin
                next_state = DATA;
					 
            end
				
				//ACK_LOW: begin
                //next_state = DATA;
					 
            //end
				
				LOAD: begin
					 next_state = DATA;
				end
				
				DATA: begin
                if (bit_cnt == 4'd0) next_state = DONE;
                else next_state = DATA;
            end
				
				DONE: begin
					 next_state = ACK;
				end
				
				STOP: begin
                next_state = WAIT;
            end
            WAIT: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
				
        endcase
    end

    // Control signals and I2C data
    reg [7:0] data_shift;


    // Output logic and bit counter
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            sda <= 1'b1;
				scl <= 1'b1;
				bit_cnt <= 4'd0;
				data_shift <= sine_wave;
        end else begin
            case (state)
                IDLE: begin
                    sda <= 1'b1;
						  scl <= 1'b1;
						  
                end
                START_HIGH: begin
                    sda <= 1'b0;
						  scl <= 1'b1;
						  
                end
					 START_LOW: begin
                    sda <= 1'b0;
						  scl <= 1'b1;
						  bit_cnt <= 4'd8;
						  //sda<= address[bit_cnt];
						  
                    //bit_cnt <= bit_cnt - 1;
                end
                
					 ADDR: begin
                    
                    if (scl == 1'b1) begin
                        sda<= address[bit_cnt-1];
                        bit_cnt <= bit_cnt - 1;
                    end
						  scl <= ~scl;
                end
					 
					 ACK: begin
						 sda <= 1'b0;
						 scl <= ~scl;
						 clk_out <= ~clk_out;
						 data_shift <= {1'b0, sine_wave};
					 end
					 
					 //ACK_HIGH: begin
                    //sda <= 1'b0;
						  //scl <= ~scl;
						  
						  //clk_out <= ~clk_out;
						  //data_shift <= {1'b0,sine_wave};
                //end
						
					 //ACK_LOW: begin
                 //   sda <= 1'b0;
						//  scl <= ~scl;
						  //clk_out <= ~clk_out;
						//  data_shift <= sine_wave;
						  //bit_cnt <= bit_cnt - 1;
                //end
					 LOAD: begin
                    sda <= 1'b0;
						  //scl <= ~scl;
						  scl <= ~scl;
							//sda <= data_shift[bit_cnt];
                        //bit_cnt <= bit_cnt - 1;
						  
						  //bit_cnt <= 3'd7;  
                end
					
					 
					 DATA: begin
					 
                    if (scl == 1'b1) begin
                        sda <= data_shift[bit_cnt-1];
                        bit_cnt <= bit_cnt - 1;
                    end
						  scl <= ~scl;
						  //if (bit_cnt == 3'd0) clk_out <= ~clk_out;
                end
					 
					 DONE: begin
                    sda <= 1'b0;
						  scl <= ~scl;
						  clk_out <= ~clk_out;
						  bit_cnt <= 4'd8;
                end
					
					 
            endcase
        end
    end

endmodule










