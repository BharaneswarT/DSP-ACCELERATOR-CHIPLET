module input_buffer1 #(
    parameter DATA_WIDTH = 16,
    parameter BUFFER_SIZE = 256
)(
    input clk,
    input reset,
    input valid_in,
    input [DATA_WIDTH-1:0] sample_in,
    output reg ready_for_processing,
    output logic [DATA_WIDTH*BUFFER_SIZE-1:0] buffer_flat  //  Packed output
);

    reg [DATA_WIDTH-1:0] buffer [0:BUFFER_SIZE-1];
    reg [$clog2(BUFFER_SIZE):0] write_ptr;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            write_ptr <= 0;
            ready_for_processing <= 0;
        end else if (valid_in) begin
            buffer[write_ptr] <= sample_in;
            write_ptr <= write_ptr + 1;

            if (write_ptr == BUFFER_SIZE - 1)
                ready_for_processing <= 1;
        end
    end

    // Flatten buffer for external access
    genvar i;
    generate
        for (i = 0; i < BUFFER_SIZE; i++) begin : flatten_buffer
            assign buffer_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] = buffer[i];
        end
    endgenerate

endmodule
