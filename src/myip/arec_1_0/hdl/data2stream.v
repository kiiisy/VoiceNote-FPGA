// data2stream.v
// internal packed data (36-bit) -> AXI-Stream
// - One-word buffer with backpressure
// - Unpack {tid,tdata} and drive AXIS

module data2stream (
    input  wire         clk,
    input  wire         reset,

    // enable (from sys_ctrl): 1=active output, 0=force idle
    input  wire         en,

    // Internal input
    input  wire [35:0]  in_packed,
    input  wire         in_valid,
    output wire         in_ready,

    // AXI-Stream Master
    output wire [31:0]  m_axis_tdata,
    output wire         m_axis_tvalid,
    input  wire         m_axis_tready,
    output wire [ 2:0]  m_axis_tid
);

    // -------------------------------
    // 内部信号
    // -------------------------------
    reg        r_valid;
    reg [31:0] r_tdata;
    reg [ 2:0] r_tid;

    wire w_out_fire;
    wire w_in_fire;

    assign w_out_fire = r_valid & m_axis_tready;

    // can accept when buffer empty OR will be consumed
    wire w_can_accept = (~r_valid) | w_out_fire;

    assign in_ready = en & w_can_accept;
    assign w_in_fire = in_valid & in_ready;

    // unpack (ignore pad)
    wire [ 2:0] w_in_tid   = in_packed[35:33];
    wire [31:0] w_in_tdata = in_packed[32:1];

    // -------------------------------
    // 1-word buffer
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_valid <= 1'b0;
            r_tdata <= 32'd0;
            r_tid   <= 3'd0;
        end else begin
            if (!en) begin
                r_valid <= 1'b0;
            end else begin
                case ({w_in_fire, w_out_fire})
                2'b10: begin
                    // input only
                    r_valid <= 1'b1;
                    r_tdata <= w_in_tdata;
                    r_tid   <= w_in_tid;
                end
                2'b01: begin
                    // output only
                    r_valid <= 1'b0;
                end
                2'b11: begin
                    // replace
                    r_valid <= 1'b1;
                    r_tdata <= w_in_tdata;
                    r_tid   <= w_in_tid;
                end
                default: begin
                    r_valid <= r_valid;
                end
                endcase
            end
        end
    end

    // -------------------------------
    // AXIS outputs
    // -------------------------------
    assign m_axis_tvalid = r_valid;
    assign m_axis_tdata  = r_tdata;
    assign m_axis_tid    = r_tid;

endmodule
