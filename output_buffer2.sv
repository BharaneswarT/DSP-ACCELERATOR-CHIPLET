module output_buffer #(
    parameter DATA_WIDTH = 16,  
    parameter N = 16           
)(
    input wire clk,            
    input wire reset,          
	 
    input wire store,          //latch input samples
    input wire read_en,        //enable sample read
    input wire [3:0] read_addr, 	//address for sample read (0 to 15)
    input wire read_done,      //external module read complete

    input wire signed [DATA_WIDTH-1:0] real_in [0:N-1],  //time samples from IFFT
    input wire signed [DATA_WIDTH-1:0] imag_in [0:N-1],

    output reg signed [DATA_WIDTH-1:0] real_out [0:N-1], //buffered samples
    output reg signed [DATA_WIDTH-1:0] imag_out [0:N-1],
    output reg buffer_ready    //data ready for read
);

    reg storing;               //FSM state
    reg [4:0] i;               //loop counter (5 bits for N=16)

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            storing <= 0;
            buffer_ready <= 0;
            for (i = 0; i < N; i = i + 1) begin
                real_out[i] <= 0;
                imag_out[i] <= 0;
            end
        end else begin
            if (store && !storing) begin
                //latch inputs in one cycle
                storing <= 1;
                buffer_ready <= 0;
                for (i = 0; i < N; i = i + 1) begin
                    real_out[i] <= real_in[i];
                    imag_out[i] <= imag_in[i];
                end
                buffer_ready <= 1;  //signal data ready
                storing <= 0;
					 
					 
            end else if (read_en && buffer_ready) begin
                //output one sample at read_addr (for streaming)
					 
                real_out[read_addr] <= real_out[read_addr]; //hold value
                imag_out[read_addr] <= imag_out[read_addr];
					 
					 
            end else if (read_done && buffer_ready) begin
                //external module signals read complete
                buffer_ready <= 0;
            end else begin
                //idle, hold outputs
                buffer_ready <= buffer_ready;
            end
        end
    end

endmodule