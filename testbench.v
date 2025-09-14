`timescale 1ns/1ps

module dsp_chiplet_tb;

    parameter DATA_WIDTH = 12;
    parameter BUFFER_SIZE = 256;
    parameter FFT_N = 16;

    reg clk, reset;
    reg valid_in;
    reg [DATA_WIDTH-1:0] sample_in;
    reg write_enable;
    reg [4:0] config_in;
    reg dma_ack = 1'b1;

    wire ready_for_processing;
    wire start_fir, start_fft, start_dma_out;
    wire [4:0] config_mode;
    wire clk_fir, clk_fft, clk_dma;
    wire [DATA_WIDTH-1:0] fir_output;
    wire fir_done, fft_done, dma_done;
    wire processing_active;
    wire buffer_ready;
    wire dma_valid;
    wire [DATA_WIDTH-1:0] dma_data_out;
    wire signed [DATA_WIDTH-1:0] dma_real, dma_imag;
    wire done;

    wire [DATA_WIDTH*FFT_N-1:0] fft_real_out_flat;
    wire [DATA_WIDTH*FFT_N-1:0] fft_imag_out_flat;
    wire [DATA_WIDTH*256-1:0] dma_output_flat;

    // Instantiate input buffer
    input_buffer1 #(.DATA_WIDTH(DATA_WIDTH), .BUFFER_SIZE(BUFFER_SIZE)) u_input_buffer (
        .clk(clk), .reset(reset), .valid_in(valid_in),
        .sample_in(sample_in), .ready_for_processing(ready_for_processing)
    );

    // Instantiate controller
    controller #(.BLOCK_SIZE(BUFFER_SIZE)) u_controller (
        .clk(clk), .reset(reset),
        .ready_for_processing(ready_for_processing),
        .fir_done(fir_done), .fft_done(fft_done),
        .config_mode(config_mode[0]),
        .start_fir(start_fir), .start_fft(start_fft),
        .start_dma_out(start_dma_out), .processing_active(processing_active)
    );

    // Instantiate config register
    config_register u_config (
        .clk(clk), .reset(reset), .write_enable(write_enable),
        .config_in(config_in), .config_mode(config_mode)
    );

    // Instantiate clock manager
    clock_manager u_clock_manager (
        .clk_in(clk), .reset(reset),
        .enable_fir(start_fir), .enable_fft(start_fft), .enable_dma(start_dma_out),
        .clk_fir(clk_fir), .clk_fft(clk_fft), .clk_dma(clk_dma)
    );

    // Instantiate FIR filter
    fir_filter #(.DATA_WIDTH(DATA_WIDTH), .TAPS(16)) u_fir (
        .clk(clk_fir), .reset(reset), .start_fir(start_fir),
        .filter_mode(2'b00),
        .input_buffer(u_input_buffer.buffer),
        .fir_output(fir_output), .fir_done(fir_done)
    );

    // Instantiate FFT core
    wire [DATA_WIDTH*FFT_N-1:0] fft_real_in_flat;
    wire [DATA_WIDTH*FFT_N-1:0] fft_imag_in_flat;
    wire [$clog2(FFT_N)-1:0] twiddle_addr;
    wire signed [DATA_WIDTH-1:0] twiddle_real, twiddle_imag;

    fft_core #(.DATA_WIDTH(DATA_WIDTH), .N(FFT_N)) u_fft (
        .clk(clk_fft), .reset(reset), .start_fft(start_fft),
        .real_in(fft_real_in_flat), .imag_in(fft_imag_in_flat),
        .twiddle_addr(twiddle_addr), .twiddle_real(twiddle_real),
        .twiddle_imag(twiddle_imag),
        .real_out(fft_real_out_flat), .imag_out(fft_imag_out_flat),
        .fft_done(fft_done)
    );

    // Instantiate twiddle ROM
    twiddle_rom #(.DATA_WIDTH(DATA_WIDTH), .N(FFT_N)) u_twiddle (
        .addr(twiddle_addr),
        .twiddle_real(twiddle_real),
        .twiddle_imag(twiddle_imag)
    );

    // Instantiate IFFT core
    wire [DATA_WIDTH*FFT_N-1:0] ifft_real_out_flat;
    wire [DATA_WIDTH*FFT_N-1:0] ifft_imag_out_flat;

    ifft_core #(.DATA_WIDTH(DATA_WIDTH), .N(FFT_N)) u_ifft (
        .clk(clk_fft), .reset(reset), .start_ifft(start_fft),
        .real_in(fft_real_out_flat), .imag_in(fft_imag_out_flat),
        .twiddle_addr(twiddle_addr), .twiddle_real(twiddle_real),
        .twiddle_imag(twiddle_imag),
        .real_out(ifft_real_out_flat), .imag_out(ifft_imag_out_flat),
        .ifft_done(fft_done)
    );

    // Instantiate output buffer
    wire [DATA_WIDTH*FFT_N-1:0] output_real_in_flat = ifft_real_out_flat;
    wire [DATA_WIDTH*FFT_N-1:0] output_imag_in_flat = ifft_imag_out_flat;
    wire [DATA_WIDTH*FFT_N-1:0] output_real_out_flat;
    wire [DATA_WIDTH*FFT_N-1:0] output_imag_out_flat;

    output_buffer #(.DATA_WIDTH(DATA_WIDTH), .N(FFT_N)) u_output (
        .clk(clk), .reset(reset), .store(fft_done), .read_en(dma_valid),
        .read_addr(dma_done ? 0 : 4'hF), .read_done(dma_done),
        .real_in(output_real_in_flat), .imag_in(output_imag_in_flat),
        .real_out(output_real_out_flat), .imag_out(output_imag_out_flat),
        .buffer_ready(buffer_ready)
    );

    // Instantiate DMA controller
    dma_controller #(.DATA_WIDTH(DATA_WIDTH), .BLOCK_SIZE(BUFFER_SIZE)) u_dma (
        .clk(clk_dma), .reset(reset), .start_dma_out(start_dma_out),
        .output_buffer_flat(dma_output_flat),
        .dma_data_out(dma_data_out), .dma_valid(dma_valid), .dma_done(dma_done)
    );

    // Instantiate interface
    interface1 #(.DATA_WIDTH(DATA_WIDTH), .N(FFT_N)) u_interface (
        .clk(clk), .reset(reset), .buffer_ready(buffer_ready),
        .real_in(output_real_out_flat), .imag_in(output_imag_out_flat),
        .dma_ack(dma_ack), .dma_real(dma_real), .dma_imag(dma_imag),
        .dma_valid(dma_valid), .done(done),
        .write_enable(write_enable), .config_in(config_in)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Stimulus
    initial begin
        $dumpfile("dsp_chiplet_tb.vcd");
        $dumpvars(0, dsp_chiplet_tb);

        reset = 1;
        valid_in = 0;
        sample_in = 0;
        write_enable = 0;
        config_in = 5'b00001;

        #20 reset = 0;
        #10 write_enable = 1;
        #10 write_enable = 0;

        repeat (BUFFER_SIZE) begin
            valid_in = 1;
            sample_in = $random % (1 << DATA_WIDTH);
            #10;
            valid_in = 0;
            #10;
        end

        wait (dma_done);
        $display("DMA completed at time %t", $time);
        #100;
        $finish;
    end

    initial $monitor("Time=%0t | FIR=%b FFT=%b DMA=%b Active=%b BufferReady=%b",
                     $time, fir_done, fft_done, dma_done, processing_active, buffer_ready);

endmodule
