`timescale 1ns / 1ps

module tb_config_register;

    // Testbench signals
    reg clk;
    reg reset;
    reg write_enable;
    reg [4:0] config_in;
    wire [4:0] config_mode;

    // Instantiate the module
    config_register uut (
        .clk(clk),
        .reset(reset),
        .write_enable(write_enable),
        .config_in(config_in),
        .config_mode(config_mode)
    );

    // Clock generation: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Test sequence
    initial begin
        // Initialize signals
        reset = 0;
        write_enable = 0;
        config_in = 5'b00000;

        // Apply reset
        $display("Applying reset...");
        reset = 1;
        #10;
        reset = 0;
        #10;

        // Write new config values
        $display("Writing new config values...");

        config_in = 5'b00011; 
        write_enable = 1;
        #10;
        write_enable = 0;
        #10;

        config_in = 5'b10101;
        write_enable = 1;
        #10;
        write_enable = 0;
        #10;

        config_in = 5'b11111;
        write_enable = 1;
        #10;
        write_enable = 0;
        #10;

        $display("Test completed.");
        $stop;
    end

    // Monitor the output
    initial begin
        $monitor("Time=%0t | reset=%b | write_enable=%b | config_in=%b | config_mode=%b", 
                 $time, reset, write_enable, config_in, config_mode);
    end

endmodule
