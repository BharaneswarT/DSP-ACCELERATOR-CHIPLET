`timescale 1ns/1ps

module top #(
    parameter DATA_WIDTH = 16,
    parameter BUFFER_SIZE = 256
)(
    input clk,
    input reset,
    input valid_in,
    input [DATA_WIDTH-1:0] sample_in,  // Now 16 bits
    output [4:0] config_mode,
    output fir_done,
    output fft_done,
    output dma_done,
    output processing_active,
    output V,  // Added output port V
    output done  // Added for completion signal
);

    wire ready_for_processing;
    wire start_fir, start_fft, start_dma_out;
    wire write_enable;  // Driven from interface
    wire [4:0] config_in;
    wire clk_fir, clk_fft, clk_dma;
    wire [DATA_WIDTH-1:0] fir_output;  // Now 16 bits
    wire [DATA_WIDTH-1:0] dma_data_out;  // Now 16 bits
    wire dma_valid;
    wire [DATA_WIDTH*BUFFER_SIZE-1:0] input_buffer_flat_a;
    wire [DATA_WIDTH*BUFFER_SIZE-1:0] input_buffer_flat_b;
    wire buffer_select;
    wire [DATA_WIDTH*BUFFER_SIZE-1:0] selected_buffer_flat = (buffer_select == 0) ? input_buffer_flat_a : input_buffer_flat_b;

    // Flattened arrays for compatibility
    wire [DATA_WIDTH*16-1:0] fft_real_in_flat;
    wire [DATA_WIDTH*16-1:0] fft_imag_in_flat;
    wire [DATA_WIDTH*16-1:0] fft_real_out_flat;
    wire [DATA_WIDTH*16-1:0] fft_imag_out_flat;
    wire [DATA_WIDTH*16-1:0] ifft_real_in_flat;
    wire [DATA_WIDTH*16-1:0] ifft_imag_in_flat;
    wire [DATA_WIDTH*16-1:0] ifft_real_out_flat;
    wire [DATA_WIDTH*16-1:0] ifft_imag_out_flat;
    wire [DATA_WIDTH*16-1:0] output_real_in_flat;
    wire [DATA_WIDTH*16-1:0] output_imag_in_flat;

    // Twiddle ROM signals
    wire [$clog2(16)-1:0] twiddle_addr;
    wire signed [DATA_WIDTH-1:0] twiddle_real;
    wire signed [DATA_WIDTH-1:0] twiddle_imag;

    // DMA output mux selection
    wire [1:0] dma_select = 2'b00;  // Select FIR or FFT output (configurable)
    reg [DATA_WIDTH*BUFFER_SIZE-1:0] dma_output_flat;  // Now 16*256 bits
    wire [DATA_WIDTH*BUFFER_SIZE-1:0] dma_output_flat_wire;  // Wire for module connection

    // Interface signals (removed redundant wire done)
    wire signed [DATA_WIDTH-1:0] dma_real;
    wire signed [DATA_WIDTH-1:0] dma_imag;

    // Instantiate input_buffer1
    input_buffer1 #(.DATA_WIDTH(DATA_WIDTH), .BUFFER_SIZE(BUFFER_SIZE)) u_input_buffer (
        .clk(clk),
        .reset(reset),
        .valid_in(valid_in),
        .sample_in(sample_in),
        .ready_for_processing(ready_for_processing),
        .buffer_flat_a(input_buffer_flat_a),
        .buffer_flat_b(input_buffer_flat_b),
        .buffer_select(buffer_select)
    );

    // Instantiate controller
    controller #(.BLOCK_SIZE(BUFFER_SIZE)) u_controller (
        .clk(clk),
        .reset(reset),
        .ready_for_processing(ready_for_processing),
        .fir_done(fir_done),
        .fft_done(fft_done),
        .config_mode(config_mode[0]),  // Use bit 0 for FIR/FFT select
        .buffer_select(buffer_select),
        .start_fir(start_fir),
        .start_fft(start_fft),
        .start_dma_out(start_dma_out),
        .processing_active(processing_active)
        // ready_ack not connected yet—add if needed
    );

    // Instantiate config_register
    config_register u_config (
        .clk(clk),
        .reset(reset),
        .write_enable(write_enable),
        .config_in(config_in),
        .config_mode(config_mode)
    );

    // Instantiate clock_manager
    clock_manager u_clock_manager (
        .clk_in(clk),
        .reset(reset),
        .enable_fir(start_fir),
        .enable_fft(start_fft),
        .enable_dma(start_dma_out),
        .clk_fir(clk_fir),
        .clk_fft(clk_fft),
        .clk_dma(clk_dma)
    );

    // Instantiate fir_filter
    fir_filter #(.DATA_WIDTH(DATA_WIDTH), .TAPS(16)) u_fir (
        .clk(clk_fir),
        .reset(reset),
        .start_fir(start_fir),
        .filter_mode(2'b00),  // LPF
        .input_buffer(selected_buffer_flat[DATA_WIDTH*16-1:0]),  // Use selected buffer
        .fir_output(fir_output),
        .fir_done(fir_done)
    );

    // Instantiate fft_core with flattened ports
    fft_core #(.DATA_WIDTH(DATA_WIDTH), .N(16)) u_fft (
        .clk(clk_fft),
        .reset(reset),
        .start_fft(start_fft),
        .real_in(fft_real_in_flat[DATA_WIDTH*16-1:0]),
        .imag_in(fft_imag_in_flat[DATA_WIDTH*16-1:0]),
        .twiddle_addr(twiddle_addr),
        .twiddle_real(twiddle_real),
        .twiddle_imag(twiddle_imag),
        .real_out(fft_real_out_flat[DATA_WIDTH*16-1:0]),
        .imag_out(fft_imag_out_flat[DATA_WIDTH*16-1:0]),
        .fft_done(fft_done)
    );

    // Instantiate twiddle_rom
    twiddle_rom #(.DATA_WIDTH(DATA_WIDTH), .N(16)) u_twiddle (
        .addr(twiddle_addr),
        .twiddle_real(twiddle_real),
        .twiddle_imag(twiddle_imag)
    );

    // Instantiate ifft_core with flattened ports
    ifft_core #(.DATA_WIDTH(DATA_WIDTH), .N(16)) u_ifft (
        .clk(clk_fft),
        .reset(reset),
        .start_ifft(start_fft),
        .real_in(ifft_real_in_flat[DATA_WIDTH*16-1:0]),
        .imag_in(ifft_imag_in_flat[DATA_WIDTH*16-1:0]),
        .twiddle_addr(twiddle_addr),
        .twiddle_real(twiddle_real),
        .twiddle_imag(twiddle_imag),
        .real_out(ifft_real_out_flat[DATA_WIDTH*16-1:0]),
        .imag_out(ifft_imag_out_flat[DATA_WIDTH*16-1:0]),
        .ifft_done(fft_done)
    );

    // Instantiate output_buffer
    output_buffer #(.DATA_WIDTH(DATA_WIDTH), .N(16)) u_output (
        .clk(clk),
        .reset(reset),
        .store(fft_done),
        .read_en(dma_valid),
        .read_addr(dma_done ? 0 : 4'hF),
        .read_done(dma_done),
        .real_in(ifft_real_out_flat[DATA_WIDTH*16-1:0]),
        .imag_in(ifft_imag_out_flat[DATA_WIDTH*16-1:0]),
        .real_out(output_real_in_flat[DATA_WIDTH*16-1:0]),
        .imag_out(output_imag_in_flat[DATA_WIDTH*16-1:0]),
        .buffer_ready(V)
    );

    // Instantiate dma_controller with muxed output
    dma_controller #(.DATA_WIDTH(DATA_WIDTH), .BLOCK_SIZE(BUFFER_SIZE)) u_dma (
        .clk(clk_dma),
        .reset(reset),
        .start_dma_out(start_dma_out),
        .output_buffer_flat(dma_output_flat_wire[DATA_WIDTH*BUFFER_SIZE-1:0]),
        .dma_data_out(dma_data_out),
        .dma_valid(dma_valid),
        .dma_done(dma_done)
    );

    // Instantiate interface1
    interface1 #(.DATA_WIDTH(DATA_WIDTH), .N(16)) u_interface (
        .clk(clk),
        .reset(reset),
        .buffer_ready(V),
        .real_in(output_real_in_flat[DATA_WIDTH*16-1:0]),
        .imag_in(output_imag_in_flat[DATA_WIDTH*16-1:0]),
        .dma_ack(1'b1),
        .dma_real(dma_real),
        .dma_imag(dma_imag),
        .dma_valid(dma_valid),
        .done(done),
        .write_enable(write_enable),
        .config_in(config_in)
    );

    // DMA output mux logic
    always @(*) begin
    case (dma_select)
        2'b00: dma_output_flat = {
            {(BUFFER_SIZE-16){ {DATA_WIDTH{1'b0}} }},
            fir_output,
            {(BUFFER_SIZE-1){ {DATA_WIDTH{1'b0}} }}
        };
        2'b01: dma_output_flat = {
            {(BUFFER_SIZE-16){ {DATA_WIDTH{1'b0}} }},
            fft_real_out_flat[DATA_WIDTH*16-1:0],
            {(BUFFER_SIZE-16){ {DATA_WIDTH{1'b0}} }}
        };
        default: dma_output_flat = {BUFFER_SIZE{ {DATA_WIDTH{1'b0}} }};
    endcase
end
    // Assign reg to wire for module connection
    assign dma_output_flat_wire = dma_output_flat;

    // Unpack flattened arrays
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : unpack_arrays
            assign fft_real_in_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] = selected_buffer_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH];  // Use selected buffer
            assign fft_imag_in_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] = {DATA_WIDTH{1'b0}};
            assign ifft_real_in_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] = fft_real_out_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH];
            assign ifft_imag_in_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] = fft_imag_out_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH];
        end
    endgenerate

endmodule
