module clock_manager (
    input wire clk_in,               
    input wire reset,               
	 
    input wire enable_fir,           // enable FIR clock
    input wire enable_fft,           // enable FFT clock
    input wire enable_dma,           // enable DMA clock
	 
    output reg clk_fir,              // gated FIR clock
    output reg clk_fft,              // gated FFT clock
    output reg clk_dma               // gated DMA clock
);

    // Internal divided clocks 
    reg clk_div2, clk_div4;

    // Frequency division logic (divide-by-2 and divide-by-4)
    always @(posedge clk_in or posedge reset) begin
        if (reset) begin
            clk_div2 <= 0;
            clk_div4 <= 0;
        end else begin
            clk_div2 <= ~clk_div2;
            clk_div4 <= clk_div2 ? ~clk_div4 : clk_div4;
        end
    end

    // Clock gating logic   we do this to SAve a whole ass lot of power
    always @(*) begin
        clk_fir = enable_fir ? clk_div2 : 1'b0;    //FIR module is getting paused
        clk_fft = enable_fft ? clk_div2 : 1'b0;   //FFT module is getting paused 
        clk_dma = enable_dma ? clk_div4 : 1'b0;     //DMA module getting paused 
    end

endmodule