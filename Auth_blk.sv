module Auth_blk(
    input  logic clk,         // clock
    input  logic rst_n,       // active-low reset
    input  logic RX,          // UART RX pin
    input  logic rider_off,   // rider presence sensor (1 means rider is off)
    output logic pwr_up       // power enable output
);

logic [7:0] rx_data;  // received byte from UART
logic       rdy;      // pulse: new byte available
logic       clr_rdy;  // handshake: clear rdy in UART

// UART receiver instance
UART_rx u_rx (
    .clk     (clk),
    .rst_n   (rst_n),
    .RX      (RX),
    .clr_rdy (clr_rdy),
    .rx_data (rx_data),
    .rdy     (rdy)
);

// Simple FSM states
typedef enum logic [1:0] {
    IDLE,      // waiting for 'G' to enable
    ENABLED,   // power is up; wait for 'S' and rider_off
    WAIT_OFF   // one-cycle state to turn power off then return to IDLE
} state_t;

state_t state, nxt_state;
logic init, set_off;  // control strobes to set/clear pwr_up

// State register with async reset
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= nxt_state;
end

// pwr_up register control: set on init, clear on set_off, otherwise hold
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        pwr_up <= 1'b0;
    else if (init)
        pwr_up <= 1'b1;
    else if (set_off)
        pwr_up <= 1'b0;
    else
        pwr_up <= pwr_up; // explicit hold
end

logic last_is_S;  // remembers if last received byte was 'S' (0x53)

// Track if the last received byte was 'S'
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        last_is_S <= 1'b0;
    else if (rdy)
        last_is_S <= (rx_data == 8'h53); // remember if last byte was 'S'
end

// Next-state and output logic
always_comb begin
    // Defaults
    nxt_state = state;
    clr_rdy   = 1'b0;
    init      = 1'b0;
    set_off   = 1'b0;

    case (state)
        IDLE: begin
            if (rdy) begin
                clr_rdy = 1'b1;           // consume byte
                if (rx_data == 8'h47) begin // 'G'
                    init      = 1'b1;     // turn power on
                    nxt_state = ENABLED;
                end
            end
        end

        ENABLED: begin
            if (rdy) begin
                clr_rdy = 1'b1;           // consume byte
                if (rx_data == 8'h53 && rider_off) begin // 'S' and rider is off
                    set_off   = 1'b1;     // turn power off
                    nxt_state = WAIT_OFF;
                end
            end
            else if (last_is_S && rider_off) begin
                // If 'S' arrived previously and rider_off asserted later
                set_off   = 1'b1;
                nxt_state = WAIT_OFF;
            end
        end

        WAIT_OFF: nxt_state = IDLE; // return to IDLE after deasserting power
        default:  nxt_state = IDLE; // safe default
    endcase
end

endmodule
