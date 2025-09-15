module ifft_core #(
    parameter DATA_WIDTH = 16, 
    parameter N = 16           
)(
    input wire clk,            
    input wire reset,         
    input wire start_ifft,     //start signal

    input wire signed [DATA_WIDTH-1:0] real_in [0:N-1],  //freq domain inputs
    input wire signed [DATA_WIDTH-1:0] imag_in [0:N-1],

    output reg [$clog2(N)-1:0] twiddle_addr,           //twiddle ROM address
    input wire signed [DATA_WIDTH-1:0] twiddle_real,   //twiddle real input
    input wire signed [DATA_WIDTH-1:0] twiddle_imag,   //twiddle imag input

    output reg signed [DATA_WIDTH-1:0] real_out [0:N-1], //time domain outputs
    output reg signed [DATA_WIDTH-1:0] imag_out [0:N-1],
    output reg ifft_done       //done flag
);

    //internal storage
    reg signed [DATA_WIDTH-1:0] stage_real [0:N-1];  //intermediate buffers
    reg signed [DATA_WIDTH-1:0] stage_imag [0:N-1];
    reg [3:0] stage;                                //FSM stage counter
    reg ifft_active;                                //active flag

    //twiddle multiplication (positive exponential for IFFT)
    task automatic twiddle_mul;
        input signed [DATA_WIDTH-1:0] xr, xi;   // Input sample
        input signed [DATA_WIDTH-1:0] wr, wi;   // Twiddle factor
        output signed [DATA_WIDTH-1:0] yr, yi;  // Result
        reg signed [2*DATA_WIDTH-1:0] temp_r, temp_i;
        begin
            temp_r = xr * wr + xi * wi;         // IFFT: + for real
            temp_i = -xr * wi + xi * wr;        // IFFT: - for imag
            yr = temp_r >>> (DATA_WIDTH - 2);   // Scale (Q2.14 assumed)
            yi = temp_i >>> (DATA_WIDTH - 2);
        end
    endtask

    // Radix-4 butterfly task
    task automatic butterfly_radix4;
        input integer i0, i1, i2, i3;       // 4 indices
        input integer twiddle_base;         // Twiddle offset (-1 for no twiddles)
        reg signed [DATA_WIDTH-1:0] a_r, a_i, b_r, b_i, c_r, c_i, d_r, d_i;
        reg signed [DATA_WIDTH-1:0] tb_r, tb_i, tc_r, tc_i, td_r, td_i;
        begin
            // Load inputs
            a_r = stage_real[i0]; a_i = stage_imag[i0];
            b_r = stage_real[i1]; b_i = stage_imag[i1];
            c_r = stage_real[i2]; c_i = stage_imag[i2];
            d_r = stage_real[i3]; d_i = stage_imag[i3];

            // Apply twiddles only if twiddle_base != -1 (stage 1)
            if (twiddle_base != -1) begin
                twiddle_addr = twiddle_base + 1; // W^1
                twiddle_mul(b_r, b_i, twiddle_real, twiddle_imag, tb_r, tb_i);
                twiddle_addr = twiddle_base + 2; // W^2
                twiddle_mul(c_r, c_i, twiddle_real, twiddle_imag, tc_r, tc_i);
                twiddle_addr = twiddle_base + 3; // W^3
                twiddle_mul(d_r, d_i, twiddle_real, twiddle_imag, td_r, td_i);
            end else begin
                tb_r = b_r; tb_i = b_i;
                tc_r = c_r; tc_i = c_i;
                td_r = d_r; td_i = d_i;
            end

            // Butterfly equations
            stage_real[i0] = a_r + tb_r + tc_r + td_r;         // Out0 = a + b + c + d
            stage_imag[i0] = a_i + tb_i + tc_i + td_i;

            stage_real[i1] = a_r - tb_i + tc_r - td_i;         // Out1 = a + jb - c - jd
            stage_imag[i1] = a_i + tb_r - tc_i - td_r;

            stage_real[i2] = a_r - tb_r + tc_r - td_r;         // Out2 = a - b + c - d
            stage_imag[i2] = a_i - tb_i + tc_i - td_i;

            stage_real[i3] = a_r + tb_i - tc_r + td_i;         // Out3 = a - jb - c + jd
            stage_imag[i3] = a_i - tb_r - tc_i - td_r;
        end
    endtask

    // FSM for IFFT stages
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            stage <= 0;
            ifft_active <= 0;
            ifft_done <= 0;
            twiddle_addr <= 0;
            for (i = 0; i < N; i = i + 1) begin
                stage_real[i] <= 0;
                stage_imag[i] <= 0;
                real_out[i] <= 0;
                imag_out[i] <= 0;
            end
        end else begin
            if (start_ifft && !ifft_active) begin
                ifft_active <= 1;
                stage <= 0;
                ifft_done <= 0;
                // Load input samples
                for (i = 0; i < N; i = i + 1) begin
                    stage_real[i] <= real_in[i];
                    stage_imag[i] <= imag_in[i];
                end
            end else if (ifft_active) begin
                case (stage)
                    // Stage 0: 4-point IFFTs (no twiddles)
                    0: begin
                        butterfly_radix4(0, 1, 2, 3, -1);    // Group 0
                        butterfly_radix4(4, 5, 6, 7, -1);    // Group 1
                        butterfly_radix4(8, 9, 10, 11, -1);  // Group 2
                        butterfly_radix4(12, 13, 14, 15, -1); // Group 3
                        stage <= 1;
                    end
                    // Stage 1: Cross-group butterflies (with twiddles)
                    1: begin
                        butterfly_radix4(0, 4, 8, 12, 0);    // Group 0, twiddle base 0
                        butterfly_radix4(1, 5, 9, 13, 4);    // Group 1, twiddle base 4
                        butterfly_radix4(2, 6, 10, 14, 8);   // Group 2, twiddle base 8
                        butterfly_radix4(3, 7, 11, 15, 12);  // Group 3, twiddle base 12
                        stage <= 2;
                    end
                    // Stage 2: Output with scaling
                    2: begin
                        for (i = 0; i < N; i = i + 1) begin
                            real_out[i] <= stage_real[i] >>> 4; // Divide by N=16
                            imag_out[i] <= stage_imag[i] >>> 4;
                        end
                        ifft_done <= 1;
                        ifft_active <= 0;
                    end
                    default: begin
                        ifft_active <= 0;
                        ifft_done <= 0;
                    end
                endcase
            end else begin
                ifft_done <= 0;
            end
        end
    end


endmodule
