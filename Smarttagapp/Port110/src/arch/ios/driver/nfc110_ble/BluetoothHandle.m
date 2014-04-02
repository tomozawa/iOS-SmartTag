/**
 * \brief    Device handle for NFC Port-110 BLE Driver (iOS)
 * \date     2013/11/26
 * \author   Copyright 2013 Sony Corporation
 */

#undef ICSLOG_MODULE
#define ICSLOG_MODULE "DBb"

#import <CoreBluetooth/CoreBluetooth.h>

#include "ics_error.h"

#import "blelog.h"
#import "BluetoothHandle.h"
#import "BluetoothInternal.h"
#import "Semaphore.h"

/* --------------------------------
 * Constances
 * -------------------------------- */

#define BLEH_ERROR_DOMAIN @"BluetoothHandleErrorDomain"
#define BLEH_ERROR_CODE   ICS_ERROR_IO

/* --------------------------------
 * Private members
 * -------------------------------- */

@interface BluetoothHandle () <CBPeripheralDelegate>

/* for preparation */
@property (weak, nonatomic) id<BluetoothHandleDelegate> connectionDelegate;
@property (nonatomic) BOOL isConnecting;
@property (nonatomic) CBUUID* serviceUUID;
@property (nonatomic) CBUUID* readChUUID;
@property (nonatomic) CBUUID* notifyChUUID;
@property (nonatomic) CBUUID* writeChUUID;
@property (nonatomic) Semaphore* semUpdateNotification;

/* for connection */
@property (nonatomic) CBPeripheral* peripheral;
@property (nonatomic) CBCharacteristic* readCh;
@property (nonatomic) CBCharacteristic* notifyCh;
@property (nonatomic) CBCharacteristic* writeCh;
@property (nonatomic) Semaphore* semReadValue;
@property (nonatomic) Semaphore* semWriteValue;
@property (nonatomic) NSMutableArray* receiveBuffer;
@property (nonatomic) BLENotifyCallback notifyCallback;
@property (nonatomic) id notifyCallbackContent;

/* for error state */
@property (nonatomic) NSError* defaultError;
@property (nonatomic) NSError* readError;
@property (nonatomic) NSError* writeError;
@property (nonatomic) NSError* updateStateError;

- (void)callNotifyCallback:(NSData*)data;

@end

/* --------------------------------
 * Class definition
 * -------------------------------- */

@implementation BluetoothHandle
{
    /*
     * These member variables are defined in the category above,
     * because of the implementation of accessing from unit tests.
     */
#if 0
    /* for preparation */
    id<BluetoothHandleDelegate> _connectionDelegate;
    BOOL _isConnecting;
    CBUUID* _serviceUUID;
    CBUUID* _readChUUID;
    CBUUID* _notifyChUUID;
    CBUUID* _writeChUUID;
    Semaphore* _semUpdateNotification;

    /* for connection */
    CBPeripheral* _peripheral;
    CBCharacteristic* _readCh;
    CBCharacteristic* _notifyCh;
    CBCharacteristic* _writeCh;
    Semaphore* _semReadValue;
    Semaphore* _semWriteValue;
    NSMutableArray* _receiveBuffer;
    BLENotifyCallback _notifyCallback;
    id _notifyCallbackContent;

    /* for error state */
    NSError* _defaultError;
    NSError* _readError;
    NSError* _writeError;
    NSError* _updateStateError;
#endif
}

#pragma mark - public methods

/**
 * This method initializes the handle.
 *
 * \param  delegate               [IN] The delegate that will receive handle
 *                                     role events.
 *
 * \retval not nil                     Pointer to the instance.
 * \retval nil                         Initialization failure.
 */
