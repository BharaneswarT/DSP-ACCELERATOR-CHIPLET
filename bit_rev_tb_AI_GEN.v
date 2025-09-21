module tb_bit_reversal;
    reg clk = 0, reset = 1, start_reorder = 0;
    reg signed [255:0] real_in, imag_in;
    wire signed [255:0] real_out, imag_out;
    wire reorder_done;
    
    bit_reversal uut (
        .clk(clk), .reset(reset), .start_reorder(start_reorder),
        .real_in(real_in), .imag_in(imag_in),
        .real_out(real_out), .imag_out(imag_out),
        .reorder_done(reorder_done)
    );
    
    always #5 clk = ~clk;
    
    initial begin
        $dumpfile("bit_reversal_tb.vcd");
        $dumpvars(0, tb_bit_reversal);
        
        // Load test data: samples 0,1,2,...,15
        real_in = {16'd0, 16'd1, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd7,
                   16'd8, 16'd9, 16'd10,16'd11,16'd12,16'd13,16'd14,16'd15};
        imag_in = 256'b0;  // Real signal only
        
        #10 reset = 0;
        #10 start_reorder = 1;
        #10 start_reorder = 0;
        
        #100;  // Wait for processing
        
        // Check results (manual verification)
        $display("Expected order: [0,8,4,12,2,10,6,14,1,9,5,13,3,11,7,15]");
        $display("Actual real_out[0:15]: %0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                 real_out[15:0], real_out[31:16], real_out[47:32], real_out[63:48], real_out[79:64],
                 real_out[95:80], real_out[111:96], real_out[127:112], real_out[143:128], real_out[159:144],
                 real_out[175:160], real_out[191:176], real_out[207:192], real_out[223:208], real_out[239:224], real_out[255:240]);
        
        #50 $finish;
    end
endmodule
