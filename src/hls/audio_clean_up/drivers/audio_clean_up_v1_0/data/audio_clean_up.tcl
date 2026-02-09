# ==============================================================
# Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2024.2 (64-bit)
# Tool Version Limit: 2024.11
# Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
# Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
# 
# ==============================================================
proc generate {drv_handle} {
    xdefine_include_file $drv_handle "xparameters.h" "XAudio_clean_up" \
        "NUM_INSTANCES" \
        "DEVICE_ID" \
        "C_S_AXI_ACU_BASEADDR" \
        "C_S_AXI_ACU_HIGHADDR"

    xdefine_config_file $drv_handle "xaudio_clean_up_g.c" "XAudio_clean_up" \
        "DEVICE_ID" \
        "C_S_AXI_ACU_BASEADDR"

    xdefine_canonical_xpars $drv_handle "xparameters.h" "XAudio_clean_up" \
        "DEVICE_ID" \
        "C_S_AXI_ACU_BASEADDR" \
        "C_S_AXI_ACU_HIGHADDR"
}

