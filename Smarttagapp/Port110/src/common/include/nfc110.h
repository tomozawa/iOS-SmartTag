/**
 * \brief    a header file for the NFC Port-110 module
 * \date     2013/11/28
 * \author   Copyright 2013 Sony Corporation
 */

#include "ics_types.h"
#include "ics_hwdev.h"
#include "icsdrv.h"

#include "nfc110_internal.h"

#ifndef NFC110_H_
#define NFC110_H_

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Constant
 */

#define NFC110_BLE_SPEED                        400

#ifndef NFC110_MAX_TRANSMIT_DATA_LEN
#define NFC110_MAX_TRANSMIT_DATA_LEN            1000
#endif
#ifndef NFC110_MAX_RECEIVE_DATA_LEN
#define NFC110_MAX_RECEIVE_DATA_LEN             NFC110_MAX_TRANSMIT_DATA_LEN
#endif

#define NFC110_MAX_FELICA_COMMAND_LEN           254
#define NFC110_MAX_FELICA_RESPONSE_LEN          254

#define NFC110_MAX_IN_SET_PROTOCOL_SETTING_NUM  19
#define NFC110_MAX_TG_SET_PROTOCOL_SETTING_NUM  3

#define NFC110_COMMAND_CODE                     0xd6
#define NFC110_RESPONSE_CODE                    0xd7

/* RF communication */
#define NFC110_CMD_IN_SET_RF                    0x00
#define NFC110_RES_IN_SET_RF                    0x01
#define NFC110_CMD_IN_SET_PROTOCOL              0x02
#define NFC110_RES_IN_SET_PROTOCOL              0x03
#define NFC110_CMD_IN_COMM_RF                   0x04
#define NFC110_RES_IN_COMM_RF                   0x05
#define NFC110_CMD_SWITCH_RF                    0x06
#define NFC110_RES_SWITCH_RF                    0x07
#define NFC110_CMD_TG_SET_RF                    0x40
#define NFC110_RES_TG_SET_RF                    0x41
#define NFC110_CMD_TG_SET_PROTOCOL              0x42
#define NFC110_RES_TG_SET_PROTOCOL              0x43
#define NFC110_CMD_TG_SET_AUTO                  0x44
#define NFC110_RES_TG_SET_AUTO                  0x45
#define NFC110_CMD_TG_SET_RF_OFF                0x46
#define NFC110_RES_TG_SET_RF_OFF                0x47
#define NFC110_CMD_TG_COMM_RF                   0x48
#define NFC110_RES_TG_COMM_RF                   0x49

/* Device maintenance */
#define NFC110_CMD_RESET_DEVICE                 0x12
#define NFC110_RES_RESET_DEVICE                 0x13

/* Get/Set the device attribute */
#define NFC110_CMD_SWITCH_RF_AUTO               0x08
#define NFC110_RES_SWITCH_RF_AUTO               0x09
#define NFC110_CMD_SET_ALARM                    0x14
#define NFC110_RES_SET_ALARM                    0x15
#define NFC110_CMD_SET_BLE_PARAMETER            0x1c
#define NFC110_RES_SET_BLE_PARAMETER            0x1d
#define NFC110_CMD_GET_FIRMWARE_VERSION         0x20
#define NFC110_RES_GET_FIRMWARE_VERSION         0x21
#define NFC110_CMD_GET_PD_DATA_VERSION          0x22
#define NFC110_RES_GET_PD_DATA_VERSION          0x23
#define NFC110_CMD_GET_PROPERTY                 0x24
#define NFC110_RES_GET_PROPERTY                 0x25
#define NFC110_CMD_IN_GET_PROTOCOL              0x26
#define NFC110_RES_IN_GET_PROTOCOL              0x27
#define NFC110_CMD_GET_COMMAND_TYPE             0x28
#define NFC110_RES_GET_COMMAND_TYPE             0x29
#define NFC110_CMD_SET_COMMAND_TYPE             0x2a
#define NFC110_RES_SET_COMMAND_TYPE             0x2b
#define NFC110_CMD_GET_ALARM                    0x3a
#define NFC110_RES_GET_ALARM                    0x3b
#define NFC110_CMD_TG_GET_PROTOCOL              0x50
#define NFC110_RES_TG_GET_PROTOCOL              0x51
#define NFC110_CMD_GET_BLE_PARAMETER            0x52
#define NFC110_RES_GET_BLE_PARAMETER            0x53

