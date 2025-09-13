module dma_controller #(
    parameter DATA_WIDTH = 12,
    parameter BLOCK_SIZE = 256
)(
    input wire clk,
    input wire reset,
    input wire start_dma_out,  // trigger from controller

    // Flattened input buffer (all samples in one wide bus)
    input wire [DATA_WIDTH*BLOCK_SIZE-1:0] output_buffer_flat,

    output reg [DATA_WIDTH-1:0] dma_data_out, // output to external system
    output reg dma_valid,                     // valid signal
    output reg dma_done                       // high when block dispatched
);

    reg [$clog2(BLOCK_SIZE):0] dma_ptr;  // sample pointer
    reg dma_active;                      // DMA active flag

    // Unpack flattened buffer into array
    wire [DATA_WIDTH-1:0] output_buffer [0:BLOCK_SIZE-1];
    genvar i;
    generate
        for (i = 0; i < BLOCK_SIZE; i = i + 1) begin : UNPACK
            assign output_buffer[i] = 
                output_buffer_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH];
        end
    endgenerate

    // FSM for DMA
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            dma_ptr      <= 0;
            dma_valid    <= 0;
            dma_done     <= 0;
            dma_active   <= 0;
            dma_data_out <= 0;
        end 
        else begin
            if (start_dma_out && !dma_active) begin
                dma_active <= 1;
                dma_ptr    <= 0;
                dma_done   <= 0;
            end 
            else if (dma_active) begin
                dma_data_out <= output_buffer[dma_ptr];
                dma_valid    <= 1;
                dma_ptr      <= dma_ptr + 1;

                if (dma_ptr == BLOCK_SIZE - 1) begin
                    dma_active <= 0;
                    dma_done   <= 1;
                    dma_valid  <= 0;
                end
            end 
            else begin
                dma_valid <= 0;
                dma_done  <= 0;
            end
        end
    end

endmodule