- (id)initWithDelegate:(id<BluetoothHandleDelegate>)delegate
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "BluetoothHandle:initWithDelegate"
    ICSLOG_FUNC_BEGIN;

    self = [super init];
    if (self == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_NO_RESOURCES,
                         @"super initialization failed.");
        return nil;
    }

    _connectionDelegate = delegate;

    BLELOG_DBG_PRINT(@"Begin alloc: _semUpdateNotification");
    _semUpdateNotification = [[Semaphore alloc] initWithCount:0];
    BLELOG_DBG_PRINT(@"End alloc: _semUpdateNotification");
    if (_semUpdateNotification == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_NO_RESOURCES,
                         @"_semUpdateNotification initialization failed.");
        return nil;
    }

    BLELOG_DBG_PRINT(@"Begin alloc: _semReadValue");
    _semReadValue = [[Semaphore alloc] initWithCount:0];
    BLELOG_DBG_PRINT(@"End alloc: _semReadValue");
    if (_semReadValue == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_NO_RESOURCES,
                         @"_semReadValue initialization failed.");
        return nil;
    }

    BLELOG_DBG_PRINT(@"Begin alloc: _semWriteValue");
    _semWriteValue = [[Semaphore alloc] initWithCount:0];
    BLELOG_DBG_PRINT(@"End alloc: _semWriteValue");
    if (_semWriteValue == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_NO_RESOURCES,
                         @"_semWriteValue initialization failed.");
        return nil;
    }

    BLELOG_DBG_PRINT(@"Begin alloc: _receiveBuffer");
    _receiveBuffer = [[NSMutableArray alloc] init];
    BLELOG_DBG_PRINT(@"End alloc: _receiveBuffer");
    if (_receiveBuffer == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_NO_RESOURCES,
                         @"NSMutableArray initialization failed.");
        return nil;
    }

    BLELOG_DBG_PRINT(@"Begin alloc: _defaultError");
    _defaultError = [NSError errorWithDomain:BLEH_ERROR_DOMAIN
                                        code:BLEH_ERROR_CODE
                                    userInfo:nil];
    BLELOG_DBG_PRINT(@"End alloc: _defaultError");
    if (_defaultError == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_NO_RESOURCES,
                         @"_defaultError initialization failed.");
        return nil;
    }

    ICSLOG_FUNC_END;
    return self;
}

/**
 * This method sets a peripheral to the handle.
 *
 * \param  peripheral             [IN] The peripheral to set.
 */
- (void)setPeripheral:(CBPeripheral*)peripheral
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "BluetoothHandle:setPeripheral"
    ICSLOG_FUNC_BEGIN;

    _peripheral = peripheral;
    [_peripheral setDelegate:self];

    ICSLOG_FUNC_END;
}

/**
 * This method gets the peripheral from the handle.
 *
 * \retval peripheral
 */
- (CBPeripheral*)getPeripheral
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "BluetoothHandle:getPeripheral"
    ICSLOG_FUNC_BEGIN;

    ICSLOG_FUNC_END;
    return _peripheral;
}

/**
 * This method prepares the services presented by the device.
 *
 * \param  serviceUUID            [IN] The service UUID to discover.
 * \param  readChUUID             [IN] readCh UUID to discover.
 * \param  notifyChUUID           [IN] notifyCh UUID to discover.
 * \param  writeChUUID            [IN] writeCh UUID to discover.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_NOT_INITIALIZED   Not Initialized.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_NO_RESOURCES      An instance allocation failure.
 */