/* Product design */
#define NFC110_CMD_GET_PD_DATA                  0x34
#define NFC110_RES_GET_PD_DATA                  0x35
#define NFC110_CMD_READ_REGISTER                0x36
#define NFC110_RES_READ_REGISTER                0x37

/* Diagnose */
#define NFC110_CMD_DIAGNOSE                     0xf0
#define NFC110_RES_DIAGNOSE                     0xf1

/* Diagnose TestNum parameter */
#define NFC110_TESTNUM_POWERSTATUS              0x0a

/* GetFirmwareVersion option */
#define NFC110_GETFWOPT_BLE_VERSION             0x70

/* The status code of NFC Port-100 command (except InCommRF/TgCommRF) */
#define NFC110_DEV_STATUS_SUCCESS               0x00
#define NFC110_DEV_STATUS_PARAMETER_ERROR       0x01
#define NFC110_DEV_STATUS_PB_ERROR              0x02
#define NFC110_DEV_STATUS_RFCA_ERROR            0x03
#define NFC110_DEV_STATUS_TEMPERATURE_ERROR     0x04
#define NFC110_DEV_STATUS_PWD_ERROR             0x05
#define NFC110_DEV_STATUS_RECEIVE_ERROR         0x06
#define NFC110_DEV_STATUS_COMMANDTYPE_ERROR     0x07
#define NFC110_DEV_STATUS_INTTEMPRFOFF_ERROR    0x09

/* The status code of InCommRF/TgCommRF command */
#define NFC110_RF_STATUS_SUCCESS                0x00000000
#define NFC110_RF_STATUS_PROTOCOL_ERROR         0x00000001
#define NFC110_RF_STATUS_PARITY_ERROR           0x00000002
#define NFC110_RF_STATUS_CRC_ERROR              0x00000004
#define NFC110_RF_STATUS_COLLISION_ERROR        0x00000008
#define NFC110_RF_STATUS_OVERFLOW_ERROR         0x00000010
#define NFC110_RF_STATUS_TEMPERATURE_ERROR      0x00000040
#define NFC110_RF_STATUS_REC_TIMEOUT_ERROR      0x00000080
#define NFC110_RF_STATUS_CRYPTO1_ERROR          0x00000100
#define NFC110_RF_STATUS_RFCA_ERROR             0x00000200
#define NFC110_RF_STATUS_RF_OFF                 0x00000400
#define NFC110_RF_STATUS_TRA_TIMEOUT_ERROR      0x00000800
#define NFC110_RF_STATUS_INTTEMPRFOFF_ERROR     0x00001000
#define NFC110_RF_STATUS_RECEIVELENGTH_ERROR    0x80000000

/* InSetRF parameter */
#define NFC110_RF_INITIATOR_ISO18092_212K       0x01
#define NFC110_RF_INITIATOR_ISO18092_424K       0x02
#define NFC110_RF_INITIATOR_ISO18092_106K       0x03
#define NFC110_RF_INITIATOR_ISO14443A_106K      0x03
#define NFC110_RF_INITIATOR_ISO14443A_212K      0x04
#define NFC110_RF_INITIATOR_ISO14443A_424K      0x05
#define NFC110_RF_INITIATOR_ISO14443A_848K      0x06
#define NFC110_RF_INITIATOR_ISO14443B_106K      0x07
#define NFC110_RF_INITIATOR_ISO14443B_212K      0x08
#define NFC110_RF_INITIATOR_ISO14443B_424K      0x09
#define NFC110_RF_INITIATOR_ISO14443B_848K      0x0a
#define NFC110_RF_TARGET_ISO18092_106K          0x0b
#define NFC110_RF_TARGET_ISO14443A_106K         0x0b
#define NFC110_RF_TARGET_ISO18092_212K          0x0c
#define NFC110_RF_TARGET_ISO18092_424K          0x0d
#define NFC110_RF_TARGET_ISO14443A_212K         0x0e
#define NFC110_RF_TARGET_ISO14443A_424K         0x0f
#define NFC110_RF_TARGET_ISO14443A_848K         0x10

