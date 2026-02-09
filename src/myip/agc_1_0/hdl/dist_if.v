module dist_if (
    input  wire        clk,
    input  wire        reset,

    // from dToF
    input  wire        rx,

    // to dist2gain
    output wire [15:0] dist_mm,
    output wire        dist_valid,

    // to register
    output wire        pkt_error,
    output wire        frame_error,
    output wire        tof_working
);

    // -------------------------------
    // 内部信号
    // -------------------------------
    wire [ 7:0] w_rx_byte;
    wire        w_rx_valid;

    uart_rx U_uart_rx (
        .clk           (clk),           // in
        .reset         (reset),         // in
        .rx            (rx),            // in
        .data          (w_rx_byte),     // out
        .valid         (w_rx_valid),    // out
        .frame_error   (frame_error)    // out
    );

    frame_parser U_frame_parser (
        .clk           (clk),           // in
        .reset         (reset),         // in
        .rx_byte       (w_rx_byte),     // in
        .rx_valid      (w_rx_valid),    // in
        .dist_mm       (dist_mm),       // out
        .dist_valid    (dist_valid),    // out
        .pkt_error     (pkt_error),     // out
        .tof_working   (tof_working)    // out
    );

endmodule