- (UInt32)prepareServices:(CBUUID*)serviceUUID
               readChUUID:(CBUUID*)readChUUID
             notifyChUUID:(CBUUID*)notifyChUUID
              writeChUUID:(CBUUID*)writeChUUID;
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "BluetoothHandle:prepareServices"
    UInt32 rc;
    NSArray* services;
    ICSLOG_FUNC_BEGIN;

    if (serviceUUID == nil) {
        rc = ICS_ERROR_INVALID_PARAM;
        BLELOG_ERR_PRINT(rc, @"Invalid parameter.");
        return rc;
    }

    if (readChUUID == nil) {
        rc = ICS_ERROR_INVALID_PARAM;
        BLELOG_ERR_PRINT(rc, @"Invalid parameter.");
        return rc;
    }

    if (notifyChUUID == nil) {
        rc = ICS_ERROR_INVALID_PARAM;
        BLELOG_ERR_PRINT(rc, @"Invalid parameter.");
        return rc;
    }

    if (writeChUUID == nil) {
        rc = ICS_ERROR_INVALID_PARAM;
        BLELOG_ERR_PRINT(rc, @"Invalid parameter.");
        return rc;
    }

    if (_peripheral == nil) {
        rc = ICS_ERROR_NOT_INITIALIZED;
        BLELOG_ERR_PRINT(rc, @"_peripheral is nil.");
        return rc;
    }

    _serviceUUID = serviceUUID;
    _readChUUID = readChUUID;
    _notifyChUUID = notifyChUUID;
    _writeChUUID = writeChUUID;

    BLELOG_DBG_PRINT(@"Begin alloc: services");
    services = @[serviceUUID];
    BLELOG_DBG_PRINT(@"End alloc: services");
    if (services == nil) {
        rc = ICS_ERROR_NO_RESOURCES;
        BLELOG_ERR_PRINT(rc, @"services initialization failed.");
        return rc;
    }

    _isConnecting = YES;

    [_peripheral discoverServices:services];

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This method sets notify value to the read characteristic.
 *
 * \param  enabled                [IN] Whether or not notifications/indications
 *                                     should be enabled.
 * \param  timeout                [IN] When to timeout.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_NOT_INITIALIZED   Not Initialized.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other I/O error occurred.
 */