/* Reader / Writer mode */
#define NFC110_MODE_INITIATOR                   0x00
#define NFC110_MODE_TARGET                      0x08
#define NFC110_MODE_TYPEF                       0x03
#define NFC110_MODE_INITIATOR_TYPEF \
    (NFC110_MODE_INITIATOR | NFC110_MODE_TYPEF)
#define NFC110_MODE_TARGET_TYPEF \
    (NFC110_MODE_TARGET | NFC110_MODE_TYPEF)

static const UINT8 nfc110_felica_default_protocol[] = {
    0x00, 0x15, /* Initial guard time = 21 (20.4) */
    0x01, 0x01, /* Add CRC = 1 */
    0x02, 0x01, /* Check CRC = 1 */
    0x03, 0x00, /* Multi card = 0 */
    0x04, 0x00, /* Add parity = 0 */
    0x05, 0x00, /* Check parity = 0 */
    0x06, 0x00, /* Bitwise anticollision receiving mode = 0 */
    0x07, 0x08, /* Valid bit number for last transmit byte = 8 */
    0x08, 0x00, /* Crypto1 = 0 */
    0x09, 0x00, /* Add SOF = 0 */
    0x0a, 0x00, /* Check SOF = 0 */
    0x0b, 0x00, /* Add EOF = 0 */
    0x0c, 0x00, /* Check EOF = 0 */
    0x0e, 0x04, /* Deaf time = 4 */
    0x0f, 0x00, /* Continuous receiving mode = 0 */
    0x10, 0x00, /* Min len for CRM = 0 */
    0x11, 0x00, /* Type 1 Tag frame = 0 */
    0x12, 0x00, /* RFCA = 0 */
    0x13, 0x06, /* Guard time at initiator = 6 */
};

/* NFC110 connection status */
#define NFC110_CONN_STATUS_DISCONNECTION    1U
#define NFC110_CONN_STATUS_CONNECTION       2U

/*
 * Macro
 */

#define NFC110_SPEED(nfc110) \
    ((UINT32)(((nfc110)->status) & 0xff) * 9600)
#define NFC110_SET_SPEED(nfc110, speed) \
    do { \
        (nfc110)->status = (((nfc110)->status & 0xffffff00) | \
                            (((speed) / 9600) & 0xff)); \
    } while (0)
#define NFC110_IS_VALID_SPEED(speed) \
    (((speed) == NFC110_BLE_SPEED) || (((speed) % 9600) == 0))
#define NFC110_LAST_MODE(nfc110) \
    (((nfc110)->status >> 8) & 0x0f)
#define NFC110_SET_LAST_MODE(nfc110, mode) \
    do { \
        (nfc110)->status = (((nfc110)->status & 0xfffff0ff) | \
                            (((UINT32)(mode) & 0x0f) << 8)); \
    } while (0)
#define NFC110_TX_RBT(nfc110) \
    (((nfc110)->status >> 12) & 0x1f)
#define NFC110_SET_TX_RBT(nfc110, rbt) \
    do { \
        (nfc110)->status = (((nfc110)->status & 0xfffe0fff) | \
                            (((UINT32)(rbt) & 0x1f) << 12)); \
    } while (0)
#define NFC110_TX_SPEED(nfc110) \
    (((nfc110)->status >> 17) & 0x1f)
#define NFC110_SET_TX_SPEED(nfc110, speed) \
    do { \
        (nfc110)->status = (((nfc110)->status & 0xffc1ffff) | \
                            (((UINT32)(speed) & 0x1f) << 17)); \
    } while (0)
