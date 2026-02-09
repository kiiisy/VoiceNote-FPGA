// ==============================================================
// Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2024.2 (64-bit)
// Tool Version Limit: 2024.11
// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// 
// ==============================================================
#ifndef XAUDIO_CLEAN_UP_H
#define XAUDIO_CLEAN_UP_H

#ifdef __cplusplus
extern "C" {
#endif

/***************************** Include Files *********************************/
#ifndef __linux__
#include "xil_types.h"
#include "xil_assert.h"
#include "xstatus.h"
#include "xil_io.h"
#else
#include <stdint.h>
#include <assert.h>
#include <dirent.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stddef.h>
#endif
#include "xaudio_clean_up_hw.h"

/**************************** Type Definitions ******************************/
#ifdef __linux__
typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
#else
typedef struct {
#ifdef SDT
    char *Name;
#else
    u16 DeviceId;
#endif
    u64 Acu_BaseAddress;
} XAudio_clean_up_Config;
#endif

typedef struct {
    u64 Acu_BaseAddress;
    u32 IsReady;
} XAudio_clean_up;

typedef u32 word_type;

/***************** Macros (Inline Functions) Definitions *********************/
#ifndef __linux__
#define XAudio_clean_up_WriteReg(BaseAddress, RegOffset, Data) \
    Xil_Out32((BaseAddress) + (RegOffset), (u32)(Data))
#define XAudio_clean_up_ReadReg(BaseAddress, RegOffset) \
    Xil_In32((BaseAddress) + (RegOffset))
#else
#define XAudio_clean_up_WriteReg(BaseAddress, RegOffset, Data) \
    *(volatile u32*)((BaseAddress) + (RegOffset)) = (u32)(Data)
#define XAudio_clean_up_ReadReg(BaseAddress, RegOffset) \
    *(volatile u32*)((BaseAddress) + (RegOffset))

#define Xil_AssertVoid(expr)    assert(expr)
#define Xil_AssertNonvoid(expr) assert(expr)

#define XST_SUCCESS             0
#define XST_DEVICE_NOT_FOUND    2
#define XST_OPEN_DEVICE_FAILED  3
#define XIL_COMPONENT_IS_READY  1
#endif

/************************** Function Prototypes *****************************/
#ifndef __linux__
#ifdef SDT
int XAudio_clean_up_Initialize(XAudio_clean_up *InstancePtr, UINTPTR BaseAddress);
XAudio_clean_up_Config* XAudio_clean_up_LookupConfig(UINTPTR BaseAddress);
#else
int XAudio_clean_up_Initialize(XAudio_clean_up *InstancePtr, u16 DeviceId);
XAudio_clean_up_Config* XAudio_clean_up_LookupConfig(u16 DeviceId);
#endif
int XAudio_clean_up_CfgInitialize(XAudio_clean_up *InstancePtr, XAudio_clean_up_Config *ConfigPtr);
#else
int XAudio_clean_up_Initialize(XAudio_clean_up *InstancePtr, const char* InstanceName);
int XAudio_clean_up_Release(XAudio_clean_up *InstancePtr);
#endif

void XAudio_clean_up_Start(XAudio_clean_up *InstancePtr);
u32 XAudio_clean_up_IsDone(XAudio_clean_up *InstancePtr);
u32 XAudio_clean_up_IsIdle(XAudio_clean_up *InstancePtr);
u32 XAudio_clean_up_IsReady(XAudio_clean_up *InstancePtr);
void XAudio_clean_up_EnableAutoRestart(XAudio_clean_up *InstancePtr);
void XAudio_clean_up_DisableAutoRestart(XAudio_clean_up *InstancePtr);

void XAudio_clean_up_Set_dc_a_coef(XAudio_clean_up *InstancePtr, u32 Data);
u32 XAudio_clean_up_Get_dc_a_coef(XAudio_clean_up *InstancePtr);
void XAudio_clean_up_Set_dc_pass(XAudio_clean_up *InstancePtr, u32 Data);
u32 XAudio_clean_up_Get_dc_pass(XAudio_clean_up *InstancePtr);
void XAudio_clean_up_Set_th_open_amp(XAudio_clean_up *InstancePtr, u64 Data);
u64 XAudio_clean_up_Get_th_open_amp(XAudio_clean_up *InstancePtr);
void XAudio_clean_up_Set_th_close_amp(XAudio_clean_up *InstancePtr, u64 Data);
u64 XAudio_clean_up_Get_th_close_amp(XAudio_clean_up *InstancePtr);
void XAudio_clean_up_Set_a_attack(XAudio_clean_up *InstancePtr, u32 Data);
u32 XAudio_clean_up_Get_a_attack(XAudio_clean_up *InstancePtr);
void XAudio_clean_up_Set_a_release(XAudio_clean_up *InstancePtr, u32 Data);
u32 XAudio_clean_up_Get_a_release(XAudio_clean_up *InstancePtr);
void XAudio_clean_up_Set_b_attack(XAudio_clean_up *InstancePtr, u32 Data);
u32 XAudio_clean_up_Get_b_attack(XAudio_clean_up *InstancePtr);
void XAudio_clean_up_Set_b_release(XAudio_clean_up *InstancePtr, u32 Data);
u32 XAudio_clean_up_Get_b_release(XAudio_clean_up *InstancePtr);
void XAudio_clean_up_Set_ng_pass(XAudio_clean_up *InstancePtr, u32 Data);
u32 XAudio_clean_up_Get_ng_pass(XAudio_clean_up *InstancePtr);

void XAudio_clean_up_InterruptGlobalEnable(XAudio_clean_up *InstancePtr);
void XAudio_clean_up_InterruptGlobalDisable(XAudio_clean_up *InstancePtr);
void XAudio_clean_up_InterruptEnable(XAudio_clean_up *InstancePtr, u32 Mask);
void XAudio_clean_up_InterruptDisable(XAudio_clean_up *InstancePtr, u32 Mask);
void XAudio_clean_up_InterruptClear(XAudio_clean_up *InstancePtr, u32 Mask);
u32 XAudio_clean_up_InterruptGetEnabled(XAudio_clean_up *InstancePtr);
u32 XAudio_clean_up_InterruptGetStatus(XAudio_clean_up *InstancePtr);

#ifdef __cplusplus
}
#endif

#endif
