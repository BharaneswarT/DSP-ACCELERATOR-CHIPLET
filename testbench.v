`timescale 1ns/1ps

module dsp_chiplet_tb;

    // Parameters
    parameter DATA_WIDTH = 12;
    parameter BUFFER_SIZE = 256;
    parameter BLOCK_SIZE = 256;
    parameter TAPS = 16;
    parameter FFT_N = 16;

    // Clock and reset
    reg clk;
    reg reset;

    // Input buffer signals
    reg valid_in;
    reg [DATA_WIDTH-1:0] sample_in;
    wire ready_for_processing;

    // Controller signals
    wire start_fir;
    wire start_fft;
    wire start_dma_out;
    wire processing_active;

    // Config register signals
    reg write_enable;
    reg [4:0] config_in;
    wire [4:0] config_mode;

    // Clock manager signals
    wire clk_fir;
    wire clk_fft;
    wire clk_dma;

    // DMA controller signals
    wire [DATA_WIDTH*BLOCK_SIZE-1:0] output_buffer_flat;
    wire [DATA_WIDTH-1:0] dma_data_out;
    wire dma_valid;
    wire dma_done;

    // FIR filter signals
    wire [1:0] filter_mode = 2'b00; // LPF mode
    wire signed [DATA_WIDTH-1:0] fir_output;
    wire fir_done;

    // FFT core signals
    wire [$clog2(FFT_N)-1:0] twiddle_addr;
    wire signed [DATA_WIDTH-1:0] twiddle_real;
    wire signed [DATA_WIDTH-1:0] twiddle_imag;
    wire signed [DATA_WIDTH-1:0] real_out [0:FFT_N-1];
    wire signed [DATA_WIDTH-1:0] imag_out [0:FFT_N-1];
    wire fft_done;

    // IFFT core signals
    wire start_ifft;
    wire signed [DATA_WIDTH-1:0] ifft_real_out [0:FFT_N-1];
    wire signed [DATA_WIDTH-1:0] ifft_imag_out [0:FFT_N-1];
    wire ifft_done;

    // Output buffer signals
    wire buffer_ready;
    wire signed [DATA_WIDTH-1:0] real_in [0:FFT_N-1];
    wire signed [DATA_WIDTH-1:0] imag_in [0:FFT_N-1];

    // Interface signals
    wire signed [DATA_WIDTH-1:0] dma_real;
    wire signed [DATA_WIDTH-1:0] dma_imag;
    wire dma_ack = 1'b1; // Assume DMA always acknowledges
    wire done;

    // Flattened arrays for connection
    wire [DATA_WIDTH*FFT_N-1:0] fft_real_in_flat;
    wire [DATA_WIDTH*FFT_N-1:0] fft_imag_in_flat;
    wire [DATA_WIDTH*FFT_N-1:0] fft_real_out_flat;
    wire [DATA_WIDTH*FFT_N-1:0] fft_imag_out_flat;
    wire [DATA_WIDTH*FFT_N-1:0] ifft_real_in_flat;
    wire [DATA_WIDTH*FFT_N-1:0] ifft_imag_in_flat;
    wire [DATA_WIDTH*FFT_N-1:0] ifft_real_out_flat;
    wire [DATA_WIDTH*FFT_N-1:0] ifft_imag_out_flat;
    wire [DATA_WIDTH*FFT_N-1:0] output_real_in_flat;
    wire [DATA_WIDTH*FFT_N-1:0] output_imag_in_flat;

    // Instantiate modules
    input_buffer1 #(.DATA_WIDTH(DATA_WIDTH), .BUFFER_SIZE(BUFFER_SIZE)) 
        u_input_buffer1 (.clk(clk), .reset(reset), .valid_in(valid_in), 
                        .sample_in(sample_in), .ready_for_processing(ready_for_processing));

    controller #(.BLOCK_SIZE(BLOCK_SIZE)) 
        u_controller (.clk(clk), .reset(reset), .ready_for_processing(ready_for_processing), 
                     .fir_done(fir_done), .fft_done(fft_done), .config_mode(config_mode[0]), 
                     .start_fir(start_fir), .start_fft(start_fft), .start_dma_out(start_dma_out), 
                     .processing_active(processing_active));

    config_register u_config_register (.clk(clk), .reset(reset), .write_enable(write_enable), 
                                      .config_in(config_in), .config_mode(config_mode));

    clock_manager u_clock_manager (.clk_in(clk), .reset(reset), 
                                  .enable_fir(start_fir), .enable_fft(start_fft), 
                                  .enable_dma(start_dma_out), 
                                  .clk_fir(clk_fir), .clk_fft(clk_fft), .clk_dma(clk_dma));

    dma_controller #(.DATA_WIDTH(DATA_WIDTH), .BLOCK_SIZE(BLOCK_SIZE)) 
        u_dma_controller (.clk(clk), .reset(reset), .start_dma_out(start_dma_out), 
                         .output_buffer_flat(output_buffer_flat), .dma_data_out(dma_data_out), 
                         .dma_valid(dma_valid), .dma_done(dma_done));

    fir_filter #(.DATA_WIDTH(DATA_WIDTH), .TAPS(TAPS)) 
        u_fir_filter (.clk(clk_fir), .reset(reset), .start_fir(start_fir), 
                     .filter_mode(filter_mode), .input_buffer(u_input_buffer1.buffer), 
                     .fir_output(fir_output), .fir_done(fir_done));

    // FFT core with flattened ports
    fft_core #(.DATA_WIDTH(DATA_WIDTH), .N(FFT_N)) 
        u_fft_core (.clk(clk_fft), .reset(reset), .start_fft(start_fft), 
                   .real_in(fft_real_in_flat[DATA_WIDTH*FFT_N-1:0]), 
                   .imag_in(fft_imag_in_flat[DATA_WIDTH*FFT_N-1:0]), 
                   .twiddle_addr(twiddle_addr), .twiddle_real(twiddle_real), 
                   .twiddle_imag(twiddle_imag), 
                   .real_out(fft_real_out_flat[DATA_WIDTH*FFT_N-1:0]), 
                   .imag_out(fft_imag_out_flat[DATA_WIDTH*FFT_N-1:0]), 
                   .fft_done(fft_done));

    twiddle_rom #(.DATA_WIDTH(DATA_WIDTH), .N(FFT_N)) 
        u_twiddle_rom (.addr(twiddle_addr), .twiddle_real(twiddle_real), 
                      .twiddle_imag(twiddle_imag));

    // IFFT core with flattened ports
    ifft_core #(.DATA_WIDTH(DATA_WIDTH), .N(FFT_N)) 
        u_ifft_core (.clk(clk_fft), .reset(reset), .start_ifft(start_fft), 
                    .real_in(ifft_real_in_flat[DATA_WIDTH*FFT_N-1:0]), 
                    .imag_in(ifft_imag_in_flat[DATA_WIDTH*FFT_N-1:0]), 
                    .twiddle_addr(twiddle_addr), .twiddle_real(twiddle_real), 
                    .twiddle_imag(twiddle_imag), 
                    .real_out(ifft_real_out_flat[DATA_WIDTH*FFT_N-1:0]), 
                    .imag_out(ifft_imag_out_flat[DATA_WIDTH*FFT_N-1:0]), 
                    .ifft_done(ifft_done));

    output_buffer #(.DATA_WIDTH(DATA_WIDTH), .N(FFT_N)) 
        u_output_buffer (.clk(clk), .reset(reset), .store(fft_done), .read_en(dma_valid), 
                        .read_addr(dma_done ? 0 : 4'hF), .read_done(dma_done), 
                        .real_in(ifft_real_out_flat[DATA_WIDTH*FFT_N-1:0]), 
                        .imag_in(ifft_imag_out_flat[DATA_WIDTH*FFT_N-1:0]), 
                        .real_out(output_real_in_flat[DATA_WIDTH*FFT_N-1:0]), 
                        .imag_out(output_imag_in_flat[DATA_WIDTH*FFT_N-1:0]), 
                        .buffer_ready(buffer_ready));

    interface1 #(.DATA_WIDTH(DATA_WIDTH), .N(FFT_N)) 
        u_interface1 (.clk(clk), .reset(reset), .buffer_ready(buffer_ready), 
                     .real_in(output_real_in_flat[DATA_WIDTH*FFT_N-1:0]), 
                     .imag_in(output_imag_in_flat[DATA_WIDTH*FFT_N-1:0]), 
                     .dma_ack(dma_ack), .dma_real(dma_real), .dma_imag(dma_imag), 
                     .dma_valid(dma_valid), .done(done));

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // Test stimulus
    initial begin
        // Initialize
        reset = 1;
        valid_in = 0;
        sample_in = 0;
        write_enable = 0;
        config_in = 5'b00001; // Set to FFT mode

        // Reset
        #20 reset = 0;

        // Write config
        #10 write_enable = 1;
        #10 write_enable = 0;

        // Feed input samples
        #20 valid_in = 1;
        sample_in = 12'h100; // Example input
        #10 valid_in = 0;

        // Wait for processing
        #1000;

        // Check outputs
        if (done) $display("Test passed: DMA transfer complete");
        else $display("Test failed: DMA transfer not complete");

        #100 $finish;
    end

    // Monitor
    initial begin
        $monitor("Time=%0t ready_for_processing=%b processing_active=%b dma_done=%b", 
                 $time, ready_for_processing, processing_active, dma_done);
    end

    // Unpack flattened arrays (simplified for testbench)
    genvar i;
    generate
        for (i = 0; i < FFT_N; i = i + 1) begin : unpack_arrays
            assign fft_real_in_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] = u_input_buffer1.buffer[i];
            assign fft_imag_in_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] = 0; // Zero imag for FFT
            assign real_out[i] = fft_real_out_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH];
            assign imag_out[i] = fft_imag_out_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH];
            assign ifft_real_in_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] = real_out[i];
            assign ifft_imag_in_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] = imag_out[i];
            assign ifft_real_out[i] = ifft_real_out_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH];
            assign ifft_imag_out[i] = ifft_imag_out_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH];
            assign real_in[i] = output_real_in_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH];
            assign imag_in[i] = output_imag_in_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH];
        end
    endgenerate
endmodule