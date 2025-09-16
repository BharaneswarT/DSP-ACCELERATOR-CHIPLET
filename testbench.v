`timescale 1ns/1ps

module dsp_chiplet_tb;

  parameter DATA_WIDTH = 16;
  parameter BUFFER_SIZE = 256;  // Match input_buffer1
  parameter FFT_N = 16;
  parameter TAPS = 16;

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
  wire ready_ack;
  wire done;

  wire [DATA_WIDTH*BUFFER_SIZE-1:0] input_buffer_flat_a;
  wire [DATA_WIDTH*BUFFER_SIZE-1:0] input_buffer_flat_b;
  wire buffer_select;  // Moved to wire to match input_buffer1 output
  wire [DATA_WIDTH*BUFFER_SIZE-1:0] selected_buffer_flat;

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
  wire [DATA_WIDTH*FFT_N-1:0] output_real_out_flat;
  wire [DATA_WIDTH*FFT_N-1:0] output_imag_out_flat;
  reg [DATA_WIDTH*BUFFER_SIZE-1:0] dma_output_flat;  // [4095:0]

  wire [$clog2(FFT_N)-1:0] twiddle_addr;
  wire signed [DATA_WIDTH-1:0] twiddle_real, twiddle_imag;

  // Input Buffer
  input_buffer1 #(.DATA_WIDTH(DATA_WIDTH), .BUFFER_SIZE(BUFFER_SIZE)) u_input_buffer (
      .clk(clk),
      .reset(reset),
      .valid_in(valid_in),
      .sample_in(sample_in),
      .ready_for_processing(ready_for_processing),
      .ready_ack(ready_ack), // your buffer uses it

      .buffer_flat_a(input_buffer_flat_a),
      .buffer_flat_b(input_buffer_flat_b),
      .buffer_select(buffer_select)
  );

  // Select active buffer
  assign selected_buffer_flat = (buffer_select == 0) ? input_buffer_flat_a : input_buffer_flat_b;

  // FIR Input Unpacking
  wire signed [DATA_WIDTH-1:0] fir_input_array [0:TAPS-1];
  genvar g_fir;
  generate
    for (g_fir = 0; g_fir < TAPS; g_fir = g_fir + 1) begin : unpack_fir_input
      assign fir_input_array[g_fir] = selected_buffer_flat[(g_fir+1)*DATA_WIDTH-1 -: DATA_WIDTH];
    end
  endgenerate

  // Controller
  controller #(.BLOCK_SIZE(BUFFER_SIZE)) u_controller (
      .clk(clk), .reset(reset),
      .ready_for_processing(ready_for_processing),
      .buffer_select(buffer_select),
      .fir_done(fir_done), .fft_done(fft_done),
      .config_mode(config_mode[0]),
      .start_fir(start_fir), .start_fft(start_fft),
      .start_dma_out(start_dma_out), .processing_active(processing_active),
      .ready_ack(ready_ack) // Add ready_ack later if needed
  );

  // Config Register
  config_register u_config (
      .clk(clk), .reset(reset), .write_enable(write_enable),
      .config_in(config_in), .config_mode(config_mode)
  );

  // Clock Manager
  clock_manager u_clock_manager (
      .clk_in(clk), .reset(reset),
      .enable_fir(start_fir), .enable_fft(start_fft), .enable_dma(start_dma_out),
      .clk_fir(clk_fir), .clk_fft(clk_fft), .clk_dma(clk_dma)
  );

  // FIR Filter
  fir_filter #(.DATA_WIDTH(DATA_WIDTH), .TAPS(TAPS)) u_fir (
      .clk(clk_fir),
      .reset(reset),
      .start_fir(start_fir),
      .filter_mode(2'b00),
      .input_buffer(fir_input_array),  // Unpacked array
      .fir_output(fir_output),
      .fir_done(fir_done)
  );

  // FFT Input Unpacking
  wire signed [DATA_WIDTH-1:0] fft_real_array [0:FFT_N-1];
  wire signed [DATA_WIDTH-1:0] fft_imag_array [0:FFT_N-1];
  assign fft_real_in_flat = selected_buffer_flat[DATA_WIDTH*FFT_N-1:0];  // First 16 samples
  assign fft_imag_in_flat = {FFT_N{16'b0}};
  genvar g_fft;
  generate
    for (g_fft = 0; g_fft < FFT_N; g_fft = g_fft + 1) begin : unpack_fft_input
      assign fft_real_array[g_fft] = fft_real_in_flat[(g_fft+1)*DATA_WIDTH-1 -: DATA_WIDTH];
      assign fft_imag_array[g_fft] = fft_imag_in_flat[(g_fft+1)*DATA_WIDTH-1 -: DATA_WIDTH];
    end
  endgenerate
  wire signed [DATA_WIDTH-1:0] fft_real_out_array [0:FFT_N-1];
  wire signed [DATA_WIDTH-1:0] fft_imag_out_array [0:FFT_N-1];

  // FFT Core
  fft_core #(.DATA_WIDTH(DATA_WIDTH), .N(FFT_N)) u_fft (
      .clk(clk_fft),
      .reset(reset),
      .start_fft(start_fft),
      .real_in(fft_real_array),  // Unpacked array
      .imag_in(fft_imag_array),  // Unpacked array
      .twiddle_addr(twiddle_addr),
      .twiddle_real(twiddle_real),
      .twiddle_imag(twiddle_imag),
      .real_out(fft_real_out_array),  // Unpacked array
      .imag_out(fft_imag_out_array),  // Unpacked array
      .fft_done(fft_done)
  );

  // Twiddle ROM
  twiddle_rom #(.DATA_WIDTH(DATA_WIDTH), .N(FFT_N)) u_twiddle (
      .addr(twiddle_addr),
      .twiddle_real(twiddle_real),
      .twiddle_imag(twiddle_imag)
  );

  // IFFT Input Unpacking
  wire signed [DATA_WIDTH-1:0] ifft_real_array [0:FFT_N-1];
  wire signed [DATA_WIDTH-1:0] ifft_imag_array [0:FFT_N-1];
  assign ifft_real_in_flat = fft_real_out_flat;
  assign ifft_imag_in_flat = fft_imag_out_flat;
  genvar g_ifft;
  generate
    for (g_ifft = 0; g_ifft < FFT_N; g_ifft = g_ifft + 1) begin : unpack_ifft_input
      assign ifft_real_array[g_ifft] = ifft_real_in_flat[(g_ifft+1)*DATA_WIDTH-1 -: DATA_WIDTH];
      assign ifft_imag_array[g_ifft] = ifft_imag_in_flat[(g_ifft+1)*DATA_WIDTH-1 -: DATA_WIDTH];
    end
  endgenerate
  wire signed [DATA_WIDTH-1:0] ifft_real_out_array [0:FFT_N-1];
  wire signed [DATA_WIDTH-1:0] ifft_imag_out_array [0:FFT_N-1];

  // IFFT Core
  ifft_core #(.DATA_WIDTH(DATA_WIDTH), .N(FFT_N)) u_ifft (
      .clk(clk_fft),
      .reset(reset),
      .start_ifft(start_fft),
      .real_in(ifft_real_array),  // Unpacked array
      .imag_in(ifft_imag_array),  // Unpacked array
      .twiddle_addr(twiddle_addr),
      .twiddle_real(twiddle_real),
      .twiddle_imag(twiddle_imag),
      .real_out(ifft_real_out_array),  // Unpacked array
      .imag_out(ifft_imag_out_array),  // Unpacked array
      .ifft_done(fft_done)
  );

  // Output Buffer Input Unpacking
  wire signed [DATA_WIDTH-1:0] output_real_array [0:FFT_N-1];
  wire signed [DATA_WIDTH-1:0] output_imag_array [0:FFT_N-1];
  assign output_real_in_flat = ifft_real_out_flat;
  assign output_imag_in_flat = ifft_imag_out_flat;
  genvar g_out;
  generate
    for (g_out = 0; g_out < FFT_N; g_out = g_out + 1) begin : unpack_output_buffer_input
      assign output_real_array[g_out] = output_real_in_flat[(g_out+1)*DATA_WIDTH-1 -: DATA_WIDTH];
      assign output_imag_array[g_out] = output_imag_in_flat[(g_out+1)*DATA_WIDTH-1 -: DATA_WIDTH];
    end
  endgenerate
  wire signed [DATA_WIDTH-1:0] output_real_out_array [0:FFT_N-1];
  wire signed [DATA_WIDTH-1:0] output_imag_out_array [0:FFT_N-1];

  // Output Buffer
  output_buffer #(.DATA_WIDTH(DATA_WIDTH), .N(FFT_N)) u_output (
      .clk(clk),
      .reset(reset),
      .store(fft_done),
      .read_en(dma_valid),
      .read_addr(dma_done ? 4'h0 : 4'hF),
      .read_done(dma_done),
      .real_in(output_real_array),  // Unpacked array
      .imag_in(output_imag_array),  // Unpacked array
      .real_out(output_real_out_array),
      .imag_out(output_imag_out_array),
      .buffer_ready(buffer_ready)
  );

  // DMA Controller
  dma_controller #(.DATA_WIDTH(DATA_WIDTH), .BLOCK_SIZE(BUFFER_SIZE)) u_dma (
      .clk(clk_dma), .reset(reset), .start_dma_out(start_dma_out),
      .output_buffer_flat(dma_output_flat),
      .dma_data_out(dma_data_out), .dma_valid(dma_valid), .dma_done(dma_done)
  );

  // Interface Input Unpacking
  genvar g_intf;
  generate
    for (g_intf = 0; g_intf < FFT_N; g_intf = g_intf + 1) begin : unpack_interface_input
      assign output_real_out_array[g_intf] = output_real_out_flat[(g_intf+1)*DATA_WIDTH-1 -: DATA_WIDTH];
      assign output_imag_out_array[g_intf] = output_imag_out_flat[(g_intf+1)*DATA_WIDTH-1 -: DATA_WIDTH];
    end
  endgenerate

  // Interface
  interface1 #(.DATA_WIDTH(DATA_WIDTH), .N(FFT_N)) u_interface (
      .clk(clk),
      .reset(reset),
      .buffer_ready(buffer_ready),
      .real_in(output_real_out_array),  // Unpacked array
      .imag_in(output_imag_out_array),  // Unpacked array
      .dma_ack(dma_ack),
      .dma_real(dma_real),
      .dma_imag(dma_imag),
      .dma_valid(dma_valid),
      .done(done)
  );

  integer i;
  always @(*) begin
    if (config_mode[0]) begin
      for (i = 0; i < BUFFER_SIZE; i = i + 1) begin
        dma_output_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] =
          (i < FFT_N) ? ifft_real_out_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] : 0;
      end
    end else begin
      dma_output_flat[DATA_WIDTH-1:0] = fir_output;
      for (i = 1; i < BUFFER_SIZE; i = i + 1) begin
        dma_output_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] = 0;
      end
    end
  end

  initial clk = 0;
  always #5 clk = ~clk;

initial begin
  $dumpfile("dsp_chiplet_tb.vcd");
  $dumpvars(0, dsp_chiplet_tb);

  // Initialize
  clk = 0;
  reset = 1;
  valid_in = 0;
  sample_in = 0;
  write_enable = 0;
  config_in = 5'b00000;

  // Reset pulse
  #20 reset = 0;

  // Write FFT mode
  #10 write_enable = 1;
  config_in = 5'b00001;
  #10 write_enable = 0;

  // Let config settle
  #20;

  // Feed 1024 samples with clean spacing
  repeat (8 * BUFFER_SIZE) begin  // 2048 samples
  valid_in = 1;
  sample_in = $random % (1 << DATA_WIDTH);
  #10;
  valid_in = 0;
  #10;
end

  // Wait for DMA to complete
  wait (dma_done);
  $display("DMA completed at time %0t", $time);
  #100;
  $finish;
end

  initial $monitor("Time=%0t | FIR=%b FFT=%b DMA=%b Active=%b BufferReady=%b | buffer_select=%b",
                   $time, fir_done, fft_done, dma_done, processing_active, buffer_ready, buffer_select);

endmodule
