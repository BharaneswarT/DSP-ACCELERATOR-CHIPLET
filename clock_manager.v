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

    // Latched enable signals
    reg enable_fir_latched;
    reg enable_fft_latched;
    reg enable_dma_latched;

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

    // Latch enable signals
    always @(posedge clk_in or posedge reset) begin
        if (reset) begin
            enable_fir_latched <= 0;
            enable_fft_latched <= 0;
            enable_dma_latched <= 0;
        end else begin
            if (enable_fir) enable_fir_latched <= 1;
            if (enable_fft) enable_fft_latched <= 1;
            if (enable_dma) enable_dma_latched <= 1;
        end
    end

    // Clock gating logic (registered outputs)
    always @(posedge clk_in or posedge reset) begin
        if (reset) begin
            clk_fir <= 0;
            clk_fft <= 0;
            clk_dma <= 0;
        end else begin
            clk_fir <= enable_fir_latched ? clk_div2 : 1'b0;
            clk_fft <= enable_fft_latched ? clk_div2 : 1'b0;
            clk_dma <= enable_dma_latched ? clk_div4 : 1'b0;
        end
    end

endmodule
