// Simple fixed-point PID math block:
//   - Takes signed pitch error, pitch rate, and an accumulated integral term
//   - Applies proportional, integral (scaled), and derivative (negated rate) components
//   - Saturates intermediary error and final control output to defined bit widths
module PID
#(
    parameter fast_sim = 1
)
(
    input clk,
    input rst_n,
    input vld,
    input pwr_up,
    input rider_off,
    input signed [15:0] ptch,
    input signed [15:0] ptch_rt,
    output signed [11:0] PID_cntrl,
    output [7:0] ss_tmr
);
    logic signed [9:0] ptch_err_sat;
    logic signed [14:0] P_term;
    logic signed [14:0] I_term;
    logic signed [12:0] D_term;
    logic signed [15:0] sum;

    logic signed [17:0] integrator;

    assign ptch_err_sat =   (!ptch[15] && |ptch[14:9]) ? 10'h1FF :
                            (ptch[15] && !(&ptch[14:9])) ? 10'h200 :
                            ptch[9:0];

    logic ov;
    logic signed [17:0] ext_ptch_err_sat;
    logic signed [17:0] new_integrator;

    assign ext_ptch_err_sat = {{8{ptch_err_sat[9]}}, ptch_err_sat[9:0]};
    
    assign new_integrator[17:0] = integrator[17:0] + ext_ptch_err_sat[17:0];
    // Overflow occurs if integrator and ptch_err_sat have same sign and
    assign ov = (integrator[17] == ptch_err_sat[9]) && (integrator[17] != new_integrator[17]);

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            integrator[17:0] <= 18'h00000;
        end
        else if(rider_off) begin
            integrator[17:0] <= 18'h00000;
        end 
        else if(vld & !ov) begin
            integrator[17:0] <= new_integrator[17:0];
        end
    end

    localparam signed [4:0] P_COEFF = 5'h09;

    assign P_term = ptch_err_sat * P_COEFF;
    generate if(fast_sim) begin
            // Tap bits [15:1] to form I_term, but saturate
            assign I_term =  (!integrator[17] && |integrator[17:15]) ? 15'h3FFF :
                             (integrator[17] && !(&integrator[17:15])) ? 15'h4000 :
                             integrator[15:1];
    end else begin
            assign I_term = {{3{integrator[17]}}, integrator[17:6]}; // Divide by 64
        end
    endgenerate
    assign D_term = -({{3{ptch_rt[15]}}, ptch_rt[15:6]});

    // Sign-extend each term to the same width before summing
    assign sum = ({P_term[14], P_term})
               + {I_term[14], I_term}
               + ({{3{D_term[12]}}, D_term}); 

    // Saturate the final output to fit in 12 bits
    assign PID_cntrl = (!sum[15] && |sum[14:11]) ? 12'h7FF : // Cap at +2047
                      (sum[15] && !(&sum[14:11])) ? 12'h800 : // Cap at -2048
                      (sum[11:0]);

    // Ramp up of ss_tmr formed from upper 8 bits of a 27-bit timer
    logic [26:0] long_tmr;
    logic [26:0] increment;
    generate if(fast_sim) begin
        assign increment = 27'h0000100; // Ramp up by 256 per step
    end else begin
        assign increment = 27'h0000001; // Ramp up by 1 per step
    end
    endgenerate

    // 27-bit timer for soft-start ramp
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            long_tmr <= 27'h0000000;
        end
        else if(!pwr_up) begin
            long_tmr <= 27'h0000000;
        end
        else if(!(&long_tmr[26:19])) begin
            long_tmr <= long_tmr + increment;
        end
    end
    assign ss_tmr = long_tmr[26:19];
endmodule