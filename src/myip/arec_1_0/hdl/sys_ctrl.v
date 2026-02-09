// sys_ctrl.v
// System controller FSM (PASS / ARMED / DUMP)
//
// PASS  : normal pass-through (I2S -> AudioFormatter)
// ARMED : monitoring + pretrigger buffering (output still I2S)
// DUMP  : output BRAM data, stop upstream I2S
//
// Notes:
// - enable=0 forces PASS
// - clear is not used
// - after DUMP, always return to PASS

module sys_ctrl (
    input  wire clk,
    input  wire reset,

    // control
    input  wire enable,     // 1: arm auto-record, 0: pure pass-through

    // trigger & dump status
    input  wire trigger,    // from window_detector
    input  wire dump_done,  // from rd_ctrl

    // downstream AXIS
    input  wire af_tready,

    // debug / status
    output wire [1:0] state_reg,

    // upstream (to I2S_RX)
    output wire i2s_tready,

    // enables
    output wire en_stream2data,
    output wire en_wr,
    output wire en_rd,

    // rd_ctrl control
    output wire start_dump,

    // output source select
    // 0: I2S (normal)
    // 1: BRAM (dump)
    output wire is_dump
);

    // -------------------------------
    // State encoding
    // -------------------------------
    localparam S_PASS  = 2'd0;
    localparam S_ARMED = 2'd1;
    localparam S_DUMP  = 2'd2;

    // -------------------------------
    // State registers
    // -------------------------------
    reg [1:0] r_state;
    reg [1:0] r_next_state;

    assign state_reg = r_state;

    // -------------------------------
    // State register
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_state <= S_PASS;
        end else begin
            r_state <= r_next_state;
        end
    end

    // -------------------------------
    // Next-state logic
    // -------------------------------
    always @(*) begin
        // default
        r_next_state = r_state;

        // enable=0 always forces PASS
        if (!enable) begin
            r_next_state = S_PASS;
        end else begin
            case (r_state)
            // ---------------------------
            // PASS: normal pass-through
            // ---------------------------
            S_PASS: begin
                r_next_state = S_ARMED;
            end

            // ---------------------------
            // ARMED: waiting for trigger
            // ---------------------------
            S_ARMED: begin
                if (trigger) begin
                    r_next_state = S_DUMP;
                end else begin
                    r_next_state = S_ARMED;
                end
            end

            // ---------------------------
            // DUMP: output BRAM
            // ---------------------------
            S_DUMP: begin
                if (dump_done) begin
                    r_next_state = S_PASS;
                end else begin
                    r_next_state = S_DUMP;
                end
            end

            default: begin
                r_next_state = S_PASS;
            end
            endcase
        end
    end

    // -------------------------------
    // start_dump pulse (ARMED -> DUMP)
    // -------------------------------
    assign start_dump = (r_state == S_ARMED) && (r_next_state == S_DUMP);

    // -------------------------------
    // Enables
    // -------------------------------
    // stream2data: ARMED only (monitoring)
    assign en_stream2data = (r_state == S_ARMED);

    // wr_ctrl: ARMED only (pretrigger buffer)
    assign en_wr = (r_state == S_ARMED);

    // rd_ctrl: DUMP only
    assign en_rd = (r_state == S_DUMP);

    // -------------------------------
    // Output select
    // -------------------------------
    // 0: I2S pass-through
    // 1: BRAM dump
    assign is_dump = (r_state == S_DUMP || r_state == S_ARMED);

    // -------------------------------
    // Upstream tready
    // -------------------------------
    // PASS  : follow downstream (pure pass-through)
    // ARMED : stop I2S
    // DUMP  : stop I2S
    assign i2s_tready =
        (r_state == S_DUMP || r_state == S_ARMED) ? 1'b0 : af_tready;

endmodule
