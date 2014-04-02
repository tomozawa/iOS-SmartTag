/**
 * \brief    the header file for NFC Port-110 BLE Driver private defines (iOS)
 * \date     2013/07/05
 * \author   Copyright 2013 Sony Corporation
 */

#ifndef BLUETOOTHINTERNAL_H_
#define BLUETOOTHINTERNAL_H_

/* --------------------------------
 * Constants
 * -------------------------------- */

#define BLE_MAX_DATA_LEN        27U
#define BLE_MAX_CONNECTION       8U  /* Bluetooth.m implementation is only
                                      * tested for 1 connection.
                                      */
#define BLE_MAX_UUID_LIST       BLE_MAX_CONNECTION

#define BLE_INIT_DEFAULT_TIMEOUT            10000U
#define BLE_READCH_UPDATE_DEFAULT_TIMEOUT   120000U
#define BLE_NOTIFYCH_UPDATE_DEFAULT_TIMEOUT 10000U

#define BLE_INVALID_RSSI                    0x00000000

/* --------------------------------
 * Macros
 * -------------------------------- */

#define GLOBAL_QUEUE \
    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)

#define CMP_UUID(uuid1, uuid2) \
    ((uuid1.byte0 == uuid2.byte0) && \
     (uuid1.byte1 == uuid2.byte1) && \
     (uuid1.byte2 == uuid2.byte2) && \
     (uuid1.byte3 == uuid2.byte3) && \
     (uuid1.byte4 == uuid2.byte4) && \
     (uuid1.byte5 == uuid2.byte5) && \
     (uuid1.byte6 == uuid2.byte6) && \
     (uuid1.byte7 == uuid2.byte7) && \
     (uuid1.byte8 == uuid2.byte8) && \
     (uuid1.byte9 == uuid2.byte9) && \
     (uuid1.byte10 == uuid2.byte10) && \
     (uuid1.byte11 == uuid2.byte11) && \
     (uuid1.byte12 == uuid2.byte12) && \
     (uuid1.byte13 == uuid2.byte13) && \
     (uuid1.byte14 == uuid2.byte14) && \
     (uuid1.byte15 == uuid2.byte15))

#endif /* !BLUETOOTHINTERNAL_H_ */
