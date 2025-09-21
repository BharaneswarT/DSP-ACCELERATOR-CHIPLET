module tb_controller;
    reg clk = 0;
    reg reset = 1;
    reg ready_for_processing = 0;
    reg fir_done = 0;
    reg fft_done = 0;
    reg config_mode = 0;  // 0=FIR, 1=FFT
    
    wire start_fir, start_fft, start_dma_out, processing_active;

    controller uut (
        .clk(clk),
        .reset(reset),
        .ready_for_processing(ready_for_processing),
        .fir_done(fir_done),
        .fft_done(fft_done),
        .config_mode(config_mode),
        .start_fir(start_fir),
        .start_fft(start_fft),
        .start_dma_out(start_dma_out),
        .processing_active(processing_active)
    );
    
    always #5 clk = ~clk; 
    initial begin
        $dumpfile("controller_tb.vcd");
        $dumpvars(0, tb_controller);
    end
    
    initial begin
      $display("time\tState\tReady\tConfig\tFIR_Done\tFFT_Done\tStart_FIR\tStart_FFT\tDMA_Out\tActive");
        
        // reset setting
        #20 reset = 0;
        $display("t=%0t: Reset released", $time);
        
        // 1st test making FIR as active
        #10 config_mode = 0;  // FIR
        #10 ready_for_processing = 1;  // data ready
        #20 ready_for_processing = 0;  // data acknowledged
        
        // simulating FIR processing 
        #100 fir_done = 1;
        #10 fir_done = 0;
        
        #20 start_dma_out = 0;  // Auto-clears, but simulate
        #10 $display("t=%0t: FIR test complete", $time);
        
        // test 2: FFT Mode  
        #50 config_mode = 1;  // FFT
        #10 ready_for_processing = 1;
        #20 ready_for_processing = 0;
        
        // Simulate FFT processing 
        #200 fft_done = 1;
        #10 fft_done = 0;
        
        #20 $display("t=%0t: FFT test complete", $time);
        
        #50 $finish;
    end
    
    // monitoring state changes
    always @(posedge clk) begin
        $display("%0t\t%d\t\t%b\t%b\t%b\t\t%b\t\t%b\t\t%b\t\t%b\t%b", 
                 $time, uut.current_state, ready_for_processing, config_mode,
                 fir_done, fft_done, start_fir, start_fft, start_dma_out, processing_active);
    end
    
endmodule
