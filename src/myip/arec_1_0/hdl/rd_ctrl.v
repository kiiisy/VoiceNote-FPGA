module rd_ctrl #(
    parameter integer DEPTH = 2048,
    parameter integer WIDTH = 36,
    parameter integer READ_LATENCY = 1
) (
    input  wire clk,
    input  wire reset,
    input  wire en,

    input  wire start_dump,
    input  wire [$clog2(DEPTH+1)-1:0] dump_len,
    input  wire [$clog2(DEPTH)-1:0]   start_ptr,

    output reg              bram_re,
    output reg  [$clog2(DEPTH)-1:0] bram_raddr,
    input  wire [WIDTH-1:0] bram_rdata,

    output reg  [WIDTH-1:0] out_packed,
    output reg              out_valid,
    input  wire             out_ready,

    output reg              dump_done
);

    localparam S_IDLE   = 3'd0;
    localparam S_REQ    = 3'd1;
    localparam S_WAIT   = 3'd2;
    localparam S_OUT    = 3'd3;
    localparam S_NEXT   = 3'd4;

    reg [2:0] r_state, r_next_state;
    reg [$clog2(DEPTH)-1:0] r_ptr;
    reg [$clog2(DEPTH+1)-1:0] r_rem;
    reg [$clog2(READ_LATENCY+1)-1:0] r_wait;

    // state reg
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_state <= S_IDLE;
        end else begin
            r_state <= r_next_state;
        end
    end

    // next state
    always @(*) begin
        r_next_state = r_state;

        case (r_state)
        S_IDLE: begin
            if (en && start_dump) begin
                r_next_state = S_REQ;
            end
        end

        S_REQ: begin
            r_next_state = S_WAIT;
        end

        S_WAIT:begin
            if (r_wait == READ_LATENCY-1) begin
                r_next_state = S_OUT;
            end
        end

        S_OUT:begin
            if (out_ready) begin
                 r_next_state = S_NEXT;
            end
        end

        S_NEXT: begin
            r_next_state = (r_rem == 1) ? S_IDLE : S_REQ;
        end

        endcase
    end

    // datapath
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            bram_re   <= 0;
            out_valid <= 0;
            dump_done <= 0;
            r_wait    <= 0;
        end else begin
            bram_re   <= 0;
            out_valid <= 0;
            dump_done <= 0;

            case (r_state)
            S_IDLE: begin
                if (start_dump) begin
                    r_ptr <= start_ptr;
                    r_rem <= dump_len;
                end
            end

            S_REQ: begin
                bram_re    <= 1'b1;
                bram_raddr <= r_ptr;
                r_wait     <= 0;
            end

            S_WAIT: r_wait <= r_wait + 1'b1;

            S_OUT: begin
                out_valid  <= 1'b1;
                out_packed <= bram_rdata;
            end

            S_NEXT: begin
                r_ptr <= (r_ptr == DEPTH-1) ? 0 : r_ptr + 1'b1;
                r_rem <= r_rem - 1'b1;
                if (r_rem == 1) begin
                    dump_done <= 1'b1;
                end
            end
            endcase
        end
    end

endmodule
