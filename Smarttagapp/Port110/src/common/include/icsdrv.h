/**
 * \brief    the common header file for drivers
 * \date     2008/10/14
 * \author   Copyright 2005,2006,2007,2008 Sony Corporation
 */

#include "ics_types.h"
#include "ics_hwdev.h"

#ifndef ICSDRV_H_
#define ICSDRV_H_

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Type and structure
 */

/* basic driver */

typedef UINT32 (*icsdrv_open_func_t)(
    ICS_HW_DEVICE* dev,
    const char* port_name);
typedef UINT32 (*icsdrv_close_func_t)(
    ICS_HW_DEVICE* dev);

typedef UINT32 (*icsdrv_initialize_device_func_t)(
    ICS_HW_DEVICE* dev,
    UINT32 timeout);
typedef UINT32 (*icsdrv_ping_func_t)(
    ICS_HW_DEVICE* dev,
    UINT32 timeout);
typedef UINT32 (*icsdrv_reset_func_t)(
    ICS_HW_DEVICE* dev,
    UINT32 timeout);

typedef UINT32 (*icsdrv_execute_command_func_t)(
    ICS_HW_DEVICE* dev,
    const UINT8* command,
    UINT32 command_len,
    UINT32 max_response_len,
    UINT8* response,
    UINT32* response_len,
    UINT32 timeout);
typedef UINT32 (*icsdrv_cancel_command_func_t)(
    ICS_HW_DEVICE* dev);

typedef UINT32 (*icsdrv_felica_command_func_t)(
    ICS_HW_DEVICE* dev,
    const UINT8* command,
    UINT32 command_len,
    UINT32 max_response_len,
    UINT8* response,
    UINT32* response_len,
    UINT32 command_timeout,
    UINT32 timeout);
typedef UINT32 (*icsdrv_rf_off_func_t)(
    ICS_HW_DEVICE* dev,
    UINT32 timeout);
typedef UINT32 (*icsdrv_rf_on_func_t)(
    ICS_HW_DEVICE* dev,
    UINT32 timeout);

typedef UINT32 (*icsdrv_set_dev_speed_func_t)(
    ICS_HW_DEVICE* dev,
    UINT32 speed,
    UINT32 timeout);

typedef UINT32 (*icsdrv_set_speed_func_t)(
    ICS_HW_DEVICE* dev,
    UINT32 speed);

typedef struct icsdrv_basic_func_t {
    const char*                      dev_name;
    icsdrv_open_func_t               open;
    icsdrv_close_func_t              close;
    icsdrv_initialize_device_func_t  initialize_device;
    icsdrv_ping_func_t               ping;
    icsdrv_reset_func_t              reset;
    icsdrv_execute_command_func_t    execute_command;
    icsdrv_cancel_command_func_t     cancel_command;
    icsdrv_felica_command_func_t     felica_command;
    UINT32                           max_felica_command_len;
    UINT32                           max_felica_response_len;
    icsdrv_rf_off_func_t             rf_off;
    icsdrv_rf_on_func_t              rf_on;
    icsdrv_set_dev_speed_func_t      set_dev_speed;
    icsdrv_set_speed_func_t          set_speed;
    UINT32                           attr;
    void*                            ext;
} icsdrv_basic_func_t;

/* raw driver */

typedef UINT32 (*icsdrv_raw_open_func_t)(
    ICS_HANDLE* handle,
    const char* port_name);
typedef UINT32 (*icsdrv_raw_close_func_t)(
    ICS_HANDLE dev);
typedef UINT32 (*icsdrv_raw_write_func_t)(
    ICS_HANDLE handle,
    const UINT8* data,
    UINT32 data_len,
    UINT32 time0,
    UINT32 timeout);
typedef UINT32 (*icsdrv_raw_read_func_t)(
    ICS_HANDLE handle,
    UINT32 min_read_len,
    UINT32 max_read_len,
    UINT8* data,
    UINT32* read_len,
    UINT32 time0,
    UINT32 timeout);
typedef UINT32 (*icsdrv_raw_set_speed_func_t)(
    ICS_HANDLE handle,
    UINT32 speed);
typedef UINT32 (*icsdrv_raw_clear_rx_queue_func_t)(
    ICS_HANDLE handle);
typedef UINT32 (*icsdrv_raw_drain_tx_queue_func_t)(
    ICS_HANDLE handle);

typedef struct icsdrv_raw_func_t {
    const char*                      dev_name;
    icsdrv_raw_open_func_t           open;
    icsdrv_raw_close_func_t          close;
    icsdrv_raw_write_func_t          write;
    icsdrv_raw_read_func_t           read;
    icsdrv_raw_set_speed_func_t      set_speed;
    icsdrv_raw_clear_rx_queue_func_t clear_rx_queue;
    icsdrv_raw_drain_tx_queue_func_t drain_tx_queue;
    UINT32                           attr;
    void*                            ext;
} icsdrv_raw_func_t;

#ifdef __cplusplus
}
#endif

#endif /* !ICSDRV_H_ */
