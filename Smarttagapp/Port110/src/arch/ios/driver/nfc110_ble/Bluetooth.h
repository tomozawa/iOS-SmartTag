/**
 * \brief    the header file for NFC Port-110 BLE Driver (iOS)
 * \date     2013/08/26
 * \author   Copyright 2013 Sony Corporation
 */

#import <Foundation/Foundation.h>

#import "BluetoothDefines.h"

#ifndef BLUETOOTH_H_
#define BLUETOOTH_H_

/* --------------------------------
 * Class declaration
 * -------------------------------- */

@interface Bluetooth: NSObject

/*
 * Initialize methods
 */

- (id)init;

/*
 * I/O control methods
 */

- (void*)open:(NSString*)uuid;
- (UInt32)close:(void*)handle;
- (UInt32)reset:(void*)handle;
- (NSInteger)write:(void*)handle
           command:(NSData*)command
      timeoutMsecs:(UInt32)timeoutMsecs;
- (NSInteger)read:(void*)handle
         response:(NSData* __autoreleasing*)response
           length:(UInt32)length
     timeoutMsecs:(UInt32)timeoutMsecs;
- (UInt32)clearReceiveBuffer:(void*)handle;
- (UInt32)registerNotifyCallback:(void*)handle
                  notifyCallback:(BLENotifyCallback)notifyCallback
                         content:(id)content;
- (UInt32)registerConnectionStateCallback:(BLEConnectionStateCallback)callback
                                  content:(id)content;

/*
 * Attribute methods
 */

- (UInt32)getPeripheralUUID:(void*)handle
                       uuid:(NSString* __autoreleasing*)uuid;

/*
 * Properties declaration
 */

@property (readonly, nonatomic) UInt32 errcode;
@property (nonatomic) UInt32 initTimeout;
@property (nonatomic) UInt32 readChTimeout;
@property (nonatomic) UInt32 notifyChTimeout;
@property (nonatomic) SInt32 RSSIMinForDiscoverPeripheral;
@property (nonatomic) BOOL connectOptionEnable;

@end

#endif /* !BLUETOOTH_H_ */
