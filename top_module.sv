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
    localparam TAPS = 16;
    wire signed [DATA_WIDTH-1:0] fft_real_in     [0:15];
    wire signed [DATA_WIDTH-1:0] fft_imag_in     [0:15];
    wire signed [DATA_WIDTH-1:0] fft_real_out    [0:15];
    wire signed [DATA_WIDTH-1:0] fft_imag_out    [0:15];
    wire signed [DATA_WIDTH-1:0] ifft_real_in    [0:15];
    wire signed [DATA_WIDTH-1:0] ifft_imag_in    [0:15];
    wire signed [DATA_WIDTH-1:0] ifft_real_out   [0:15];
    wire signed [DATA_WIDTH-1:0] ifft_imag_out   [0:15];
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
    wire signed [DATA_WIDTH-1:0] output_real_in [0:15];
    wire signed [DATA_WIDTH-1:0] output_imag_in [0:15];
    wire signed [DATA_WIDTH-1:0] output_real_out [0:15];
    wire signed [DATA_WIDTH-1:0] output_imag_out [0:15];

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
  	.ready_ack(ready_ack),
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
        .processing_active(processing_active),
  	.ready_ack(ready_ack)
        
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
wire signed [DATA_WIDTH-1:0] fir_input_buffer [0:TAPS-1];
genvar i_fir;
generate
  for (i_fir = 0; i_fir < 16; i_fir++) begin : unpack_fir_input
    assign fir_input_buffer[i_fir] = selected_buffer_flat[(i_fir+1)*DATA_WIDTH-1 -: DATA_WIDTH];
  end
endgenerate

   fir_filter #(.DATA_WIDTH(DATA_WIDTH), .TAPS(16)) u_fir (
    .clk(clk_fir),
    .reset(reset),
    .start_fir(start_fir),
    .filter_mode(2'b00),
    .input_buffer(fir_input_buffer),
    .fir_output(fir_output),
    .fir_done(fir_done)
);
 
    // Instantiate fft_core with flattened ports
genvar i_fft_pack;
generate
  for (i_fft_pack = 0; i_fft_pack < 16; i_fft_pack++) begin : pack_fft_output
    assign fft_real_out_flat[(i_fft_pack+1)*DATA_WIDTH-1 -: DATA_WIDTH] = fft_real_out[i_fft_pack];
    assign fft_imag_out_flat[(i_fft_pack+1)*DATA_WIDTH-1 -: DATA_WIDTH] = fft_imag_out[i_fft_pack];
  end
endgenerate
    fft_core u_fft (
  .clk(clk_fft),
  .reset(reset),
  .start_fft(start_fft),
  .real_in(fft_real_in),
  .imag_in(fft_imag_in),
  .twiddle_addr(twiddle_addr),
  .twiddle_real(twiddle_real),
  .twiddle_imag(twiddle_imag),
  .real_out(fft_real_out),
  .imag_out(fft_imag_out),
  .fft_done(fft_done)
);
    
    // Instantiate twiddle_rom
    twiddle_rom #(.DATA_WIDTH(DATA_WIDTH), .N(16)) u_twiddle (
        .addr(twiddle_addr),
        .twiddle_real(twiddle_real),
        .twiddle_imag(twiddle_imag)
    );

    // Instantiate ifft_core with flattened ports

genvar i_ifft_pack;
generate
  for (i_ifft_pack = 0; i_ifft_pack < 16; i_ifft_pack++) begin : pack_ifft_output
    assign ifft_real_out_flat[(i_ifft_pack+1)*DATA_WIDTH-1 -: DATA_WIDTH] = ifft_real_out[i_ifft_pack];
    assign ifft_imag_out_flat[(i_ifft_pack+1)*DATA_WIDTH-1 -: DATA_WIDTH] = ifft_imag_out[i_ifft_pack];
  end
