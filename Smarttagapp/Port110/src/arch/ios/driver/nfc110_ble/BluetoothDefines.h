/**
 * \brief    the header file for NFC Port-110 BLE Driver public defines (iOS)
 * \date     2013/08/26
 * \author   Copyright 2013 Sony Corporation
 */

#ifndef BLUETOOTHDEFINES_H_
#define BLUETOOTHDEFINES_H_

/* --------------------------------
 * Constants
 * -------------------------------- */

typedef NS_ENUM(NSInteger, BLEConnectionState) {
    BLEConnectionStateUnknown = 0,
    BLEConnectionStateConnected,
    BLEConnectionStateDisconnected,
};

/* --------------------------------
 * Callbacks
 * -------------------------------- */

typedef void (*BLENotifyCallback)(
    NSData* data,
    id content);

typedef void (*BLEConnectionStateCallback)(
    BLEConnectionState state,
    void* handle,
    id content);

#endif /* !BLUETOOTHDEFINES_H_ */
