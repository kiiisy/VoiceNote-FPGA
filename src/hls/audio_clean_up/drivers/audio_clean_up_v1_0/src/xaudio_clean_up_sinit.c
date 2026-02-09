// ==============================================================
// Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2024.2 (64-bit)
// Tool Version Limit: 2024.11
// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// 
// ==============================================================
#ifndef __linux__

#include "xstatus.h"
#ifdef SDT
#include "xparameters.h"
#endif
#include "xaudio_clean_up.h"

extern XAudio_clean_up_Config XAudio_clean_up_ConfigTable[];

#ifdef SDT
XAudio_clean_up_Config *XAudio_clean_up_LookupConfig(UINTPTR BaseAddress) {
	XAudio_clean_up_Config *ConfigPtr = NULL;

	int Index;

	for (Index = (u32)0x0; XAudio_clean_up_ConfigTable[Index].Name != NULL; Index++) {
		if (!BaseAddress || XAudio_clean_up_ConfigTable[Index].Acu_BaseAddress == BaseAddress) {
			ConfigPtr = &XAudio_clean_up_ConfigTable[Index];
			break;
		}
	}

	return ConfigPtr;
}

int XAudio_clean_up_Initialize(XAudio_clean_up *InstancePtr, UINTPTR BaseAddress) {
	XAudio_clean_up_Config *ConfigPtr;

	Xil_AssertNonvoid(InstancePtr != NULL);

	ConfigPtr = XAudio_clean_up_LookupConfig(BaseAddress);
	if (ConfigPtr == NULL) {
		InstancePtr->IsReady = 0;
		return (XST_DEVICE_NOT_FOUND);
	}

	return XAudio_clean_up_CfgInitialize(InstancePtr, ConfigPtr);
}
#else
XAudio_clean_up_Config *XAudio_clean_up_LookupConfig(u16 DeviceId) {
	XAudio_clean_up_Config *ConfigPtr = NULL;

	int Index;

	for (Index = 0; Index < XPAR_XAUDIO_CLEAN_UP_NUM_INSTANCES; Index++) {
		if (XAudio_clean_up_ConfigTable[Index].DeviceId == DeviceId) {
			ConfigPtr = &XAudio_clean_up_ConfigTable[Index];
			break;
		}
	}

	return ConfigPtr;
}

int XAudio_clean_up_Initialize(XAudio_clean_up *InstancePtr, u16 DeviceId) {
	XAudio_clean_up_Config *ConfigPtr;

	Xil_AssertNonvoid(InstancePtr != NULL);

	ConfigPtr = XAudio_clean_up_LookupConfig(DeviceId);
	if (ConfigPtr == NULL) {
		InstancePtr->IsReady = 0;
		return (XST_DEVICE_NOT_FOUND);
	}

	return XAudio_clean_up_CfgInitialize(InstancePtr, ConfigPtr);
}
#endif

#endif

