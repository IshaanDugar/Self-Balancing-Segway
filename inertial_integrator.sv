// Group name: The Flip-Floppers
// Members: Thomas Derleth, Ishaan Dugar, Colin Grommon, James Teague
module inertial_integrator (
    input  logic clk,
    input  logic rst_n,
    input  logic vld,    // High for one clock when new inertial readings are valid
    input  logic signed [15:0] ptch_rt,    // 16-bit signed raw pitch rate from gyro
    input  logic signed [15:0] AZ,    // 16-bit signed accel Z (for fusion)
    output logic signed [15:0] ptch    // 16-bit signed fused pitch output
);

    // Local parameters and internal signals
    localparam signed [15:0] PTCH_RT_OFFSET = 16'h0050; // gyro offset
    localparam signed [15:0] AZ_OFFSET      = 16'h00A0; // accelerometer offset

    logic signed [15:0] ptch_rt_comp;
    logic signed [15:0] AZ_comp;
    logic signed [26:0] ptch_int;
    logic signed [26:0] fusion_ptch_offset;
    logic signed [31:0] ptch_acc_product;
    logic signed [15:0] ptch_acc;

    // Compensation for sensor offsets
    assign ptch_rt_comp = ptch_rt - PTCH_RT_OFFSET;
    assign AZ_comp      = AZ - AZ_OFFSET;

    // Pitch estimation from accelerometer (small-angle approximation)
    always_comb begin
        ptch_acc_product = AZ_comp * 16'sd327;    // scaled accel-based pitch
        ptch_acc = {{3{ptch_acc_product[25]}}, ptch_acc_product[25:13]};    // Scaled down to 16-bit equivalent
    end

    // Fusion correction term generation
    always_comb begin
        if (ptch_acc > ptch)
            fusion_ptch_offset = 27'sd1024;   // leak upward
        else
            fusion_ptch_offset = -27'sd1024;   // leak downward
    end

    // Accumulator register: Performs inertial integration by summing the negative of the pitch rate (ptch_rt_comp)
    // on each valid reading.
    // The fusion offset is also applied to correct long-term drift.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ptch_int <= 27'sd0;
        end else if (vld) begin
            ptch_int <= ptch_int - {{11{ptch_rt_comp[15]}}, ptch_rt_comp} + fusion_ptch_offset;
        end
    end

    // Output scaling (divide by 2^11)
    assign ptch = ptch_int[26:11];

endmodule