#define NFC110_RX_RBT(nfc110) \
    (((nfc110)->status >> 22) & 0x1f)
#define NFC110_SET_RX_RBT(nfc110, rbt) \
    do { \
        (nfc110)->status = (((nfc110)->status & 0xf83fffff) | \
                            (((UINT32)(rbt) & 0x1f) << 22)); \
    } while (0)
#define NFC110_RX_SPEED(nfc110) \
    (((nfc110)->status >> 27) & 0x1f)
#define NFC110_SET_RX_SPEED(nfc110, speed) \
    do { \
        (nfc110)->status = (((nfc110)->status & 0x07ffffff) | \
                            (((UINT32)(speed) & 0x1f) << 27)); \
    } while (0)

/*
 * Callback function declaration
 */

typedef void (*nfc110_notify_callback)(
    UINT32 result,
    UINT8 category,
    void *arg);
   
typedef void (*nfc110_notify_callback2_func_t)(
    void* obj,
    UINT32 result,
    UINT8 category,
    void *arg);

typedef void (*nfc110_on_change_conn_status)(
    UINT16 cause,
    ICS_HANDLE handle,
    void* arg);

typedef void (*nfc110_on_change_conn_status2_func_t)(
    void* obj,
    UINT16 cause,
    ICS_HANDLE handle,
    void* arg);
    
/*
 * Prototype declaration
 */

UINT32 nfc110_initialize(
    ICS_HW_DEVICE* nfc110,
    const icsdrv_raw_func_t* raw_func);

/* open */
UINT32 nfc110_open(
    ICS_HW_DEVICE* nfc110,
    const char* port_name);

/* close */
UINT32 nfc110_close(
    ICS_HW_DEVICE* nfc110);

/* initialize the device */
UINT32 nfc110_initialize_device(
    ICS_HW_DEVICE* nfc110,
    UINT32 timeout);

/* check the device is alive */
UINT32 nfc110_ping(
    ICS_HW_DEVICE* nfc110,
    UINT32 timeout);

/* reset the driver */
UINT32 nfc110_reset(
    ICS_HW_DEVICE* nfc110,
    UINT32 timeout);

/* send a command to the device and receives response */
UINT32 nfc110_execute_command(
    ICS_HW_DEVICE* nfc110,
    const UINT8* command,
    UINT32 command_len,
    UINT32 max_response_len,
    UINT8* response,
    UINT32* response_len,
    UINT32 timeout);

/* send a command to RF front-end and receives response */
UINT32 nfc110_rf_command(
    ICS_HW_DEVICE* nfc110,
    const UINT8* command,
    UINT32 command_len,
    UINT32 max_response_len,
    UINT8* response,
    UINT32* response_len,
    UINT32* rf_status,
    UINT8* valid_bit,
    BOOL need_len,
    UINT32 command_timeout,
    UINT32 timeout);

/* send the FeliCa command and receive a FeliCa response */
UINT32 nfc110_felica_command(
    ICS_HW_DEVICE* nfc110,
    const UINT8* command,
    UINT32 command_len,
    UINT32 max_response_len,
    UINT8* response,
    UINT32* response_len,
    UINT32 command_timeout,
    UINT32 timeout);

/* cancel the previous command */
UINT32 nfc110_cancel_command(
    ICS_HW_DEVICE* nfc110);

/* turn RF off */
UINT32 nfc110_rf_off(
    ICS_HW_DEVICE* nfc110,
    UINT32 timeout);

/* turn RF on */
UINT32 nfc110_rf_on(
    ICS_HW_DEVICE* nfc110,
    UINT32 timeout);

/* get firmware version */
UINT32 nfc110_get_firmware_version(
    ICS_HW_DEVICE* nfc110,
    UINT16* version,
    UINT32 timeout);

/* send an ACK to the device */
UINT32 nfc110_send_ack(
    ICS_HW_DEVICE* nfc110,
    UINT32 timeout);

