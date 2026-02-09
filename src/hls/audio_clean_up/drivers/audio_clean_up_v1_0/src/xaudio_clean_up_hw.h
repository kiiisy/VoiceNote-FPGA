// ==============================================================
// Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2024.2 (64-bit)
// Tool Version Limit: 2024.11
// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// 
// ==============================================================
// acu
// 0x00 : Control signals
//        bit 0  - ap_start (Read/Write/COH)
//        bit 1  - ap_done (Read/COR)
//        bit 2  - ap_idle (Read)
//        bit 3  - ap_ready (Read/COR)
//        bit 7  - auto_restart (Read/Write)
//        bit 9  - interrupt (Read)
//        others - reserved
// 0x04 : Global Interrupt Enable Register
//        bit 0  - Global Interrupt Enable (Read/Write)
//        others - reserved
// 0x08 : IP Interrupt Enable Register (Read/Write)
//        bit 0 - enable ap_done interrupt (Read/Write)
//        bit 1 - enable ap_ready interrupt (Read/Write)
//        others - reserved
// 0x0c : IP Interrupt Status Register (Read/TOW)
//        bit 0 - ap_done (Read/TOW)
//        bit 1 - ap_ready (Read/TOW)
//        others - reserved
// 0x10 : Data signal of dc_a_coef
//        bit 31~0 - dc_a_coef[31:0] (Read/Write)
// 0x14 : reserved
// 0x18 : Data signal of dc_pass
//        bit 0  - dc_pass[0] (Read/Write)
//        others - reserved
// 0x1c : reserved
// 0x20 : Data signal of th_open_amp
//        bit 31~0 - th_open_amp[31:0] (Read/Write)
// 0x24 : Data signal of th_open_amp
//        bit 1~0 - th_open_amp[33:32] (Read/Write)
//        others  - reserved
// 0x28 : reserved
// 0x2c : Data signal of th_close_amp
//        bit 31~0 - th_close_amp[31:0] (Read/Write)
// 0x30 : Data signal of th_close_amp
//        bit 1~0 - th_close_amp[33:32] (Read/Write)
//        others  - reserved
// 0x34 : reserved
// 0x38 : Data signal of a_attack
//        bit 23~0 - a_attack[23:0] (Read/Write)
//        others   - reserved
// 0x3c : reserved
// 0x40 : Data signal of a_release
//        bit 23~0 - a_release[23:0] (Read/Write)
//        others   - reserved
// 0x44 : reserved
// 0x48 : Data signal of b_attack
//        bit 23~0 - b_attack[23:0] (Read/Write)
//        others   - reserved
// 0x4c : reserved
// 0x50 : Data signal of b_release
//        bit 23~0 - b_release[23:0] (Read/Write)
//        others   - reserved
// 0x54 : reserved
// 0x58 : Data signal of ng_pass
//        bit 0  - ng_pass[0] (Read/Write)
//        others - reserved
// 0x5c : reserved
// (SC = Self Clear, COR = Clear on Read, TOW = Toggle on Write, COH = Clear on Handshake)

#define XAUDIO_CLEAN_UP_ACU_ADDR_AP_CTRL           0x00
#define XAUDIO_CLEAN_UP_ACU_ADDR_GIE               0x04
#define XAUDIO_CLEAN_UP_ACU_ADDR_IER               0x08
#define XAUDIO_CLEAN_UP_ACU_ADDR_ISR               0x0c
#define XAUDIO_CLEAN_UP_ACU_ADDR_DC_A_COEF_DATA    0x10
#define XAUDIO_CLEAN_UP_ACU_BITS_DC_A_COEF_DATA    32
#define XAUDIO_CLEAN_UP_ACU_ADDR_DC_PASS_DATA      0x18
#define XAUDIO_CLEAN_UP_ACU_BITS_DC_PASS_DATA      1
#define XAUDIO_CLEAN_UP_ACU_ADDR_TH_OPEN_AMP_DATA  0x20
#define XAUDIO_CLEAN_UP_ACU_BITS_TH_OPEN_AMP_DATA  34
#define XAUDIO_CLEAN_UP_ACU_ADDR_TH_CLOSE_AMP_DATA 0x2c
#define XAUDIO_CLEAN_UP_ACU_BITS_TH_CLOSE_AMP_DATA 34
#define XAUDIO_CLEAN_UP_ACU_ADDR_A_ATTACK_DATA     0x38
#define XAUDIO_CLEAN_UP_ACU_BITS_A_ATTACK_DATA     24
#define XAUDIO_CLEAN_UP_ACU_ADDR_A_RELEASE_DATA    0x40
#define XAUDIO_CLEAN_UP_ACU_BITS_A_RELEASE_DATA    24
#define XAUDIO_CLEAN_UP_ACU_ADDR_B_ATTACK_DATA     0x48
#define XAUDIO_CLEAN_UP_ACU_BITS_B_ATTACK_DATA     24
#define XAUDIO_CLEAN_UP_ACU_ADDR_B_RELEASE_DATA    0x50
#define XAUDIO_CLEAN_UP_ACU_BITS_B_RELEASE_DATA    24
#define XAUDIO_CLEAN_UP_ACU_ADDR_NG_PASS_DATA      0x58
#define XAUDIO_CLEAN_UP_ACU_BITS_NG_PASS_DATA      1

