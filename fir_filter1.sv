module fir_filter #(
    parameter DATA_WIDTH = 12,
    parameter TAPS = 16
)(
    input wire clk,
    input wire reset,
    input wire start_fir,                 // Start filtering
    input wire [1:0] filter_mode,         // 00 = LPF, 01 = HPF, 10 = BPF
    input wire signed [DATA_WIDTH-1:0] input_buffer [0:TAPS-1], // input samples
    output reg signed [DATA_WIDTH-1:0] fir_output,
    output reg fir_done
);

    // FIR coefficients (pre-computed and quantized)
    reg signed [DATA_WIDTH-1:0] coeffs [0:TAPS-1];

    reg [$clog2(TAPS):0] tap_ptr;
    reg signed [2*DATA_WIDTH-1:0] acc;
    reg fir_active;

	 
    // Load coefficients based on mode
    always @(*) begin
        case (filter_mode)
            //LPF example 
            2'b00: begin
                coeffs[0]  =  12'sd100;  coeffs[1]  =  12'sd200;
                coeffs[2]  =  12'sd400;  coeffs[3]  =  12'sd600;
                coeffs[4]  =  12'sd800;  coeffs[5]  =  12'sd1000;
                coeffs[6]  =  12'sd1200; coeffs[7]  =  12'sd1400;
                coeffs[8]  =  12'sd1400; coeffs[9]  =  12'sd1200;
                coeffs[10] =  12'sd1000; coeffs[11] =  12'sd800;
                coeffs[12] =  12'sd600;  coeffs[13] =  12'sd400;
                coeffs[14] =  12'sd200;  coeffs[15] =  12'sd100;
            end

            // HPF example 
            2'b01: begin
                coeffs[0]  = -12'sd100;  coeffs[1]  = -12'sd200;
                coeffs[2]  = -12'sd300;  coeffs[3]  = -12'sd400;
                coeffs[4]  = -12'sd500;  coeffs[5]  = -12'sd600;
                coeffs[6]  = -12'sd700;  coeffs[7]  =  12'sd9000;
                coeffs[8]  =  12'sd9000; coeffs[9]  = -12'sd700;
                coeffs[10] = -12'sd600;  coeffs[11] = -12'sd500;
                coeffs[12] = -12'sd400;  coeffs[13] = -12'sd300;
                coeffs[14] = -12'sd200;  coeffs[15] = -12'sd100;
            end

            // BPF example 
            2'b10: begin
                coeffs[0]  =  12'sd0;    coeffs[1]  =  12'sd100;
                coeffs[2]  =  12'sd200;  coeffs[3]  =  12'sd400;
                coeffs[4]  =  12'sd600;  coeffs[5]  =  12'sd800;
                coeffs[6]  =  12'sd1000; coeffs[7]  = -12'sd1200;
                coeffs[8]  = -12'sd1200; coeffs[9]  =  12'sd1000;
                coeffs[10] =  12'sd800;  coeffs[11] =  12'sd600;
                coeffs[12] =  12'sd400;  coeffs[13] =  12'sd200;
                coeffs[14] =  12'sd100;  coeffs[15] =  12'sd0;
            end

            default: begin
                integer i;
                for (i = 0; i < TAPS; i = i + 1)
                    coeffs[i] = 12'sd0;
            end
        endcase
    end

    // FIR MAC process
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tap_ptr    <= 0;
            acc        <= 0;
            fir_output <= 0;
            fir_done   <= 0;
            fir_active <= 0;
        end else begin
            if (start_fir && !fir_active) begin
                fir_active <= 1;
                tap_ptr    <= 0;
                acc        <= 0;
                fir_done   <= 0;
            end else if (fir_active) begin
                acc <= acc + input_buffer[tap_ptr] * coeffs[tap_ptr];
                tap_ptr <= tap_ptr + 1;

                if (tap_ptr == TAPS - 1) begin
                    fir_output <= acc >>> 12; // scale back (since coeffs scaled up)
                    fir_done   <= 1;
                    fir_active <= 0;
                end
            end else begin
                fir_done <= 0;
            end
        end
    end

endmodule
