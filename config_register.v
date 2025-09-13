module config_register (
    input wire clk,                
    input wire reset,                
    input wire write_enable,         // write strobe from host/testbench
    input wire [4:0] config_in,      // New config value to store
    output reg [4:0] config_mode     // Current config value
);

    // On reset, clear config_mode to default (FIR only)
    // On write_enable, update config_mode with config_in
    always @(posedge clk or posedge reset) begin
        if (reset)
            config_mode <= 5'b00000; // Default: FIR mode, all features off
        else if (write_enable)
            config_mode <= config_in;
    end

endmodule