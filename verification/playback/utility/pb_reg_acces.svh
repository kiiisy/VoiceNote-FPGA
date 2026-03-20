// ------------------------------------------------------------
// ベースアドレス定義
// ------------------------------------------------------------
localparam logic [31:0] AGC_BASE = 32'h44A0_0000;

// ------------------------------------------------------------
// AXI-Lite 書き込みヘルパー
// ------------------------------------------------------------
task automatic axi_agc_write(input logic [31:0] offset, input logic [31:0] data);
    axi_agc_mst.AXI4LITE_WRITE_BURST(AGC_BASE + offset, 0, data, resp);
endtask

// ------------------------------------------------------------
// AGC設定
// ------------------------------------------------------------
task automatic set_agc_reg(
    input logic [31:0] control_reg,
    input logic [31:0] dist_sensitivity_reg,
    input logic [31:0] manual_gain_reg,
    input logic [31:0] gain_min_reg,
    input logic [31:0] gain_max_reg,
    input logic [31:0] alpha_config_reg
);
    r_ref_control_reg          = control_reg;
    r_ref_dist_sensitivity_reg = dist_sensitivity_reg;
    r_ref_manual_gain_reg      = manual_gain_reg;
    r_ref_gain_min_reg         = gain_min_reg;
    r_ref_gain_max_reg         = gain_max_reg;
    r_ref_alpha_config_reg     = alpha_config_reg;

    axi_agc_write(32'h10, dist_sensitivity_reg);
    axi_agc_write(32'h14, manual_gain_reg);
    axi_agc_write(32'h20, gain_min_reg);
    axi_agc_write(32'h24, gain_max_reg);
    axi_agc_write(32'h28, alpha_config_reg);
    axi_agc_write(32'h00, control_reg);
endtask

task automatic set_agc_default_reg();
    set_agc_reg(
        32'h0000_0000,
        32'h0000_2000,
        32'h0000_0000,
        32'h0000_2000,
        32'h0000_7FFF,
        32'h0000_0006
    );
endtask
