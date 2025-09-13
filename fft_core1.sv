module fft_core #(
    parameter DATA_WIDTH = 16,
    parameter N = 16
)(
    input  wire clk,
    input  wire reset,
    input  wire start_fft,

    //input samples
    input  wire signed [DATA_WIDTH-1:0] real_in [0:N-1],   //real part of the samples	
    input  wire signed [DATA_WIDTH-1:0] imag_in [0:N-1],			//imaginary part of the sampel

    //twiddle ROM interface
    output reg [$clog2(N)-1:0] twiddle_addr, 				//these are address for twiddle factors
    input  wire signed [DATA_WIDTH-1:0] twiddle_real,			//twiddle read part
    input  wire signed [DATA_WIDTH-1:0] twiddle_imag,			//twiddle imaginary part

    //FFT output
    output reg signed [DATA_WIDTH-1:0] real_out [0:N-1],			//the actual output	real part
    output reg signed [DATA_WIDTH-1:0] imag_out [0:N-1],			//actual output imaginary part
    output reg fft_done							//signal saying FFT completed
);

    //internal registers
    reg signed [DATA_WIDTH-1:0] stage_real [0:N-1];  //buffer for real part
    reg signed [DATA_WIDTH-1:0] stage_imag [0:N-1];	//buffer for imaginary part

    reg [3:0] stage; 			//track FFT stages 0,1 for butterfly and 2 for output
    reg fft_active;				//tells that FFT is performing operations

	 
    //twiddle multiply task
    task automatic twiddle_mul;
        input  signed [DATA_WIDTH-1:0] xr, xi;   // input sample for real and imaginary
        input  signed [DATA_WIDTH-1:0] wr, wi;   // twiddle factor for real and imaginary 
        output signed [DATA_WIDTH-1:0] yr, yi;   // result for real and imaginary
        reg signed [2*DATA_WIDTH-1:0] temp_r, temp_i;
		  
        begin
            temp_r = xr*wr - xi*wi;				//complex multiplication real part
            temp_i = xr*wi + xi*wr;				//complex multiplication imaginary part
				
            yr = temp_r >>> (DATA_WIDTH-2);  // scaling back for fixed points 
            yi = temp_i >>> (DATA_WIDTH-2);		//basically prevents overflow in fixed point maths
        end
    endtask

    
    // radix-4 Butterfly (with twiddles)
    
    task automatic butterfly_radix4;
	 
        input integer i0, i1, i2, i3;			//indices for 4 samples
		  
        begin
            reg signed [DATA_WIDTH-1:0] a_r, b_r, c_r, d_r;		//real part	
            reg signed [DATA_WIDTH-1:0] a_i, b_i, c_i, d_i;		//imaginary part 

            //loding the input
            a_r = stage_real[i0]; a_i = stage_imag[i0];
            b_r = stage_real[i1]; b_i = stage_imag[i1];
            c_r = stage_real[i2]; c_i = stage_imag[i2];
            d_r = stage_real[i3]; d_i = stage_imag[i3];

            //radix 4 butterfly equations
            stage_real[i0] = a_r + b_r + c_r + d_r;
            stage_imag[i0] = a_i + b_i + c_i + d_i;

            stage_real[i1] = a_r - b_i + c_r - d_i;
            stage_imag[i1] = a_i + b_r - c_i - d_r;

            stage_real[i2] = a_r - b_r + c_r - d_r;
            stage_imag[i2] = a_i - b_i + c_i - d_i;

            stage_real[i3] = a_r + b_i - c_r + d_i;
            stage_imag[i3] = a_i - b_r - c_i + d_r;

            
        end
    endtask

    
    // FSM for FFT stages
    
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            stage <= 0;
            fft_active <= 0;
            fft_done <= 0;
        end 
		  else begin
            if (start_fft && !fft_active) begin
                fft_active <= 1;
                stage <= 0;
                fft_done <= 0;
					 
                //load input samples
                for (i = 0; i < N; i = i + 1) begin
                    stage_real[i] <= real_in[i];
                    stage_imag[i] <= imag_in[i];
                end

            end 
				else if (fft_active) begin
                case (stage)
                    
						  
                    //stage 0: First 4-point groups
                    
                    0: begin
                        butterfly_radix4(0,1,2,3);
                        butterfly_radix4(4,5,6,7);
                        butterfly_radix4(8,9,10,11);
                        butterfly_radix4(12,13,14,15);
                        stage <= 1;
                    end

                    
                    //stage 1: Combine across groups
                    
                    1: begin
                        butterfly_radix4(0,4,8,12);
                        butterfly_radix4(1,5,9,13);
                        butterfly_radix4(2,6,10,14);
                        butterfly_radix4(3,7,11,15);
                        stage <= 2;
                    end

                    
                    //stage 2: Output stage
                   
				
                    2: begin
                        for (i = 0; i < N; i = i + 1) begin
                            real_out[i] <= stage_real[i];
                            imag_out[i] <= stage_imag[i];
                        end
                        fft_done <= 1;
                        fft_active <= 0;
                    end
                endcase
            end else begin
                fft_done <= 0;
            end
        end
    end

endmodule