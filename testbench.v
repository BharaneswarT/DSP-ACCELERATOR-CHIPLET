`timescale 1ns/1ps

module dsp_chiplet_tb;

  parameter DATA_WIDTH = 16;
  parameter BUFFER_SIZE = 256;  // Match input_buffer1
  parameter FFT_N = 16;
  parameter TAPS = 16;

  reg clk, reset;
  reg valid_in;
  reg [DATA_WIDTH-1:0] sample_in;
  wire write_enable = 1'b0;
  wire [4:0] config_in = 5'b00000;
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

  wire [DATA_WIDTH*BUFFER_SIZE-1:0] input_buffer_flat;  // Now [4095:0]
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
  reg [DATA_WIDTH*BUFFER_SIZE-1:0] dma_output_flat;  // Now [4095:0]

  wire [$clog2(FFT_N)-1:0] twiddle_addr;
  wire signed [DATA_WIDTH-1:0] twiddle_real, twiddle_imag;
  
 

  input_buffer1 #(.DATA_WIDTH(DATA_WIDTH), .BUFFER_SIZE(BUFFER_SIZE)) u_input_buffer (
    .clk(clk),
    .reset(reset),
    .valid_in(valid_in),
    .sample_in(sample_in),
    .ready_for_processing(ready_for_processing),
    .buffer_flat(input_buffer_flat)  // ✅ Connect packed output
  );
   
  wire signed [DATA_WIDTH-1:0] fir_input_array [0:TAPS-1];   //code from copilot for correction
  genvar g_fir;
generate
  for (g_fir = 0; g_fir < TAPS; g_fir = g_fir + 1) begin : unpack_fir_input
    assign fir_input_array[g_fir] = input_buffer_flat[(g_fir+1)*DATA_WIDTH-1 -: DATA_WIDTH];
  end
endgenerate

  controller #(.BLOCK_SIZE(BUFFER_SIZE)) u_controller (
    .clk(clk), .reset(reset),
    .ready_for_processing(ready_for_processing),
    .fir_done(fir_done), .fft_done(fft_done),
    .config_mode(config_mode[0]),
    .start_fir(start_fir), .start_fft(start_fft),
    .start_dma_out(start_dma_out), .processing_active(processing_active)
  );

  config_register u_config (
    .clk(clk), .reset(reset), .write_enable(write_enable),
    .config_in(config_in), .config_mode(config_mode)
  );

  clock_manager u_clock_manager (
    .clk_in(clk), .reset(reset),
    .enable_fir(start_fir), .enable_fft(start_fft), .enable_dma(start_dma_out),
    .clk_fir(clk_fir), .clk_fft(clk_fft), .clk_dma(clk_dma)
  );

   
  fir_filter #(.DATA_WIDTH(DATA_WIDTH), .TAPS(TAPS)) u_fir (
    .clk(clk_fir),
    .reset(reset),
    .start_fir(start_fir),
    .filter_mode(2'b00),
    .input_buffer(fir_input_array),  // ✅ Unpacked array passed
    .fir_output(fir_output),
    .fir_done(fir_done)
);

  // Declare unpacked arrays
wire signed [DATA_WIDTH-1:0] fft_real_array [0:FFT_N-1];
wire signed [DATA_WIDTH-1:0] fft_imag_array [0:FFT_N-1];

assign fft_real_in_flat = input_buffer_flat[DATA_WIDTH*FFT_N-1:0];  // First 16 samples 
  assign fft_imag_in_flat = {FFT_N{16'b0}}; 

// Unpack from flat vectors
genvar g_fft;
generate
  for (g_fft = 0; g_fft < FFT_N; g_fft = g_fft + 1) begin : unpack_fft_input
    assign fft_real_array[g_fft] = fft_real_in_flat[(g_fft+1)*DATA_WIDTH-1 -: DATA_WIDTH];
    assign fft_imag_array[g_fft] = fft_imag_in_flat[(g_fft+1)*DATA_WIDTH-1 -: DATA_WIDTH];
  end
endgenerate
wire signed [DATA_WIDTH-1:0] fft_real_out_array [0:FFT_N-1];
wire signed [DATA_WIDTH-1:0] fft_imag_out_array [0:FFT_N-1];
// Connect to fft_core
fft_core #(.DATA_WIDTH(DATA_WIDTH), .N(FFT_N)) u_fft (
  .clk(clk_fft),
  .reset(reset),
  .start_fft(start_fft),
  .real_in(fft_real_array),
  .imag_in(fft_imag_array),
  .twiddle_addr(twiddle_addr),
  .twiddle_real(twiddle_real),
  .twiddle_imag(twiddle_imag),
  .real_out(fft_real_out_array),
  .imag_out(fft_imag_out_array),
  .fft_done(fft_done)
);
  twiddle_rom #(.DATA_WIDTH(DATA_WIDTH), .N(FFT_N)) u_twiddle (
    .addr(twiddle_addr),
    .twiddle_real(twiddle_real),
    .twiddle_imag(twiddle_imag)
  );

 wire signed [DATA_WIDTH-1:0] ifft_real_array [0:FFT_N-1];
 wire signed [DATA_WIDTH-1:0] ifft_imag_array [0:FFT_N-1];		//copilot added code before line and this line

assign ifft_real_in_flat = fft_real_out_flat; 
  assign ifft_imag_in_flat = fft_imag_out_flat; 

//code is new until the initilization
 genvar g_ifft;
generate
  for (g_ifft = 0; g_ifft < FFT_N; g_ifft = g_ifft + 1) begin : unpack_ifft_input
    assign ifft_real_array[g_ifft] = ifft_real_in_flat[(g_ifft+1)*DATA_WIDTH-1 -: DATA_WIDTH];
    assign ifft_imag_array[g_ifft] = ifft_imag_in_flat[(g_ifft+1)*DATA_WIDTH-1 -: DATA_WIDTH];
  end
endgenerate
wire signed [DATA_WIDTH-1:0] ifft_real_out_array [0:FFT_N-1];
wire signed [DATA_WIDTH-1:0] ifft_imag_out_array [0:FFT_N-1];
  ifft_core #(.DATA_WIDTH(DATA_WIDTH), .N(FFT_N)) u_ifft (
  .clk(clk_fft),
  .reset(reset),
  .start_ifft(start_fft),
  .real_in(ifft_real_array),
  .imag_in(ifft_imag_array),
  .twiddle_addr(twiddle_addr),
  .twiddle_real(twiddle_real),
  .twiddle_imag(twiddle_imag),
  .real_out(ifft_real_out_array),
  .imag_out(ifft_imag_out_array),
  .ifft_done(fft_done)
);

//code from copilot for output buffer

  assign output_real_in_flat = ifft_real_out_flat;
  assign output_imag_in_flat = ifft_imag_out_flat;

wire signed [DATA_WIDTH-1:0] output_real_array [0:FFT_N-1];
wire signed [DATA_WIDTH-1:0] output_imag_array [0:FFT_N-1];

genvar g_out;
generate
  for (g_out = 0; g_out < FFT_N; g_out = g_out + 1) begin : unpack_output_buffer_input
    assign output_real_array[g_out] = output_real_in_flat[(g_out+1)*DATA_WIDTH-1 -: DATA_WIDTH];
    assign output_imag_array[g_out] = output_imag_in_flat[(g_out+1)*DATA_WIDTH-1 -: DATA_WIDTH];
  end
endgenerate
wire signed [DATA_WIDTH-1:0] output_real_out_array [0:FFT_N-1];
wire signed [DATA_WIDTH-1:0] output_imag_out_array [0:FFT_N-1];
  output_buffer #(.DATA_WIDTH(DATA_WIDTH), .N(FFT_N)) u_output (
  .clk(clk),
  .reset(reset),
  .store(fft_done),
  .read_en(dma_valid),
  .read_addr(dma_done ? 4'h0 : 4'hF),
  .read_done(dma_done),
  .real_in(output_real_array),  // ✅ unpacked array
  .imag_in(output_imag_array),  // ✅ unpacked array
  .real_out(output_real_out_array),
  .imag_out(output_imag_out_array),
  .buffer_ready(buffer_ready)
);

  dma_controller #(.DATA_WIDTH(DATA_WIDTH), .BLOCK_SIZE(BUFFER_SIZE)) u_dma (
    .clk(clk_dma), .reset(reset), .start_dma_out(start_dma_out),
    .output_buffer_flat(dma_output_flat),
    .dma_data_out(dma_data_out), .dma_valid(dma_valid), .dma_done(dma_done)
  );

//code from copilot

genvar g_intf;
generate
  for (g_intf = 0; g_intf < FFT_N; g_intf = g_intf + 1) begin : unpack_interface_input
    assign output_real_out_array[g_intf] = output_real_out_flat[(g_intf+1)*DATA_WIDTH-1 -: DATA_WIDTH];
    assign output_imag_out_array[g_intf] = output_imag_out_flat[(g_intf+1)*DATA_WIDTH-1 -: DATA_WIDTH];
  end
endgenerate

  interface1 #(.DATA_WIDTH(DATA_WIDTH), .N(FFT_N)) u_interface (
  .clk(clk),
  .reset(reset),
  .buffer_ready(buffer_ready),
  .real_in(output_real_out_array),  // ✅ unpacked array
  .imag_in(output_imag_out_array),  // ✅ unpacked array
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
    reset = 1;
    valid_in = 0;
    sample_in = 0;
    #20 reset = 0;
    repeat (BUFFER_SIZE) begin  // 256 iterations
      valid_in = 1;
      sample_in = $random % (1 << DATA_WIDTH);
      #10;
      valid_in = 0;
      #10;
    end
    wait (dma_done);
    $display("DMA completed at time %0t", $time);
    #100;
    $finish;
  end

  initial $monitor("Time=%0t | FIR=%b FFT=%b DMA=%b Active=%b BufferReady=%b",
                   $time, fir_done, fft_done, dma_done, processing_active, buffer_ready);

endmodule
