module freq_filter #(
    parameter DATA_WIDTH = 16,
    parameter N = 16
)(
    input wire clk,
    input wire reset,
    input wire start_filter,

    input wire signed [DATA_WIDTH-1:0] real_in [0:N-1],
    input wire signed [DATA_WIDTH-1:0] imag_in [0:N-1],
    input wire [0:N-1] mask,  // 1 = keep, 0 = zero out

    output reg signed [DATA_WIDTH-1:0] real_out [0:N-1],
    output reg signed [DATA_WIDTH-1:0] imag_out [0:N-1],
    output reg filter_done
);

    integer i;
    reg filtering;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            filtering <= 0;
            filter_done <= 0;
            for (i = 0; i < N; i = i + 1) begin
                real_out[i] <= 0;
                imag_out[i] <= 0;
            end
        end else begin
            if (start_filter && !filtering) begin
                filtering <= 1;
                filter_done <= 0;
                for (i = 0; i < N; i = i + 1) begin
                    if (mask[i]) begin
                        real_out[i] <= real_in[i];
                        imag_out[i] <= imag_in[i];
                    end else begin
                        real_out[i] <= 0;
                        imag_out[i] <= 0;
                    end
                end
                filter_done <= 1;
                filtering <= 0;
            end else begin
                filter_done <= 0;
            end
        end
    end

endmodule