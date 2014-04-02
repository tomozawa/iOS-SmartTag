/*
 * Copyright 2006,2007,2008,2011 Sony Corporation
 */

#include <nfc110_ble.h>
#include <felica_cc.h>
#include <stub/felica_cc_stub_nfc110.h>

const icsdrv_basic_func_t* g_drv_func = &nfc110_ble_basic_func;

UINT32 (*g_felica_cc_stub_initialize_func)(
    felica_cc_devf_t* devf,
    ICS_HW_DEVICE* dev) = felica_cc_stub_nfc110_initialize;
