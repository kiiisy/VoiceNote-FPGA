// stream2data.v (final, no backpressure)
//
// AXI-Stream -> internal data tap
// - No buffering
// - No backpressure decision
// - 1-cycle strobe on handshake
//
// internal packed format:
//   { tid[2:0], tdata[31:0], pad[0] } = 36-bit

module stream2data (
    input  wire         clk,
    input  wire         reset,

    // AXI-Stream Slave
    input  wire [31:0]  s_axis_tdata,
    input  wire         s_axis_tvalid,
    input  wire         s_axis_tready,  // decided by upstream MUX / sys_ctrl
    input  wire [ 2:0]  s_axis_tid,

    // Internal outputs
    output wire         sample_stb,
    output wire [35:0]  packed_data,
    output wire signed [15:0] sample16_data
);

    // -------------------------------
    // Handshake detection
    // -------------------------------
    assign sample_stb = s_axis_tvalid & s_axis_tready;

    // -------------------------------
    // Data extraction (combinational)
    // -------------------------------
    // Packed data for BRAM (store everything)
    assign packed_data = {
        s_axis_tid,        // [35:33]
        s_axis_tdata,      // [32:1]
        1'b0               // [0] pad
    };

    // Sample for window detector (16-bit audio)
    // AES AXIS format: sample in [27:12] when 16-bit mode
    assign sample16_data = s_axis_tdata[27:12];

endmodule
