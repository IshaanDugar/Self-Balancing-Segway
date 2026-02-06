// UART Receiver (RX)
// Detect a start bit (falling edge), then sample each bit in the middle of its bit period using a countdown
// divider to reconstruct 8 data bits LSB-first. Double-flop the RX line for metastability, and assert rdy exactly
// once at the end of a full frame; clear rdy on clr_rdy or when a new start is detected.
module UART_rx(
    input clk,
    input rst_n,
    input RX,
    input clr_rdy,
    output logic [7:0]rx_data,
    output logic rdy
    );
// FSM states: idle line high, or actively shifting bits out
    typedef enum logic {
        IDLE,
        RECEIVING
    } state_t;

    // State registers
    state_t current_state, next_state;

    // Ready happens half a bit before tx_done
    logic set_rdy;
    // Counters & control
    logic [3:0] bit_cnt;          // Counts transmitted symbols: 0..8 = start + data[0..7], reaches 9 after last data bit
    logic shift;                  // Pulse each baud period to shift next bit out
    logic [12:0] baud_cnt;        // Baud rate divider counter (counts clk cycles within one bit period)
    logic receiving;              // High while in RECEIVING state
    logic [8:0] rx_shft_reg;      // 8 data bits + start bit (LSB first)
    logic start;                  // Pulse to load shift register / reset counters
    logic RX_sync_0, RX_sync_1;

    // Next-state and output / control signal generation
    always_comb begin
        set_rdy = 1'b0; // Default not ready
        receiving = 1'b0; // Default not receiving
        start = 1'b0;    // Default no start
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (RX == 1'b0) begin
                    start = 1'b1;
                    next_state = RECEIVING;
                end
            end
            RECEIVING: begin
                receiving = 1'b1;
                // bit_cnt == 4'h9 means all 1 start + 8 data bits have been shifted; transition causes line to idle high
                if(bit_cnt == 4'hA) begin
                    set_rdy = 1'b1; // Signal data ready once per frame
                    next_state = IDLE;
                end
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    // State register update with async active-low reset
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Bit counter: reset on start, increment on each shift pulse. Stops incrementing automatically once FSM returns to IDLE.
    always_ff @(posedge clk) begin
        if(start) begin
            bit_cnt <= 4'h0;
        end
        else if(shift) begin
            bit_cnt <= bit_cnt + 1;
        end
    end

    // Baud rate generator: produce single-cycle shift pulse when divider expires.
    // Constant 13'h1457 (5207) corresponds to (BAUD_DIV - 1); e.g., for 50 MHz clk and 9600 baud: 50_000_000 / 9_600 ≈ 5208 cycles/bit.
    // We use 13'h1457 so shift asserts for one cycle, then the counter reloads next cycle.
    always_ff @(posedge clk) begin
        if(start) begin
            baud_cnt <= 13'h0A2B; // Half bit period (2603) to sample mid-start-bit
            shift <= 1'b0;
        end
        else if(shift) begin
            baud_cnt <= 13'h1457;
            shift <= 1'b0;
        end
        else if(receiving) begin
            baud_cnt <= baud_cnt - 1;
            shift <= 1'b0;
            if (baud_cnt == 13'h0000) begin
                shift <= 1'b1;
            end
        end
    end

    // Shift rights at each shift pulse, bringing in new bit from RX line
    always_ff @(posedge clk) begin
        if(shift) begin
            rx_shft_reg <= {RX_sync_1, rx_shft_reg[8:1]};
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdy <= 1'b0;
        end
        else if (clr_rdy || start) begin
            rdy <= 1'b0;
        end
        else if (set_rdy) begin
            rdy <= 1'b1;
        end
    end
    
    // Double flop RX for metastability
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            RX_sync_0 <= 1'b1;
            RX_sync_1 <= 1'b1;
        end
        else begin
            RX_sync_0 <= RX;
            RX_sync_1 <= RX_sync_0;
        end
    end
    assign rx_data = rx_shft_reg[7:0]; // Data bits only, discard start bit
endmodule