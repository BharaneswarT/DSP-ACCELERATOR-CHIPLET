`timescale 1ns/1ps

module top (
    input clk,
    input reset,
    input valid_in,
    input [11:0] sample_in,  // DATA_WIDTH=12
    output [4:0] config_mode,
    output fir_done,
    output fft_done,
    output dma_done,
    output processing_active,
    output V  // Added output port V
);

    wire ready_for_processing;
    wire start_fir, start_fft, start_dma_out;
    wire write_enable;  // Driven from interface
    wire [4:0] config_in;
    wire clk_fir, clk_fft, clk_dma;
    wire [11:0] fir_output;
    wire [11:0] dma_data_out;
    wire dma_valid;

    // Flattened arrays for compatibility
    wire [11*16-1:0] fft_real_in_flat;
    wire [11*16-1:0] fft_imag_in_flat;
    wire [11*16-1:0] fft_real_out_flat;
    wire [11*16-1:0] fft_imag_out_flat;
    wire [11*16-1:0] ifft_real_in_flat;
    wire [11*16-1:0] ifft_imag_in_flat;
    wire [11*16-1:0] ifft_real_out_flat;
    wire [11*16-1:0] ifft_imag_out_flat;
    wire [11*16-1:0] output_real_in_flat;
    wire [11*16-1:0] output_imag_in_flat;

    // Twiddle ROM signals
    wire [$clog2(16)-1:0] twiddle_addr;
    wire signed [11:0] twiddle_real;
    wire signed [11:0] twiddle_imag;

    // DMA output mux selection (changed to reg for procedural assignment)
    wire [1:0] dma_select = 2'b00;  // Select FIR or FFT output (configurable)
    reg [11*256-1:0] dma_output_flat;  // Changed from wire to reg
    wire [11*256-1:0] dma_output_flat_wire;  // Wire for module connection

    // Interface signals
    wire signed [11:0] dma_real;
    wire signed [11:0] dma_imag;
    wire done;

    // Instantiate input_buffer1
    input_buffer1 #(.DATA_WIDTH(12), .BUFFER_SIZE(256)) u_input_buffer (
        .clk(clk), .reset(reset), .valid_in(valid_in),
        .sample_in(sample_in), .ready_for_processing(ready_for_processing)
    );

    // Instantiate controller
    controller #(.BLOCK_SIZE(256)) u_controller (
        .clk(clk), .reset(reset),
        .ready_for_processing(ready_for_processing),
        .fir_done(fir_done), .fft_done(fft_done),
        .config_mode(config_mode[0]),  // Use bit 0 for FIR/FFT select
        .start_fir(start_fir), .start_fft(start_fft),
        .start_dma_out(start_dma_out), .processing_active(processing_active)
    );

    // Instantiate config_register
    config_register u_config (
        .clk(clk), .reset(reset), .write_enable(write_enable),
        .config_in(config_in), .config_mode(config_mode)
    );

    // Instantiate clock_manager
    clock_manager u_clock_manager (
        .clk_in(clk), .reset(reset),
        .enable_fir(start_fir), .enable_fft(start_fft), .enable_dma(start_dma_out),
        .clk_fir(clk_fir), .clk_fft(clk_fft), .clk_dma(clk_dma)
    );

    // Instantiate fir_filter
    fir_filter #(.DATA_WIDTH(12), .TAPS(16)) u_fir (
        .clk(clk_fir), .reset(reset), .start_fir(start_fir),
        .filter_mode(2'b00),  // LPF
        .input_buffer(u_input_buffer.buffer),
        .fir_output(fir_output), .fir_done(fir_done)
    );

    // Instantiate fft_core with flattened ports
    fft_core #(.DATA_WIDTH(12), .N(16)) u_fft (
        .clk(clk_fft), .reset(reset), .start_fft(start_fft),
        .real_in(fft_real_in_flat[11*16-1:0]),
        .imag_in(fft_imag_in_flat[11*16-1:0]),
        .twiddle_addr(twiddle_addr), .twiddle_real(twiddle_real),
        .twiddle_imag(twiddle_imag),
        .real_out(fft_real_out_flat[11*16-1:0]),
        .imag_out(fft_imag_out_flat[11*16-1:0]),
        .fft_done(fft_done)
    );

    // Instantiate twiddle_rom (explicitly connected)
    twiddle_rom #(.DATA_WIDTH(12), .N(16)) u_twiddle (
        .addr(twiddle_addr),
        .twiddle_real(twiddle_real),
        .twiddle_imag(twiddle_imag)
    );

    // Instantiate ifft_core with flattened ports
    ifft_core #(.DATA_WIDTH(12), .N(16)) u_ifft (
        .clk(clk_fft), .reset(reset), .start_ifft(start_fft),
        .real_in(ifft_real_in_flat[11*16-1:0]),
        .imag_in(ifft_imag_in_flat[11*16-1:0]),
        .twiddle_addr(twiddle_addr), .twiddle_real(twiddle_real),
        .twiddle_imag(twiddle_imag),
        .real_out(ifft_real_out_flat[11*16-1:0]),
        .imag_out(ifft_imag_out_flat[11*16-1:0]),
        .ifft_done(fft_done)  // Reuse fft_done for simplicity
    );

    // Instantiate output_buffer
    output_buffer #(.DATA_WIDTH(12), .N(16)) u_output (
        .clk(clk), .reset(reset), .store(fft_done), .read_en(dma_valid),
        .read_addr(dma_done ? 0 : 4'hF), .read_done(dma_done),
        .real_in(ifft_real_out_flat[11*16-1:0]),
        .imag_in(ifft_imag_out_flat[11*16-1:0]),
        .real_out(output_real_in_flat[11*16-1:0]),
        .imag_out(output_imag_in_flat[11*16-1:0]),
        .buffer_ready(V)  // Assign V as buffer_ready
    );

    // Instantiate dma_controller with muxed output
    dma_controller #(.DATA_WIDTH(12), .BLOCK_SIZE(256)) u_dma (
        .clk(clk_dma), .reset(reset), .start_dma_out(start_dma_out),
        .output_buffer_flat(dma_output_flat_wire[11*256-1:0]),
        .dma_data_out(dma_data_out), .dma_valid(dma_valid), .dma_done(dma_done)
    );

    // Instantiate interface1 (drives config_write and DMA)
    interface1 #(.DATA_WIDTH(12), .N(16)) u_interface (
        .clk(clk), .reset(reset), .buffer_ready(V),
        .real_in(output_real_in_flat[11*16-1:0]),
        .imag_in(output_imag_in_flat[11*16-1:0]),
        .dma_ack(1'b1), .dma_real(dma_real), .dma_imag(dma_imag),
        .dma_valid(dma_valid), .done(done),
        .write_enable(write_enable), .config_in(config_in)
    );

    // DMA output mux logic (procedural assignment with reg)
    always @(*) begin
        case (dma_select)
            2'b00: dma_output_flat = {{(256-16){12'b0}}, fir_output, {(256-1)*12{12'b0}}};  // Repeat FIR
            2'b01: dma_output_flat = {{(256-16){12'b0}}, fft_real_out_flat[11*16-1:0], {(256-16)*12{12'b0}}};  // Use FFT real output
            default: dma_output_flat = {256*12{12'b0}};  // Default to zero
        endcase
    end

    // Assign reg to wire for module connection
    assign dma_output_flat_wire = dma_output_flat;

    // Unpack flattened arrays (simplified)
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : unpack_arrays
            assign fft_real_in_flat[(i+1)*12-1 -: 12] = u_input_buffer.buffer[i];
            assign fft_imag_in_flat[(i+1)*12-1 -: 12] = 12'b0;
            assign ifft_real_in_flat[(i+1)*12-1 -: 12] = fft_real_out_flat[(i+1)*12-1 -: 12];
            assign ifft_imag_in_flat[(i+1)*12-1 -: 12] = fft_imag_out_flat[(i+1)*12-1 -: 12];
        end
    endgenerate

endmodule