- (UInt32)setNotifyValueToReadCharacteristic:(BOOL)enabled
                                     timeout:(dispatch_time_t)timeout
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "BluetoothHandle:setNotifyValueToReadCharacteristic"
    UInt32 rc;
    ICSLOG_FUNC_BEGIN;

    if (_peripheral == nil) {
        rc = ICS_ERROR_NOT_INITIALIZED;
        BLELOG_ERR_PRINT(rc, @"_peripheral is nil.");
        return rc;
    }

    if (_readCh == nil) {
        rc = ICS_ERROR_NOT_INITIALIZED;
        BLELOG_ERR_PRINT(rc, @"_readCh is nil.");
        return rc;
    }

    [_peripheral setNotifyValue:enabled forCharacteristic:_readCh];

    rc = [_semUpdateNotification waitTimeout:timeout];
    if (rc != ICS_ERROR_SUCCESS) {
        if (rc == ICS_ERROR_TIMEOUT) {
            BLELOG_ERR_PRINT(rc, @"An update readCh timeout occurred.");
        } else {
            rc = ICS_ERROR_IO;
        }
        return rc;
    }

    if (_updateStateError != nil) {
        rc = ICS_ERROR_IO;
        _updateStateError = nil;
        return rc;
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This method sets notify value to the notify characteristic.
 *
 * \param  enabled                [IN] Whether or not notifications/indications
 *                                     should be enabled.
 * \param  timeout                [IN] When to timeout.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_NOT_INITIALIZED   Not Initialized.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other I/O error occurred.
 */
- (UInt32)setNotifyValueToNotifyCharacteristic:(BOOL)enabled
                                       timeout:(dispatch_time_t)timeout
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "BluetoothHandle:setNotifyValueToNotifyCharacteristic"
    UInt32 rc;
    ICSLOG_FUNC_BEGIN;

    if (_peripheral == nil) {
        rc = ICS_ERROR_NOT_INITIALIZED;
        BLELOG_ERR_PRINT(rc, @"_peripheral is nil.");
        return rc;
    }

    if (_notifyCh == nil) {
        rc = ICS_ERROR_NOT_INITIALIZED;
        BLELOG_ERR_PRINT(rc, @"_notifyCh is nil.");
        return rc;
    }

    [_peripheral setNotifyValue:enabled forCharacteristic:_notifyCh];

    rc = [_semUpdateNotification waitTimeout:timeout];
    if (rc != ICS_ERROR_SUCCESS) {
        if (rc == ICS_ERROR_TIMEOUT) {
            BLELOG_ERR_PRINT(rc, @"An update notifyCh timeout occurred.");
        } else {
            rc = ICS_ERROR_IO;
        }
        return rc;
    }

    if (_updateStateError != nil) {
        rc = ICS_ERROR_IO;
        _updateStateError = nil;
        return rc;
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This method registers a notification callback function to the handle.
 *
 * \param  notifyCallback         [IN] The notification callback function to
 *                                     set.
 * \param  content                [IN] The content sent with every callbacks.
 */
- (void)registerNotifyCallback:(BLENotifyCallback)notifyCallback
                       content:(id)content
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "BluetoothHandle:registerNotifyCallback"
    ICSLOG_FUNC_BEGIN;

    @synchronized (self) {
        _notifyCallback = notifyCallback;
        _notifyCallbackContent = content;
    }

    ICSLOG_FUNC_END;
}

/**
 * This method calls writeValue method of the peripheral.
 *
 * \param  data                   [IN] The data written to the device.
 * \param  timeout                [IN] When to timeout.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_NOT_INITIALIZED   Not Initialized.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other I/O error occurred.
 */
- (UInt32)write:(NSData*)data timeout:(dispatch_time_t)timeout
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "BluetoothHandle:write"
    UInt32 rc;
    ICSLOG_FUNC_BEGIN;

    if (data == nil) {
        rc = ICS_ERROR_INVALID_PARAM;
        BLELOG_ERR_PRINT(rc, @"Invalid parameter.");
        return rc;
    }

    BLELOG_DBG_PRINT(@"%@", data.description);

    if (data.length > BLE_MAX_DATA_LEN) {
        rc = ICS_ERROR_INVALID_PARAM;
        BLELOG_ERR_PRINT(rc,
                         @"data length(%lu) must be <= %d.",
                         (unsigned long)data.length,
                         BLE_MAX_DATA_LEN);
        return rc;
    }

    if (_peripheral == nil) {
        rc = ICS_ERROR_NOT_INITIALIZED;
        BLELOG_ERR_PRINT(rc, @"_peripheral is nil.");
        return rc;
    }

    if (_writeCh == nil) {
        rc = ICS_ERROR_NOT_INITIALIZED;
        BLELOG_ERR_PRINT(rc, @"_writeCh is nil.");
        return rc;
    }

    [_peripheral writeValue:data
          forCharacteristic:_writeCh
                       type:CBCharacteristicWriteWithResponse];

    rc = [_semWriteValue waitTimeout:timeout];
    if (rc != ICS_ERROR_SUCCESS) {
        if (rc == ICS_ERROR_TIMEOUT) {
            BLELOG_ERR_PRINT(rc, @"A writeValue timeout occurred.");
        } else {
            rc = ICS_ERROR_IO;
        }
        return rc;
    }

    if (_writeError != nil) {
        rc = ICS_ERROR_IO;
        _writeError = nil;
        return rc;
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This method reads data from the data buffer.
 *
 * \param  data                  [OUT] The dequeued data from the buffer.
 * \param  length                 [IN] The length to be read.
 * \param  timeout                [IN] When to timeout.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_NO_RESOURCES      An instance allocation failure.
 * \retval ICS_ERROR_INVALID_RESPONSE  The device responds invalid data.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other I/O error occurred.
 */
- (UInt32)read:(NSData* __autoreleasing*)data
        length:(UInt32)length
       timeout:(dispatch_time_t)timeout
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "BluetoothHandle:read"
    UInt32 rc;
    NSData* response;
    ICSLOG_FUNC_BEGIN;

    if (data == nil) {
        rc = ICS_ERROR_INVALID_PARAM;
        BLELOG_ERR_PRINT(rc, @"Invalid parameter.");
        return rc;
    }

    rc = [_semReadValue waitTimeout:timeout];
    if (rc != ICS_ERROR_SUCCESS) {
        if (rc == ICS_ERROR_TIMEOUT) {
            BLELOG_ERR_PRINT(rc, @"A readValue timeout occurred.");
        } else {
            rc = ICS_ERROR_IO;
        }
        return rc;
    }

    if (_readError != nil) {
        rc = ICS_ERROR_IO;
        _readError = nil;
        return rc;
    }

    @synchronized (self) {
        if (_receiveBuffer.count == 0) {
            rc = ICS_ERROR_IO;
            BLELOG_ERR_PRINT(rc, @"_receiveBuffer count is 0.");
            return rc;
        }

        response = [_receiveBuffer objectAtIndex:0];

        if (response.length > BLE_MAX_DATA_LEN) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            BLELOG_ERR_PRINT(rc,
                             @"Response data length(%lu) must be <= %d.",
                             (unsigned long)response.length,
                             BLE_MAX_DATA_LEN);
            return rc;
        }

        if (response.length <= length) {
            [_receiveBuffer removeObjectAtIndex:0];
        } else {
            NSData* restData = response;

            BLELOG_DBG_PRINT(@"Begin alloc: response");
            response = [response subdataWithRange:NSMakeRange(0, length)];
            BLELOG_DBG_PRINT(@"End alloc: response");
            if (response == nil) {
                rc = ICS_ERROR_NO_RESOURCES;
                BLELOG_ERR_PRINT(rc, @"response initialization failed.");
                return rc;
            }

            BLELOG_DBG_PRINT(@"Begin alloc: restData");
            restData = [restData subdataWithRange:
                            NSMakeRange(length, restData.length - length)];
            BLELOG_DBG_PRINT(@"End alloc: restData");
            if (restData == nil) {
                rc = ICS_ERROR_NO_RESOURCES;
                BLELOG_ERR_PRINT(rc, @"restData initialization failed.");
                return rc;
            }

            [_receiveBuffer replaceObjectAtIndex:0 withObject:restData];
            [_semReadValue signal];
        }
    }

    *data = response;

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This method clears the receive buffer.
 */
- (void)clearReceiveBuffer
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "BluetoothHandle:clearReceiveBuffer"
    ICSLOG_FUNC_BEGIN;

    @synchronized (self) {
        [_receiveBuffer removeAllObjects];
        [_semReadValue reset];
    }

    ICSLOG_FUNC_END;
}

