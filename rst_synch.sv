module rst_synch (
    input  logic RST_n,   // async reset from pushbutton (active low)
    input  logic clk,     // system clock
    output logic rst_n    // synchronized reset (active low)
);

    logic synch1, synch2;

    // Negative-edge triggered synchronizer
    always_ff @(negedge clk or negedge RST_n) begin
        if (!RST_n) begin
            synch1 <= 1'b0;
            synch2 <= 1'b0;
        end else begin
            synch1 <= 1'b1;
            synch2 <= synch1;
        end
    end

    // Global reset comes from second stage
    assign rst_n = synch2;

endmodule