endgenerate
    ifft_core #(.DATA_WIDTH(DATA_WIDTH), .N(16)) u_ifft (
  .clk(clk_fft),
  .reset(reset),
  .start_ifft(start_fft),
  .real_in(ifft_real_in),
  .imag_in(ifft_imag_in),
  .twiddle_addr(twiddle_addr),
  .twiddle_real(twiddle_real),
  .twiddle_imag(twiddle_imag),
  .real_out(ifft_real_out),
  .imag_out(ifft_imag_out),
  .ifft_done(fft_done)
);

    // Instantiate output_buffer
genvar i_out;
generate
  for (i_out = 0; i_out < 16; i_out++) begin : unpack_output
    assign output_real_in[i_out] = fft_real_out_flat[(i_out+1)*DATA_WIDTH-1 -: DATA_WIDTH];
    assign output_imag_in[i_out] = fft_imag_out_flat[(i_out+1)*DATA_WIDTH-1 -: DATA_WIDTH];
  end
endgenerate
    output_buffer #(.DATA_WIDTH(DATA_WIDTH), .N(16)) u_output (
        .clk(clk),
        .reset(reset),
        .store(fft_done),
        .read_en(dma_valid),
        .read_addr(dma_done ? 0 : 4'hF),
        .read_done(dma_done),
        .real_in(output_real_in),
	.imag_in(output_imag_in),
	
	
        
       .real_out(output_real_out),
	.imag_out(output_imag_out),
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
genvar i_pack_out;
generate
  for (i_pack_out = 0; i_pack_out < 16; i_pack_out++) begin : pack_output_to_flat
    assign output_real_in_flat[(i_pack_out+1)*DATA_WIDTH-1 -: DATA_WIDTH] = output_real_out[i_pack_out];
    assign output_imag_in_flat[(i_pack_out+1)*DATA_WIDTH-1 -: DATA_WIDTH] = output_imag_out[i_pack_out];
  end
endgenerate
    interface1 #(.DATA_WIDTH(DATA_WIDTH), .N(16)) u_interface (
        .clk(clk),
        .reset(reset),
        .buffer_ready(V),
        .real_in(output_real_out),
	.imag_in(output_imag_out),
        .dma_ack(1'b1),
        .dma_real(dma_real),
        .dma_imag(dma_imag),
        .dma_valid(dma_valid),
        .done(done)
    );

    // DMA output mux logic
    always @(*) begin
    case (dma_select)
        2'b00: dma_output_flat = {
    		{(BUFFER_SIZE-TAPS){ {DATA_WIDTH{1'b0}} }},
    		fir_input_buffer[0],
    		fir_input_buffer[1],
    		fir_input_buffer[2],
		fir_input_buffer[3],
		fir_input_buffer[4],
		fir_input_buffer[5],
		fir_input_buffer[6],
		fir_input_buffer[7],
		fir_input_buffer[8],
		fir_input_buffer[9],
		fir_input_buffer[10],
		fir_input_buffer[11],
		fir_input_buffer[12],
		fir_input_buffer[13],
		fir_input_buffer[14],
    		fir_input_buffer[15]
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
    genvar i_unpack;
generate
  for (i_unpack = 0; i_unpack < 16; i_unpack++) begin : unpack_arrays
    assign fft_real_in_flat[(i_unpack+1)*DATA_WIDTH-1 -: DATA_WIDTH] = selected_buffer_flat[(i_unpack+1)*DATA_WIDTH-1 -: DATA_WIDTH];
    assign fft_imag_in_flat[(i_unpack+1)*DATA_WIDTH-1 -: DATA_WIDTH] = {DATA_WIDTH{1'b0}};
    assign ifft_real_in_flat[(i_unpack+1)*DATA_WIDTH-1 -: DATA_WIDTH] = fft_real_out_flat[(i_unpack+1)*DATA_WIDTH-1 -: DATA_WIDTH];
    assign ifft_imag_in_flat[(i_unpack+1)*DATA_WIDTH-1 -: DATA_WIDTH] = fft_imag_out_flat[(i_unpack+1)*DATA_WIDTH-1 -: DATA_WIDTH];
  end
endgenerate


endmodule