/**
 * This method returns whether or not the peripheral is connected.
 *
 * \retval YES                         Connecting.
 * \retval NO                          Disconnecting.
 */
- (BOOL)isConnected
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "BluetoothHandle:isConnected"
    BOOL isConnected;
    ICSLOG_FUNC_BEGIN;

    if (_peripheral == nil) {
        isConnected = false;
    } else {
        isConnected = [_peripheral isConnected];
    }

    ICSLOG_FUNC_END;
    return isConnected;
}

/**
 * This method returns whether or not the specified UUID is equal to the
 * peripheral UUID.
 *
 * \param  uuid                   [IN] UUID for comparing.
 *
 * \retval YES                         Equal.
 * \retval NO                          Not equal.
 */
- (BOOL)isEqualPeripheralUUID:(CFUUIDRef)uuid
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "BluetoothHandle:isEqualPeripheralUUID"
    BOOL isEqual;
    CFUUIDBytes uuidBytes1;
    CFUUIDBytes uuidBytes2;
    ICSLOG_FUNC_BEGIN;

    do {
        if (uuid == NULL) {
            isEqual = NO;
            break;
        }

        if (_peripheral == nil) {
            isEqual = NO;
            break;
        }

        if (_peripheral.UUID == NULL) {
            isEqual = NO;
            break;
        }

        uuidBytes1 = CFUUIDGetUUIDBytes(uuid);
        uuidBytes2 = CFUUIDGetUUIDBytes(_peripheral.UUID);

        if (!CMP_UUID(uuidBytes1, uuidBytes2)) {
            isEqual = NO;
            break;
        }

        isEqual = YES;
    } while (0);

    ICSLOG_FUNC_END;
    return isEqual;
}

#pragma mark - private methods

/**
 * This method calls the registered notification callback function with user's
 * content.
 *
 * \param  data                   [IN] The data to be send by the callback
 *                                     function.
 */
