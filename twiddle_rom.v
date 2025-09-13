module twiddle_rom #(
    parameter DATA_WIDTH = 16,
    parameter N = 16
)(
    input wire [$clog2(N)-1:0] addr,			//4bits since log2(16)=4
	 
    output reg signed [DATA_WIDTH-1:0] twiddle_real,	//real part
    output reg signed [DATA_WIDTH-1:0] twiddle_imag		//imaginary part
);

    always @(*) begin
        case (addr)
		  
		  //look up table (LUT)
		  
            4'd0: begin twiddle_real = 16'sd32767; twiddle_imag = 16'sd0;     end // W0 = 1 + j0
				
            4'd1: begin twiddle_real = 16'sd23170; twiddle_imag = -16'sd23170;end // W1 = cos(π/4) - j·sin(π/4)
				
            4'd2: begin twiddle_real = 16'sd0;     twiddle_imag = -16'sd32767;end // W2 = cos(π/2) - j·sin(π/2)
				
            4'd3: begin twiddle_real = -16'sd23170;twiddle_imag = -16'sd23170;end // W3 = cos(3π/4) - j·sin(3π/4)
				
            4'd4: begin twiddle_real = -16'sd32767;twiddle_imag = 16'sd0;     end // W4 = -1 + j0
				
            4'd5: begin twiddle_real = -16'sd23170;twiddle_imag = 16'sd23170; end // W5 = cos(5π/4) - j·sin(5π/4)
				
            4'd6: begin twiddle_real = 16'sd0;     twiddle_imag = 16'sd32767; end // W6 = cos(3π/2) - j·sin(3π/2)
				
            4'd7: begin twiddle_real = 16'sd23170; twiddle_imag = 16'sd23170; end // W7 = cos(7π/4) - j·sin(7π/4)
				
				4'd8:  begin twiddle_real = -16'sd32767; twiddle_imag =  16'sd0;     end // W8
				
            4'd9:  begin twiddle_real = -16'sd30273; twiddle_imag =  16'sd12539; end // W9
				
            4'd10: begin twiddle_real = -16'sd23170; twiddle_imag =  16'sd23170; end // W10
				
            4'd11: begin twiddle_real = -16'sd12539; twiddle_imag =  16'sd30273; end // W11
				
            4'd12: begin twiddle_real =  16'sd0;     twiddle_imag =  16'sd32767; end // W12
				
            4'd13: begin twiddle_real =  16'sd12539; twiddle_imag =  16'sd30273; end // W13
				
            4'd14: begin twiddle_real =  16'sd23170; twiddle_imag =  16'sd23170; end // W14
				
            4'd15: begin twiddle_real =  16'sd30273; twiddle_imag =  16'sd12539; end // W15

           
            default: begin
                twiddle_real = 16'sd0;
                twiddle_imag = 16'sd0;
            end
        endcase
    end

endmodule