/* set the rf communication speed of the device */
UINT32 nfc110_set_rf_speed(
    ICS_HW_DEVICE* nfc110,
    UINT8 tx_rbt,
    UINT8 tx_speed,
    UINT8 rx_rbt,
    UINT8 rx_speed,
    UINT32 timeout);

/* set the rf protocol setting data of the device */
UINT32 nfc110_set_protocol(
    ICS_HW_DEVICE* nfc110,
    const UINT8* setting,
    UINT32 setting_len,
    UINT32 timeout);

/* get the rf protocol setting data of the device */
UINT32 nfc110_get_protocol(
    ICS_HW_DEVICE* nfc110,
    const  UINT8* setting_num,
    UINT32 setting_num_len,
    UINT8* setting,
    UINT32* setting_len,
    UINT32 timeout);

/* clear the receiving queue */
UINT32 nfc110_clear_rx_queue(
    ICS_HW_DEVICE* nfc110);

/* return the time when this driver received the last ACK */
UINT32 nfc110_get_ack_time(
    ICS_HW_DEVICE* nfc110,
    UINT32* ack_time);

/* get version information */
UINT32 nfc110_get_version_information(
    ICS_HW_DEVICE* nfc110,
    UINT16* fw_version,
    UINT16* ble_version,
    UINT32 timeout);

/* get the power status of the device */
UINT32 nfc110_get_battery_information(
    ICS_HW_DEVICE* nfc110,
    UINT8* power_state,
    UINT32 timeout);

/* set the time interval for the alarm notification of the device */
UINT32 nfc110_set_alarm(
    ICS_HW_DEVICE* nfc110,
    UINT16 count,
    UINT32 timeout);

/* get the alarm setting of the device */
UINT32 nfc110_get_alarm(
    ICS_HW_DEVICE* nfc110,
    UINT16* rest_count,
    UINT16* count,
    UINT32 timeout);

/* get the ble connection parameter of the device */
UINT32 nfc110_get_ble_peripheral_parameter(
    ICS_HW_DEVICE* nfc110,
    UINT16* connection_interval,
    UINT16* slave_latency,
    UINT16* connection_timeout,
    UINT32 timeout);

/* set the ble connection parameter of the device */
UINT32 nfc110_set_ble_peripheral_parameter(
    ICS_HW_DEVICE* nfc110,
    UINT16 interval_min,
    UINT16 interval_max,
    UINT16 slave_latency,
    UINT16 timeout_multiplier,
    UINT32 timeout);

/* get a information of the device */
UINT32 nfc110_get_attribute(
    ICS_HW_DEVICE* nfc110,
    void* arg);

/* callback function for a notification from the device */
UINT32 nfc110_register_notify_callback(
    ICS_HW_DEVICE* nfc110,
    nfc110_notify_callback callback);

/* callback function for a notification from the device */
UINT32 nfc110_register_notify_callback2(
    ICS_HW_DEVICE* nfc110,
    nfc110_notify_callback2_func_t callback,
    void* obj);

/* reset the device */
UINT32 nfc110_reset_device(
    ICS_HW_DEVICE* nfc110,
    UINT16 delay_time,
    UINT8 option,
    UINT32 timeout);

/* ext driver */

typedef UINT32 (*nfc110_raw_get_attribute_func_t)(
    ICS_HANDLE handle,
    void* arg);

typedef UINT32 (*nfc110_raw_register_notify_callback_func_t)(
    ICS_HANDLE handle,
    nfc110_notify_callback callback);

typedef UINT32 (*nfc110_raw_register_notify_callback2_func_t)(
    ICS_HANDLE handle,
    nfc110_notify_callback2_func_t callback,
    void* obj);

typedef struct nfc110_raw_ext_func_t {
    nfc110_raw_get_attribute_func_t              get_attribute;
    nfc110_raw_register_notify_callback_func_t   register_notify_callback;
    nfc110_raw_register_notify_callback2_func_t  register_notify_callback2;
    void*                                        ext;
} nfc110_raw_ext_func_t;

#ifdef __cplusplus
}
#endif

#endif /* !NFC110_H_ */
