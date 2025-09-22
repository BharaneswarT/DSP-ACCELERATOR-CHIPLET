`timescale 1ns/1ps

module clock_manager_tb;

    // DUT inputs
    reg clk_in;
    reg reset;
    reg enable_fir;
    reg enable_fft;
    reg enable_dma;

    // DUT outputs
    wire clk_fir;
    wire clk_fft;
    wire clk_dma;

    // Instantiate DUT
    clock_manager uut (
        .clk_in(clk_in),
        .reset(reset),
        .enable_fir(enable_fir),
        .enable_fft(enable_fft),
        .enable_dma(enable_dma),
        .clk_fir(clk_fir),
        .clk_fft(clk_fft),
        .clk_dma(clk_dma)
    );

    // Clock generation: 10ns period (100 MHz)
    initial begin
        clk_in = 0;
        forever #5 clk_in = ~clk_in;  
    end

    // Stimulus
    initial begin
        // Initialize
        reset = 1;
        enable_fir = 0;
        enable_fft = 0;
        enable_dma = 0;

        // Hold reset for some time
        #20 reset = 0;

        // Enable FIR clock
        #30 enable_fir = 1;

        // Enable FFT clock later
        #50 enable_fft = 1;

        // Enable DMA clock later
        #50 enable_dma = 1;

        // Disable reset again midway to test latch hold
        #100 reset = 1;
        #20 reset = 0;

        // Run some more cycles
        #200;

        $display("Simulation finished at time %t", $time);
        $stop;  // pause simulation
        //$finish; // use this to completely end simulation
    end

    // Monitor signals
    initial begin
        $monitor("t=%0t | reset=%b | en_fir=%b en_fft=%b en_dma=%b | clk_fir=%b clk_fft=%b clk_dma=%b",
                  $time, reset, enable_fir, enable_fft, enable_dma,
                  clk_fir, clk_fft, clk_dma);
    end

endmodule
