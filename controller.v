module controller #(
    parameter BLOCK_SIZE = 256
)(
    input wire clk,
    input wire reset,

    // status signals from other modules
    input wire ready_for_processing,   // from input_buffer
    input wire fir_done,               // from fir_filter
    input wire fft_done,               // from fft_core
    input wire config_mode,            // control signal to choose FIR/FFT 0 = FIR, 1 = FFT

    // Control outputs to other modules
    output reg start_fir,
    output reg start_fft,
    output reg start_dma_out,
    output reg processing_active
);

    // FSM state encoding
    reg [2:0] current_state, next_state;

    localparam STATE_IDLE       = 3'b000,
               STATE_WAIT_INPUT = 3'b001,
               STATE_START_PROC = 3'b010,
               STATE_WAIT_DONE  = 3'b011,
               STATE_DISPATCH   = 3'b100;

    // FSM Sequential logic
    always @(posedge clk or posedge reset) begin
        if (reset)
            current_state <= STATE_IDLE;
        else
            current_state <= next_state;
    end

    // FSM: Combinational logic
    always @(*) begin
        // Default outputs
        start_fir         = 1'b0;
        start_fft         = 1'b0;
        start_dma_out     = 1'b0;
        processing_active = 1'b0;

        case (current_state)
            STATE_IDLE: begin
                if (ready_for_processing)
                    next_state = STATE_START_PROC;
                else
                    next_state = STATE_IDLE;
            end
                 
					  
					  //logic to begin the FFT or FIR process
            STATE_START_PROC: begin
                processing_active = 1'b1;
                if (config_mode == 1'b0)
                    start_fir = 1'b1;      //triggers the FIR
                else
                    start_fft = 1'b1;         // triggers the FFT
                next_state = STATE_WAIT_DONE;
            end
						
						
						//tells the controller that process (FFT/FIR) is completed 
            STATE_WAIT_DONE: begin
                processing_active = 1'b1;
                if ((config_mode == 1'b0 && fir_done) ||
                    (config_mode == 1'b1 && fft_done))
                    next_state = STATE_DISPATCH;
                else
                    next_state = STATE_WAIT_DONE;
            end
							
							
							//after the processes is completed, release the output
            STATE_DISPATCH: begin
                start_dma_out = 1'b1;
                next_state = STATE_IDLE;
            end

            default: next_state = STATE_IDLE;
        endcase
    end

endmodule
