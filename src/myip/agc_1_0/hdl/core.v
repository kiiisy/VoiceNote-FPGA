module core #(
    parameter integer C_S00_AXI_DATA_WIDTH = 32
)(
    input  wire clk,
    input  wire reset,

    // AXI-Stream Slave
    input  wire [C_S00_AXI_DATA_WIDTH-1:0] s00_axis_tdata,
    input  wire                            s00_axis_tvalid,
    output wire                            s00_axis_tready,
    input  wire [ 2:0]                     s00_axis_tid,

    // AXI-Stream Master
    output wire [C_S00_AXI_DATA_WIDTH-1:0] m00_axis_tdata,
    output wire                            m00_axis_tvalid,
    input  wire                            m00_axis_tready,
    output wire [ 2:0]                     m00_axis_tid,

    // dToFセンサーIF
    input  wire rx,
    output wire tx,

    // レジスタ
    input  wire [C_S00_AXI_DATA_WIDTH-1:0] control_reg,
    input  wire [C_S00_AXI_DATA_WIDTH-1:0] dist_sensitivity_reg,
    input  wire [C_S00_AXI_DATA_WIDTH-1:0] manual_gain_reg,
    input  wire [C_S00_AXI_DATA_WIDTH-1:0] gain_min_reg,
    input  wire [C_S00_AXI_DATA_WIDTH-1:0] gain_max_reg,
    input  wire [C_S00_AXI_DATA_WIDTH-1:0] alpha_config_reg,
    output wire [15:0]                     dist_raw_mm_reg,
    output wire [15:0]                     dist_clamp_mm_reg,
    output wire [15:0]                     gain_target_reg,
    output wire [15:0]                     gain_smooth_reg,
    output wire                            tof_working,
    output wire                            clipping_flg,
    output wire                            uart_packet_err,
    output wire                            uart_framing_err
);
    // -------------------------------
    // 内部信号
    // -------------------------------
    // output from dist_if
    wire [15:0] w_dist_mm;
    wire        w_dist_valid;

    // output from dist2gain
    wire [15:0] w_gain_data;
    wire        w_gain_valid;

    // output form iir_filter
    wire signed [15:0] w_smooth_gain;
    wire signed [15:0] w_manual_gain;
    wire signed [15:0] w_gain;

    assign w_manual_gain = manual_gain_reg[15:0];

    dist_if U_dist_if(
        .clk            (clk),              // in
        .reset          (reset),            // in
        .rx             (rx),               // in
        .dist_mm        (w_dist_mm),        // out
        .dist_valid     (w_dist_valid),     // out
        .pkt_error      (uart_packet_err),  // out
        .frame_error    (uart_framing_err), // out
        .tof_working    (tof_working)       // out
    );

    dist2gain U_dist2gain(
        .clk             (clk),              // in
        .reset           (reset),            // in
        .dist_sensitivity_reg (dist_sensitivity_reg), // in
        .dist_data       (w_dist_mm),        // in
        .dist_valid      (w_dist_valid),     // in
        .gain_data       (w_gain_data),      // out
        .gain_valid      (w_gain_valid),     // out
        .dist_raw_mm     (dist_raw_mm_reg),  // out
        .dist_clamp_mm   (dist_clamp_mm_reg) // out
    );

    iir_filter U_iir_filter(
        .clk              (clk),              // in
        .reset            (reset),            // in
        .update_en        (w_gain_valid),     // in
        .target_gain      (w_gain_data),      // in
        .control_reg      (control_reg),      // in
        .alpha_config_reg (alpha_config_reg), // in
        .gain_min_reg     (gain_min_reg),     // in
        .gain_max_reg     (gain_max_reg),     // in
        .smooth_gain      (w_smooth_gain)     // out
    );

    assign w_gain = (control_reg[0]) ? w_manual_gain : w_smooth_gain;

    calculation U_calculation(
        .clk               (clk),              // in
        .reset             (reset),            // in
        .s_axis_tdata      (s00_axis_tdata),   // in
        .s_axis_tvalid     (s00_axis_tvalid),  // in
        .s_axis_tready     (s00_axis_tready),  // out
        .s_axis_tid        (s00_axis_tid),     // in
        .m_axis_tdata      (m00_axis_tdata),   // out
        .m_axis_tvalid     (m00_axis_tvalid),  // out
        .m_axis_tready     (m00_axis_tready),  // in
        .m_axis_tid        (m00_axis_tid),     // out
        .smooth_gain       (w_gain),           // in
        .clip_flg          (clipping_flg)      // out
    );

    // 一旦使用しないため固定にしておく
    assign tx = 1'd1;

    assign gain_target_reg = (w_gain_valid) ? w_gain_data : 16'd0;
    assign gain_smooth_reg = w_smooth_gain;

endmodule
