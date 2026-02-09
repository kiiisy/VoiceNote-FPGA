// ==============================================================
// Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2024.2 (64-bit)
// Tool Version Limit: 2024.11
// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// 
// ==============================================================
/***************************** Include Files *********************************/
#include "xaudio_clean_up.h"

/************************** Function Implementation *************************/
#ifndef __linux__
int XAudio_clean_up_CfgInitialize(XAudio_clean_up *InstancePtr, XAudio_clean_up_Config *ConfigPtr) {
    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(ConfigPtr != NULL);

    InstancePtr->Acu_BaseAddress = ConfigPtr->Acu_BaseAddress;
    InstancePtr->IsReady = XIL_COMPONENT_IS_READY;

    return XST_SUCCESS;
}
#endif

void XAudio_clean_up_Start(XAudio_clean_up *InstancePtr) {
    u32 Data;

    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XAudio_clean_up_ReadReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_AP_CTRL) & 0x80;
    XAudio_clean_up_WriteReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_AP_CTRL, Data | 0x01);
}

u32 XAudio_clean_up_IsDone(XAudio_clean_up *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XAudio_clean_up_ReadReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_AP_CTRL);
    return (Data >> 1) & 0x1;
}

u32 XAudio_clean_up_IsIdle(XAudio_clean_up *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XAudio_clean_up_ReadReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_AP_CTRL);
    return (Data >> 2) & 0x1;
}

u32 XAudio_clean_up_IsReady(XAudio_clean_up *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XAudio_clean_up_ReadReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_AP_CTRL);
    // check ap_start to see if the pcore is ready for next input
    return !(Data & 0x1);
}

void XAudio_clean_up_EnableAutoRestart(XAudio_clean_up *InstancePtr) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XAudio_clean_up_WriteReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_AP_CTRL, 0x80);
}

void XAudio_clean_up_DisableAutoRestart(XAudio_clean_up *InstancePtr) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XAudio_clean_up_WriteReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_AP_CTRL, 0);
}

void XAudio_clean_up_Set_dc_a_coef(XAudio_clean_up *InstancePtr, u32 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XAudio_clean_up_WriteReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_DC_A_COEF_DATA, Data);
}

u32 XAudio_clean_up_Get_dc_a_coef(XAudio_clean_up *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XAudio_clean_up_ReadReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_DC_A_COEF_DATA);
    return Data;
}

void XAudio_clean_up_Set_dc_pass(XAudio_clean_up *InstancePtr, u32 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XAudio_clean_up_WriteReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_DC_PASS_DATA, Data);
}

u32 XAudio_clean_up_Get_dc_pass(XAudio_clean_up *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XAudio_clean_up_ReadReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_DC_PASS_DATA);
    return Data;
}

void XAudio_clean_up_Set_th_open_amp(XAudio_clean_up *InstancePtr, u64 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XAudio_clean_up_WriteReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_TH_OPEN_AMP_DATA, (u32)(Data));
    XAudio_clean_up_WriteReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_TH_OPEN_AMP_DATA + 4, (u32)(Data >> 32));
}

u64 XAudio_clean_up_Get_th_open_amp(XAudio_clean_up *InstancePtr) {
    u64 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XAudio_clean_up_ReadReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_TH_OPEN_AMP_DATA);
    Data += (u64)XAudio_clean_up_ReadReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_TH_OPEN_AMP_DATA + 4) << 32;
    return Data;
}

void XAudio_clean_up_Set_th_close_amp(XAudio_clean_up *InstancePtr, u64 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XAudio_clean_up_WriteReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_TH_CLOSE_AMP_DATA, (u32)(Data));
    XAudio_clean_up_WriteReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_TH_CLOSE_AMP_DATA + 4, (u32)(Data >> 32));
}

u64 XAudio_clean_up_Get_th_close_amp(XAudio_clean_up *InstancePtr) {
    u64 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XAudio_clean_up_ReadReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_TH_CLOSE_AMP_DATA);
    Data += (u64)XAudio_clean_up_ReadReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_TH_CLOSE_AMP_DATA + 4) << 32;
    return Data;
}

void XAudio_clean_up_Set_a_attack(XAudio_clean_up *InstancePtr, u32 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XAudio_clean_up_WriteReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_A_ATTACK_DATA, Data);
}

u32 XAudio_clean_up_Get_a_attack(XAudio_clean_up *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XAudio_clean_up_ReadReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_A_ATTACK_DATA);
    return Data;
}

void XAudio_clean_up_Set_a_release(XAudio_clean_up *InstancePtr, u32 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XAudio_clean_up_WriteReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_A_RELEASE_DATA, Data);
}

u32 XAudio_clean_up_Get_a_release(XAudio_clean_up *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XAudio_clean_up_ReadReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_A_RELEASE_DATA);
    return Data;
}

void XAudio_clean_up_Set_b_attack(XAudio_clean_up *InstancePtr, u32 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XAudio_clean_up_WriteReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_B_ATTACK_DATA, Data);
}

u32 XAudio_clean_up_Get_b_attack(XAudio_clean_up *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XAudio_clean_up_ReadReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_B_ATTACK_DATA);
    return Data;
}

void XAudio_clean_up_Set_b_release(XAudio_clean_up *InstancePtr, u32 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XAudio_clean_up_WriteReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_B_RELEASE_DATA, Data);
}

u32 XAudio_clean_up_Get_b_release(XAudio_clean_up *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XAudio_clean_up_ReadReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_B_RELEASE_DATA);
    return Data;
}

void XAudio_clean_up_Set_ng_pass(XAudio_clean_up *InstancePtr, u32 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XAudio_clean_up_WriteReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_NG_PASS_DATA, Data);
}

u32 XAudio_clean_up_Get_ng_pass(XAudio_clean_up *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XAudio_clean_up_ReadReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_NG_PASS_DATA);
    return Data;
}

void XAudio_clean_up_InterruptGlobalEnable(XAudio_clean_up *InstancePtr) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XAudio_clean_up_WriteReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_GIE, 1);
}

void XAudio_clean_up_InterruptGlobalDisable(XAudio_clean_up *InstancePtr) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XAudio_clean_up_WriteReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_GIE, 0);
}

void XAudio_clean_up_InterruptEnable(XAudio_clean_up *InstancePtr, u32 Mask) {
    u32 Register;

    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Register =  XAudio_clean_up_ReadReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_IER);
    XAudio_clean_up_WriteReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_IER, Register | Mask);
}

void XAudio_clean_up_InterruptDisable(XAudio_clean_up *InstancePtr, u32 Mask) {
    u32 Register;

    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Register =  XAudio_clean_up_ReadReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_IER);
    XAudio_clean_up_WriteReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_IER, Register & (~Mask));
}

void XAudio_clean_up_InterruptClear(XAudio_clean_up *InstancePtr, u32 Mask) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XAudio_clean_up_WriteReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_ISR, Mask);
}

u32 XAudio_clean_up_InterruptGetEnabled(XAudio_clean_up *InstancePtr) {
    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    return XAudio_clean_up_ReadReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_IER);
}

u32 XAudio_clean_up_InterruptGetStatus(XAudio_clean_up *InstancePtr) {
    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    return XAudio_clean_up_ReadReg(InstancePtr->Acu_BaseAddress, XAUDIO_CLEAN_UP_ACU_ADDR_ISR);
}

