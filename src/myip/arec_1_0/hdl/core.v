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

    // レジスタ
    input  wire [C_S00_AXI_DATA_WIDTH-1:0] control_reg,
    input  wire [C_S00_AXI_DATA_WIDTH-1:0] threshold_reg,
    input  wire [C_S00_AXI_DATA_WIDTH-1:0] window_samples_reg,
    input  wire [C_S00_AXI_DATA_WIDTH-1:0] pretrig_samples_reg,
    output wire [15:0]                     status_reg,
    output wire [ 2:0]                     state_reg
);
    // -------------------------------
    // 内部信号
    // -------------------------------

    // output of sys_ctrl
    wire w_trigger;
    wire w_dump_done;
    wire w_en_wr;
    wire w_en_rd;
    wire w_start_dump;
    wire w_is_dump;

    // output of stream2data
    wire               w_sample_stb;
    wire signed [15:0] w_sample16_data;
    wire        [35:0] w_packed_data;

    sys_ctrl U_sys_ctrl(
        .clk            (clk),              // in
        .reset          (reset),            // in
        .enable         (control_reg[0]),   // in
        .trigger        (w_trigger),        // in
        .dump_done      (w_dump_done),      // in
        .af_tready      (m00_axis_tready),  // in
        .state_reg      (state_reg),        // in
        .i2s_tready     (reset),            // in
        .en_stream2data (/* not use */),    // out
        .en_wr          (w_en_wr),          // out
        .en_rd          (w_en_rd),          // out
        .start_dump     (w_start_dump),     // out
        .is_dump        (w_is_dump)         // out
    );

    stream2data U_stream2data(
        .clk            (clk),              // in
        .s_axis_tdata   (s00_axis_tdata),   // in
        .s_axis_tvalid  (s00_axis_tvalid),  // in
        .s_axis_tready  (m00_axis_tready),  // in
        .s_axis_tid     (s00_axis_tid),     // in
        .sample_stb     (w_sample_stb),     // out
        .packed_data    (w_sample16_data),  // out
        .sample16_data  (w_packed_data)     // out
    );

    window_detector U_window_detector(
        .clk                (clk),           // in
        .reset              (reset),         // in
        .en                 (reset),         // in
        .sample_stb         (reset),         // in
        .sample16_data      (reset),         // in
        .tid                (reset),         // in
        .threshold_reg      (reset),         // out
        .trigger_pulse_reg  (reset),         // out
        .level_last_reg     (reset),         // out
        .level_max_reg      (reset),         // out
        .above_th_last_reg  (reset)          // out
    );

    bram_ctrl U_bram_ctrl(
        .clk              (clk),              // in
        .reset            (reset),            // in
        .wr_en            (reset),            // in
        .in_valid         (reset),            // in
        .in_ready         (reset),            // out
        .in_packed        (reset),            // in
        .rd_en            (reset),            // in
        .start_dump       (reset),            // in
        .dump_len         (reset),            // in
        .dump_done        (reset),            // out
        .out_packed       (reset),            // out
        .out_valid        (reset),            // out
        .out_ready        (reset)             // in
    );

    data2stream U_data2stream(
        .clk               (clk),              // in
        .reset             (reset),            // in
        .en                (reset),            // in
        .in_packed         (reset),            // in
        .in_valid          (reset),            // in
        .in_ready          (reset),            // in
        .m_axis_tdata      (reset),            // in
        .m_axis_tvalid     (reset),            // in
        .m_axis_tready     (reset),            // in
        .m_axis_tid        (reset)             // in
    );

endmodule