- (void)callNotifyCallback:(NSData*)data
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "BluetoothHandle:callNotifyCallback"
    BLENotifyCallback notifyCallback;
    id content;
    ICSLOG_FUNC_BEGIN;

    if (data == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_INVALID_PARAM, @"Invalid parameter.");
        return;
    }

    if (data.length > BLE_MAX_DATA_LEN) {
        BLELOG_ERR_PRINT(ICS_ERROR_INVALID_PARAM,
                         @"data.length(%lu) must be <= %d.",
                         (unsigned long)data.length,
                         BLE_MAX_DATA_LEN);
        return;
    }

    do {
        @synchronized (self) {
            if (_notifyCallback == NULL) {
                BLELOG_DBG_PRINT(@"_notifyCallback is NULL.");
                break;
            }

            notifyCallback = _notifyCallback;
            content = _notifyCallbackContent;
        }

        notifyCallback(data, content);
    } while (0);

    ICSLOG_FUNC_END;
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral*)peripheral
    didDiscoverServices:(NSError*)error
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "BluetoothHandle:didDiscoverServices"
    NSError* localError;
    CBService* matchService;
    NSArray* characteristicUUIDs;
    ICSLOG_FUNC_BEGIN;

    if (_isConnecting == NO) {
        return;
    }

    localError = nil;

    do {
        if (error != nil) {
            BLELOG_ERR_PRINT(ICS_ERROR_IO, @"%@", error.localizedDescription);
            localError = error;
            break;
        }

        if (peripheral == nil) {
            BLELOG_ERR_PRINT(ICS_ERROR_IO, @"peripheral is nil.");
            localError = _defaultError;
            break;
        }

        matchService = nil;

        for (CBService* service in peripheral.services) {
            BLELOG_DBG_PRINT(@"service found: %@", service.UUID);
            if ([service.UUID isEqual:_serviceUUID]) {
                matchService = service;
                break;
            }
        }

        if (matchService == nil) {
            BLELOG_ERR_PRINT(ICS_ERROR_IO, @"No service matched.");
            localError = _defaultError;
            break;
        }
    } while (0);

    if (localError != nil) {
        _isConnecting = NO;
        [_connectionDelegate bluetoothHandle:self
                          didPrepareServices:localError];
        return;
    }

    BLELOG_DBG_PRINT(@"Begin alloc: characteristicUUIDs");
    characteristicUUIDs = @[_readChUUID, _notifyChUUID, _writeChUUID];
    BLELOG_DBG_PRINT(@"End alloc: characteristicUUIDs");
    if (characteristicUUIDs == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_NO_RESOURCES,
                         @"restData initialization failed.");
        _isConnecting = NO;
        [_connectionDelegate bluetoothHandle:self
                          didPrepareServices:_defaultError];
        return;
    }

    [peripheral discoverCharacteristics:characteristicUUIDs
                             forService:matchService];

    ICSLOG_FUNC_END;
}

- (void)peripheral:(CBPeripheral*)peripheral
    didDiscoverCharacteristicsForService:(CBService*)service
    error:(NSError*)error
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "BluetoothHandle:didDiscoverCharacteristicsForService"
    NSError* localError;
    CBCharacteristic* readCh;
    CBCharacteristic* notifyCh;
    CBCharacteristic* writeCh;
    ICSLOG_FUNC_BEGIN;

    if (_isConnecting == NO) {
        return;
    }

    localError = nil;

    do {
        if (error != nil) {
            BLELOG_ERR_PRINT(ICS_ERROR_IO, @"%@", error.localizedDescription);
            localError = error;
            break;
        }

        readCh = nil;
        notifyCh = nil;
        writeCh = nil;

        /* If service is nil, nothing occurs. */
        for (CBCharacteristic* characteristic in service.characteristics) {
            BLELOG_DBG_PRINT(@"characteristic found: %@", characteristic.UUID);
            if ([characteristic.UUID isEqual:_readChUUID]) {
                BLELOG_DBG_PRINT(@"Found readUUID.");
                readCh = characteristic;
            } else if ([characteristic.UUID isEqual:_notifyChUUID]) {
                BLELOG_DBG_PRINT(@"Found notifyUUID.");
                notifyCh = characteristic;
            } else if ([characteristic.UUID isEqual:_writeChUUID]) {
                BLELOG_DBG_PRINT(@"Found writeUUID.");
                writeCh = characteristic;
            } else {
                /* Do nothing */
            }
        }

        if ((readCh == nil) || (notifyCh == nil) || (writeCh == nil)) {
            if (readCh == nil) {
                BLELOG_ERR_PRINT(ICS_ERROR_IO,
                                 @"No read characteristic matched.");
            }
            if (notifyCh == nil) {
                BLELOG_ERR_PRINT(ICS_ERROR_IO,
                                 @"No notify characteristic matched.");
            }
            if (writeCh == nil) {
                BLELOG_ERR_PRINT(ICS_ERROR_IO,
                                 @"No write characteristic matched.");
            }
            localError = _defaultError;
            break;
        }

        _readCh = readCh;
        _notifyCh = notifyCh;
        _writeCh = writeCh;
    } while (0);

    _isConnecting = NO;
    [_connectionDelegate bluetoothHandle:self
                      didPrepareServices:localError];

    ICSLOG_FUNC_END;
}

