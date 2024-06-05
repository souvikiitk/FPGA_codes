module DDS_main_tb;

    // Testbench signals
    reg clk;
    reg reset;
    
    wire W_CLK;
    wire FQ_UD;
    wire DATA;
    wire RESET;
	 wire led1;
	 wire led2;

    // Instantiate the DUT (Device Under Test)
    DDS_main dut (
        .clk(clk),
        .reset(reset),
        
        .W_CLK(W_CLK),
        .FQ_UD(FQ_UD),
        .DATA(DATA),
        .RESET(RESET),
		  .led1(led1),
		  .led2(led2)
    );

    // Clock generation
    initial begin
        clk = 0;
        repeat(5000) #5 clk = ~clk; // 100 MHz clock (10 ns period)
    end

    // Test sequence
    initial begin
        // Initialize signals
        reset = 1;
        //freq = 10000000; // Example frequency tuning word

        // Apply reset
        #20 reset = 0;
			#10000
        // Stop simulation
        $stop;
    end

    // Monitor signals
    initial begin
        $monitor("Time=%0d clk=%b reset=%b W_CLK=%b FQ_UD=%b DATA=%b RESET=%b",
                 $time, clk, reset, W_CLK, FQ_UD, DATA, RESET);
    end

endmodule
