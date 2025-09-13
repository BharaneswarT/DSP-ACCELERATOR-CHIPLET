module interface1 #(
    parameter DATA_WIDTH = 16,
    parameter N = 16
)(
    input wire clk,
    input wire reset,

    //from output_buffer
    input wire buffer_ready,
    input wire signed [DATA_WIDTH-1:0] real_in [0:N-1],
    input wire signed [DATA_WIDTH-1:0] imag_in [0:N-1],
	 
	 input wire dma_ack,  // Acknowledge from DMA

    //DMA or memory interface
    output reg signed [DATA_WIDTH-1:0] dma_real,
    output reg signed [DATA_WIDTH-1:0] dma_imag,
    output reg dma_valid,
	 
    output reg done      //signals completion of transfer
);

    reg [3:0] index;
    reg transferring;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            index <= 0;
            transferring <= 0;
            dma_valid <= 0;
            dma_real <= 0;
            dma_imag <= 0;
            done <= 0;
        end else begin
            if (buffer_ready && !transferring) begin
				
                //start transfer
                transferring <= 1;
                index <= 0;
                done <= 0;
					 
            end else if (transferring) begin
				
                if (!dma_valid) begin
                    //present data to DMA
                    dma_real <= real_in[index];
                    dma_imag <= imag_in[index];
                    dma_valid <= 1;
						  
                end else if (dma_ack) begin
                    // DMA accepted data
                    dma_valid <= 0;
                    index <= index + 1;
                    if (index == N - 1) begin
                        transferring <= 0;
                        done <= 1;
                    end
                end
            end else begin
                done <= 0;
            end
        end
    end

endmodule