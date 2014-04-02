/**
 * \brief    a header file for the NFC Port-110 BLE module
 * \date     2013/08/26
 * \author   Copyright 2013 Sony Corporation
 */

#include "ics_types.h"
#include "ics_hwdev.h"
#include "icsdrv.h"
#include "nfc110.h"

#ifndef NFC110_BLE_H_
#define NFC110_BLE_H_

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Prototype declaration
 */

/* driver functions */
UINT32 nfc110_ble_open(
    ICS_HW_DEVICE* nfc110,
    const char* port_name);

#define nfc110_ble_close                        nfc110_close
#define nfc110_ble_initialize_device            nfc110_initialize_device
#define nfc110_ble_get_firmware_version         nfc110_get_firmware_version
#define nfc110_ble_ping                         nfc110_ping
#define nfc110_ble_reset                        nfc110_reset
#define nfc110_ble_execute_command              nfc110_execute_command
#define nfc110_ble_rf_command                   nfc110_rf_command
#define nfc110_ble_send_ack                     nfc110_send_ack
#define nfc110_ble_cancel_command               nfc110_cancel_command
#define nfc110_ble_felica_command               nfc110_felica_command
#define nfc110_ble_rf_off                       nfc110_rf_off
#define nfc110_ble_rf_on                        nfc110_rf_on
#define nfc110_ble_get_protocol                 nfc110_get_protocol
#define nfc110_ble_set_protocol                 nfc110_set_protocol
#define nfc110_ble_set_rf_speed                 nfc110_set_rf_speed
#define nfc110_ble_claer_rx_queue               nfc110_clear_rx_queue
#define nfc110_ble_get_ack_time                 nfc110_get_ack_time
#define nfc110_ble_get_version_information      nfc110_get_version_information
#define nfc110_ble_get_battery_information      nfc110_get_battery_information
#define nfc110_ble_set_alarm                    nfc110_set_alarm
#define nfc110_ble_get_alarm                    nfc110_get_alarm
#define nfc110_ble_get_ble_peripheral_parameter \
    nfc110_get_ble_peripheral_parameter
#define nfc110_ble_set_ble_peripheral_parameter \
    nfc110_set_ble_peripheral_parameter
#define nfc110_ble_get_attribute                nfc110_get_attribute
#define nfc110_ble_register_notify_callback     nfc110_register_notify_callback

static const icsdrv_basic_func_t nfc110_ble_basic_func = {
    "nfc110_ble",
    nfc110_ble_open,
    nfc110_close,
    nfc110_initialize_device,
    nfc110_ping,
    nfc110_reset,
    nfc110_execute_command,
    nfc110_cancel_command,
    nfc110_felica_command,
    NFC110_MAX_FELICA_COMMAND_LEN,
    NFC110_MAX_FELICA_RESPONSE_LEN,
    nfc110_rf_off,
    nfc110_rf_on,
    NULL, /* set dev speed */
    NULL, /* set speed */
    0,
    NULL,
};

/* raw functions */
UINT32 nfc110_ble_raw_open(
    ICS_HANDLE* nfc110,
    const char* port_name);
UINT32 nfc110_ble_raw_close(
    ICS_HANDLE handle);
UINT32 nfc110_ble_raw_write(
    ICS_HANDLE handle,
    const UINT8* data,
    UINT32 data_len,
    UINT32 time0,
    UINT32 timeout);
UINT32 nfc110_ble_raw_read(
    ICS_HANDLE handle,
    UINT32 min_read_len,
    UINT32 max_read_len,
    UINT8* data,
    UINT32* read_len,
    UINT32 time0,
    UINT32 timeout);
UINT32 nfc110_ble_raw_clear_rx_queue(
    ICS_HANDLE handle);
UINT32 nfc110_ble_raw_drain_tx_queue(
    ICS_HANDLE handle);
UINT32 nfc110_ble_raw_reset(
    ICS_HANDLE handle);
UINT32 nfc110_ble_raw_register_notify_callback(
    ICS_HANDLE handle,
    nfc110_notify_callback callback);
UINT32 nfc110_ble_raw_register_notify_callback2(
    ICS_HANDLE handle,
    nfc110_notify_callback2_func_t callback,
    void* obj);
UINT32 nfc110_ble_raw_register_change_conn_status_callback(
    nfc110_on_change_conn_status callback);
UINT32 nfc110_ble_raw_register_change_conn_status_callback2(
    nfc110_on_change_conn_status2_func_t callback,
    void* obj);
UINT32 nfc110_ble_raw_set_cb_parameter(
    UINT32 cm_init_timeout,
    INT32 rssi,
    UINT32 readch_timeout,
    UINT32 notifych_timeout);
UINT32 nfc110_ble_raw_get_attribute(
    ICS_HANDLE handle,
    void* arg);

static const nfc110_raw_ext_func_t nfc110_raw_ext_func = {
    nfc110_ble_raw_get_attribute,
    nfc110_ble_raw_register_notify_callback,
    nfc110_ble_raw_register_notify_callback2,
    NULL,
};

static const icsdrv_raw_func_t nfc110_ble_raw_func = {
    "nfc110_ble",
    nfc110_ble_raw_open,
    nfc110_ble_raw_close,
    nfc110_ble_raw_write,
    nfc110_ble_raw_read,
    NULL,
    nfc110_ble_raw_clear_rx_queue,
    nfc110_ble_raw_drain_tx_queue,
    0,
    (void*)&nfc110_raw_ext_func,
};

#ifdef __cplusplus
}
#endif

#endif /* !NFC110_BLE_H_ */
