module wr_ctrl #(
    parameter integer DEPTH = 2048,
    parameter integer WIDTH = 36
) (
    input  wire clk,
    input  wire reset,

    input  wire en,

    input  wire [WIDTH-1:0] in_packed,
    input  wire             in_valid,
    output wire             in_ready,

    output reg              bram_we,
    output reg  [$clog2(DEPTH)-1:0] bram_waddr,
    output reg  [WIDTH-1:0] bram_wdata,

    output reg  [$clog2(DEPTH)-1:0] wr_ptr
);

    localparam S_IDLE  = 1'b0;
    localparam S_WRITE = 1'b1;

    reg r_state, r_next_state;

    assign in_ready = (r_state == S_IDLE) && en;

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
            if (en && in_valid) begin
                r_next_state = S_WRITE;
            end
        end
        S_WRITE: begin
            r_next_state = S_IDLE;
        end
        endcase
    end

    // outputs / datapath
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            bram_we    <= 1'b0;
            bram_waddr <= 0;
            bram_wdata <= 0;
            wr_ptr     <= 0;
        end else begin
            bram_we <= 1'b0;

            if (r_state == S_IDLE && r_next_state == S_WRITE) begin
                bram_we    <= 1'b1;
                bram_waddr <= wr_ptr;
                bram_wdata <= in_packed;

                // ring increment
                wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1'b1;
            end
        end
    end

endmodule