- (void)peripheral:(CBPeripheral*)peripheral
    didUpdateValueForCharacteristic:(CBCharacteristic*)characteristic
    error:(NSError*)error
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "BluetoothHandle:didUpdateValueForCharacteristic"
    ICSLOG_FUNC_BEGIN;

    if (error != nil) {
        _readError = error;
        BLELOG_ERR_PRINT(ICS_ERROR_IO, @"%@", error.localizedDescription);
        return;
    }

    if ([characteristic isEqual:_readCh]) {
        NSData* value = characteristic.value;
        if (value == nil) {
            BLELOG_ERR_PRINT(ICS_ERROR_INVALID_RESPONSE,
                             @"Received value is nil.");
            return;
        }

        BLELOG_DBG_PRINT(@"%@", value.description);

        @synchronized (self) {
            [_receiveBuffer addObject:value];
            [_semReadValue signal];
        }
    } else if ([characteristic isEqual:_notifyCh]) {
        NSData* value = characteristic.value;
        if (value == nil) {
            BLELOG_ERR_PRINT(ICS_ERROR_INVALID_RESPONSE,
                             @"Notify value is nil.");
            return;
        }

        if (value.length > 0) {
            if (((const UInt8*)[value bytes])[0] == 0x00) {
                BLELOG_DBG_PRINT(@"Encryption notification: %@",
                                 value.description);
                return;
            }
        }

        BLELOG_DBG_PRINT(@"Notify: %@", value.description);

        dispatch_async(GLOBAL_QUEUE, ^{
            @autoreleasepool {
                [self callNotifyCallback:value];
            }
        });
    } else {
        BLELOG_ERR_PRINT(ICS_ERROR_INVALID_RESPONSE,
                         @"Unsupported characteristic: %@",
                         characteristic.UUID);
        return;
    }

    ICSLOG_FUNC_END;
    return;
}

- (void)peripheral:(CBPeripheral*)peripheral
    didWriteValueForCharacteristic:(CBCharacteristic*)characteristic
    error:(NSError*)error
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "BluetoothHandle:didWriteValueForCharacteristic"
    ICSLOG_FUNC_BEGIN;

    if (error != nil) {
        _writeError = error;
        BLELOG_ERR_PRINT(ICS_ERROR_IO, @"%@", error.localizedDescription);
    }

    [_semWriteValue signal];

    ICSLOG_FUNC_END;
}

- (void)peripheral:(CBPeripheral*)peripheral
    didUpdateNotificationStateForCharacteristic:
        (CBCharacteristic*)characteristic
    error:(NSError*)error
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC \
    "BluetoothHandle:didUpdateNotificationStateForCharacteristic"
    ICSLOG_FUNC_BEGIN;

    if (error != nil) {
        _updateStateError = error;
        BLELOG_ERR_PRINT(ICS_ERROR_IO, @"%@", error.localizedDescription);
    }

    BLELOG_DBG_PRINT(@"characteristic: %@", characteristic.UUID);

    [_semUpdateNotification signal];

    ICSLOG_FUNC_END;
}

@end
