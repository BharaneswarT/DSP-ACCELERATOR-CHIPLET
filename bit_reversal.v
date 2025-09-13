module bit_reversal #(
    parameter DATA_WIDTH = 16,
    parameter N = 16
)(
    input wire clk,
    input wire reset,
    input wire start_reorder,

    //flattened inputs: [sample0, sample1, ..., sampleN-1]
    input wire signed [N*DATA_WIDTH-1:0] real_in,		//concatinated answer but real value
    input wire signed [N*DATA_WIDTH-1:0] imag_in,		//concatinated answer but imaginary value

    output reg signed [N*DATA_WIDTH-1:0] real_out,	//reordered answer of DIT real part
    output reg signed [N*DATA_WIDTH-1:0] imag_out,	//reordered answer of DIT imaginary part
	 
	 
    output reg reorder_done			//signaling to the controller as ocmpleted 
);

    localparam INDEX_WIDTH = $clog2(N);		//log2(16)=4bits, to count 0 to 15

    integer i, j;   //loop index
    reg [INDEX_WIDTH-1:0] reversed_index;		//holds the bit reversed value of i

    //bit reversal function
	 
    function [INDEX_WIDTH-1:0] reverse_bits;
        input [INDEX_WIDTH-1:0] in;
        integer k;
        begin
            for (k = 0; k < INDEX_WIDTH; k = k + 1)
                reverse_bits[k] = in[INDEX_WIDTH-1-k];
        end
    endfunction

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            reorder_done <= 0;
            real_out <= 0;
            imag_out <= 0;
        end else if (start_reorder) begin
            for (i = 0; i < N; i = i + 1) begin
                reversed_index = reverse_bits(i[INDEX_WIDTH-1:0]);

                // qssign each slice of the output
                real_out[reversed_index*DATA_WIDTH +: DATA_WIDTH] 
                    <= real_in[i*DATA_WIDTH +: DATA_WIDTH];
                imag_out[reversed_index*DATA_WIDTH +: DATA_WIDTH] 
                    <= imag_in[i*DATA_WIDTH +: DATA_WIDTH];
            end
            reorder_done <= 1;
        end else begin
            reorder_done <= 0;
        end
    end

endmodule

