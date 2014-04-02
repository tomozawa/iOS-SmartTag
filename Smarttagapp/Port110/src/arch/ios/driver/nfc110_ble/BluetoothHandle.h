/**
 * \brief    the header file for device handle for NFC Port-110 BLE Driver (iOS)
 * \date     2013/08/26
 * \author   Copyright 2013 Sony Corporation
 */

#import <Foundation/Foundation.h>

#import "BluetoothDefines.h"

#ifndef BLUETOOTHHANDLE_H_
#define BLUETOOTHHANDLE_H_

@class CBPeripheral;
@class CBUUID;
@protocol BluetoothHandleDelegate;

/* --------------------------------
 * Class declaration
 * -------------------------------- */

@interface BluetoothHandle : NSObject

/*
 * Initialize methods
 */

- (id)initWithDelegate:(id<BluetoothHandleDelegate>)delegate;

/*
 * Bluetooth handle control methods
 */

- (void)setPeripheral:(CBPeripheral*)peripheral;
- (CBPeripheral*)getPeripheral;
- (UInt32)prepareServices:(CBUUID*)serviceUUID
             readChUUID:(CBUUID*)readChUUID
           notifyChUUID:(CBUUID*)notifyChUUID
            writeChUUID:(CBUUID*)writeChUUID;
- (UInt32)setNotifyValueToReadCharacteristic:(BOOL)enabled
                                     timeout:(dispatch_time_t)timeout;
- (UInt32)setNotifyValueToNotifyCharacteristic:(BOOL)enabled
                                       timeout:(dispatch_time_t)timeout;
- (void)registerNotifyCallback:(BLENotifyCallback)notifyCallback
                       content:(id)content;
- (UInt32)write:(NSData*)data timeout:(dispatch_time_t)timeout;
- (UInt32)read:(NSData* __autoreleasing*)data
        length:(UInt32)length
       timeout:(dispatch_time_t)timeout;
- (void)clearReceiveBuffer;
- (BOOL)isConnected;
- (BOOL)isEqualPeripheralUUID:(CFUUIDRef)uuid;

@end

/* --------------------------------
 * Protocol declaration
 * -------------------------------- */

@protocol BluetoothHandleDelegate <NSObject>

/**
 * This method returns the result of a prepareServices call.
 *
 * \param  bluetoothHandle        [IN] The handle providing this information.
 * \param  error                  [IN] If an error occurred, the cause of the
 *                                     failure.
 */
- (void)bluetoothHandle:(BluetoothHandle*)bluetoothHandle
     didPrepareServices:(NSError*)error;

@end

#endif /* !BLUETOOTHHANDLE_H_ */
