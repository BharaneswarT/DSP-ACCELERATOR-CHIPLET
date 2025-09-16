module input_buffer1 #(
    parameter DATA_WIDTH = 16,
    parameter BUFFER_SIZE = 256
)(
    input clk,
    input reset,
    input valid_in,
    input [DATA_WIDTH-1:0] sample_in,
    input wire ready_ack,
    output reg ready_for_processing,
    output wire [DATA_WIDTH*BUFFER_SIZE-1:0] buffer_flat_a,
    output wire [DATA_WIDTH*BUFFER_SIZE-1:0] buffer_flat_b,
    output reg buffer_select  // 0 for buffer_a, 1 for buffer_b
);

    reg [DATA_WIDTH-1:0] buffer_a [0:BUFFER_SIZE-1];
    reg [DATA_WIDTH-1:0] buffer_b [0:BUFFER_SIZE-1];
    reg [$clog2(BUFFER_SIZE):0] write_ptr;
    reg buffer_full;

    // Flatten buffers for external access
    genvar i;
    generate
        for (i = 0; i < BUFFER_SIZE; i = i + 1) begin : flatten_buffer_a
            assign buffer_flat_a[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] = buffer_a[i];
        end
        for (i = 0; i < BUFFER_SIZE; i = i + 1) begin : flatten_buffer_b
            assign buffer_flat_b[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] = buffer_b[i];
        end
    endgenerate

    always @(posedge clk or posedge reset) begin
    if (reset) begin
        write_ptr <= 0;
        ready_for_processing <= 0;
        buffer_select <= 0;
        buffer_full <= 0;
    end else if (ready_ack) begin
        buffer_select <= ~buffer_select;
        write_ptr <= 0;
        ready_for_processing <= 0;
        buffer_full <= 0;
    end else if (valid_in && !buffer_full) begin
        if (buffer_select == 0)
            buffer_a[write_ptr] <= sample_in;
        else
            buffer_b[write_ptr] <= sample_in;

        write_ptr <= write_ptr + 1;
        if (write_ptr == BUFFER_SIZE - 1) begin
            buffer_full <= 1;
            ready_for_processing <= 1;
        end
    end
end

endmodule

