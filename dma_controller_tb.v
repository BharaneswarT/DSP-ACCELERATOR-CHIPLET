`timescale 1ns / 1ps

module tb_dma_controller;

    parameter DATA_WIDTH = 12;
    parameter BLOCK_SIZE = 8; // smaller block size for simulation

    reg clk;
    reg reset;
    reg start_dma_out;
    reg [DATA_WIDTH*BLOCK_SIZE-1:0] output_buffer_flat;

    wire [DATA_WIDTH-1:0] dma_data_out;
    wire dma_valid;
    wire dma_done;

    // Instantiate DMA controller
    dma_controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .BLOCK_SIZE(BLOCK_SIZE)
    ) uut (
        .clk(clk),
        .reset(reset),
        .start_dma_out(start_dma_out),
        .output_buffer_flat(output_buffer_flat),
        .dma_data_out(dma_data_out),
        .dma_valid(dma_valid),
        .dma_done(dma_done)
    );

    // Clock generation: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // Initialize signals
        reset = 1;
        start_dma_out = 0;
        output_buffer_flat = 0;
        #20;

        reset = 0;
        #10;

        // Load test data into flattened buffer
        output_buffer_flat = {12'd100, 12'd200, 12'd300, 12'd400, 12'd500, 12'd600, 12'd700, 12'd800};
        #10;

        // Start DMA
        start_dma_out = 1;
        #10;
        start_dma_out = 0;

        // Wait for DMA to finish
        wait(dma_done == 1);
        #10;

        $display("DMA transfer completed");
        $stop;
    end

    // Monitor signals
    initial begin
        $monitor("Time=%0t | dma_ptr=%0d | dma_data_out=%0d | dma_valid=%b | dma_done=%b", 
                 $time, uut.dma_ptr, dma_data_out, dma_valid, dma_done);
    end

endmodule
