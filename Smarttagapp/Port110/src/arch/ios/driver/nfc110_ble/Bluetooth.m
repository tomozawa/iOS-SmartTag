/**
 * \brief    NFC Port-110 BLE Driver (iOS)
 * \date     2013/11/05
 * \author   Copyright 2013 Sony Corporation
 */

#undef ICSLOG_MODULE
#define ICSLOG_MODULE "DBb"

#import <CoreBluetooth/CoreBluetooth.h>

#include "ics_error.h"

#import "blelog.h"
#import "Bluetooth.h"
#import "BluetoothHandle.h"
#import "BluetoothInternal.h"
#import "Semaphore.h"

/* --------------------------------
 * Constants
 * -------------------------------- */

static NSString* const kUUIDService  = @"233e8100-3a1b-1c59-9bee-180373dd03a1";
static NSString* const kUUIDReadCh   = @"233e8101-3a1b-1c59-9bee-180373dd03a1";
static NSString* const kUUIDNotifyCh = @"233e8102-3a1b-1c59-9bee-180373dd03a1";
static NSString* const kUUIDWriteCh  = @"233e8103-3a1b-1c59-9bee-180373dd03a1";

/* --------------------------------
 * Private members
 * -------------------------------- */

@interface Bluetooth () <CBCentralManagerDelegate, BluetoothHandleDelegate>

@property (nonatomic) UInt32 errcode;

/* for initialization */
@property (nonatomic) Semaphore* semUpdateState;

/* for connection */
@property (nonatomic) BluetoothHandle* connectingHandle;
@property (nonatomic) Semaphore* semConnect;
@property (nonatomic) CFUUIDRef peripheralUUID;
@property (nonatomic) CBUUID* serviceUUID;
@property (nonatomic) CBUUID* readUUID;
@property (nonatomic) CBUUID* notifyUUID;
@property (nonatomic) CBUUID* writeUUID;
@property (nonatomic) NSDictionary* connectOption;

@property (nonatomic) NSMutableDictionary* handleList;
@property (nonatomic) CBCentralManager* centralManager;

/* for callback */
@property (nonatomic) BLEConnectionStateCallback connectionStateCallback;
@property (nonatomic) id connectionStateCallbackContent;

- (void)setHandleObject:(void*)handle object:(id)object;
- (BluetoothHandle*)getHandleObject:(void*)handle;
- (void)removeHandleObject:(void*)handle;
- (void)callConnectionStateCallback:(CBPeripheral*)peripheral
                              state:(BLEConnectionState)state;

@end

/* --------------------------------
 * Class definition
 * -------------------------------- */

@implementation Bluetooth
{
    UInt32 errcode;

    /*
     * These member variables are defined in the category above,
     * because of the implementation of accessing from unit tests.
     */
#if 0
    /* for initialization */
    Semaphore* _semUpdateState;

    /* for connection */
    BluetoothHandle* _connectingHandle;
    Semaphore* _semConnect;
    CFUUIDRef _peripheralUUID;
    CBUUID* _serviceUUID;
    CBUUID* _readUUID;
    CBUUID* _notifyUUID;
    CBUUID* _writeUUID;
    NSDictionary* _connectOption;

    NSMutableDictionary* _handleList;
    CBCentralManager* _centralManager;

    /* for callback */
    BLEConnectionStateCallback _connectionStateCallback;
    id _connectionStateCallbackContent;
#endif
}

/* --------------------------------
 * Property definition
 * -------------------------------- */

@synthesize errcode;

#pragma mark - initialize methods

/**
 * This method initializes to the Bluetooth class instance.
 *
 * \retval not nil                     Pointer to the instance.
 * \retval nil                         Initialization failure.
 *
 * Error codes (the value can be gotten from errcode).
 * errcode cannot be accessible.
 */
- (id)init
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:init"
    ICSLOG_FUNC_BEGIN;

    self = [super init];
    if (self == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_NO_RESOURCES,
                         @"super initialization failed.");
        return nil;
    }

    errcode = ICS_ERROR_SUCCESS;

    BLELOG_DBG_PRINT(@"Begin alloc: _semUpdateState");
    _semUpdateState = [[Semaphore alloc] initWithCount:0];
    BLELOG_DBG_PRINT(@"End alloc: _semUpdateState");
    if (_semUpdateState == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_NO_RESOURCES,
                         @"_semUpdateState initialization failed.");
        return nil;
    }

    BLELOG_DBG_PRINT(@"Begin alloc: _semConnect");
    _semConnect = [[Semaphore alloc] initWithCount:0];
    BLELOG_DBG_PRINT(@"End alloc: _semConnect");
    if (_semConnect == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_NO_RESOURCES,
                         @"_semConnect initialization failed.");
        return nil;
    }

    BLELOG_DBG_PRINT(@"Begin alloc: _serviceUUID");
    _serviceUUID = [CBUUID UUIDWithString:kUUIDService];
    BLELOG_DBG_PRINT(@"End alloc: _serviceUUID");
    if (_serviceUUID == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_NO_RESOURCES,
                         @"_serviceUUID initialization failed.");
        return nil;
    }

    BLELOG_DBG_PRINT(@"Begin alloc: _readUUID");
    _readUUID   = [CBUUID UUIDWithString:kUUIDReadCh];
    BLELOG_DBG_PRINT(@"End alloc: _readUUID");
    if (_readUUID == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_NO_RESOURCES,
                         @"_readUUID initialization failed.");
        return nil;
    }

    BLELOG_DBG_PRINT(@"Begin alloc: _notifyUUID");
    _notifyUUID = [CBUUID UUIDWithString:kUUIDNotifyCh];
    BLELOG_DBG_PRINT(@"End alloc: _notifyUUID");
    if (_notifyUUID == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_NO_RESOURCES,
                         @"_notifyUUID initialization failed.");
        return nil;
    }

    BLELOG_DBG_PRINT(@"Begin alloc: _writeUUID");
    _writeUUID  = [CBUUID UUIDWithString:kUUIDWriteCh];
    BLELOG_DBG_PRINT(@"End alloc: _writeUUID");
    if (_writeUUID == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_NO_RESOURCES,
                         @"_writeUUID initialization failed.");
        return nil;
    }

    BLELOG_DBG_PRINT(@"Begin alloc: _handleList");
    _handleList = [NSMutableDictionary
                       dictionaryWithCapacity:BLE_MAX_UUID_LIST];
    BLELOG_DBG_PRINT(@"End alloc: _handleList");
    if (_handleList == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_NO_RESOURCES,
                         @"_handleList initialization failed.");
        return nil;
    }

    BLELOG_DBG_PRINT(@"Begin alloc: _connectOption");
    _connectOption = @{CBConnectPeripheralOptionNotifyOnConnectionKey:@YES,
                       CBConnectPeripheralOptionNotifyOnDisconnectionKey:@YES,
                       CBConnectPeripheralOptionNotifyOnNotificationKey:@YES};
    BLELOG_DBG_PRINT(@"End alloc: _connectOption");
    if (_connectOption == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_NO_RESOURCES,
                         @"_connectOption initialization failed.");
        return nil;
    }

    _initTimeout = BLE_INIT_DEFAULT_TIMEOUT;
    _readChTimeout = BLE_READCH_UPDATE_DEFAULT_TIMEOUT;
    _notifyChTimeout = BLE_NOTIFYCH_UPDATE_DEFAULT_TIMEOUT;

    _RSSIMinForDiscoverPeripheral = BLE_INVALID_RSSI;

    BLELOG_DBG_PRINT(@"Begin alloc: _centralManager");
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                           queue:GLOBAL_QUEUE];
    BLELOG_DBG_PRINT(@"End alloc: _centralManager");
    if (_centralManager == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_NO_RESOURCES,
                         @"_centralManager initialization failed.");
        return nil;
    }

    /* centralManagerDidUpdateState almost immediately returns. */
    [_semUpdateState waitTimeout:DISPATCH_TIME_FOREVER];
    _semUpdateState = nil;

    ICSLOG_FUNC_END;
    return self;
}

#pragma mark - public methods

/**
 * This method opens a handle of the device.
 *
 * \param  uuid                   [IN] A peripheral UUID to discover. If the
 *                                     length of uuid is 0, any peripheral will
 *                                     be discovered.
 *
 * \retval not NULL                    Pointer of the handle.
 * \retval NULL                        Initialization failure.
 *
 * Error codes (the value can be gotten from errcode).
 * ICS_ERROR_SUCCESS                   No error.
 * ICS_ERROR_NO_RESOURCES              Failed to allocate an instance.
 * ICS_ERROR_BUSY                      open method is already running, or the
 *                                     specified device by uuid is already
 *                                     connected, or the handle list is full.
 * ICS_ERROR_TIMEOUT                   Time-out.
 * ICS_ERROR_IO                        Other I/O error occurred.
 */
- (void*)open:(NSString*)uuid
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:open"
    UInt32 rc;
    dispatch_time_t timeout;
    void* handle;
    ICSLOG_FUNC_BEGIN;

    /* --------------------------------- *
     * Timeout creations                 *
     * --------------------------------- */

    timeout = dispatch_time(DISPATCH_TIME_NOW,
                            NSEC_PER_MSEC * _initTimeout);

    /* --------------------------------- *
     * Local variable initializations    *
     * --------------------------------- */

    handle = NULL;

    /* --------------------------------- *
     * Parameter checks                  *
     * --------------------------------- */

    if (uuid == nil) {
        errcode = ICS_ERROR_INVALID_PARAM;
        BLELOG_ERR_PRINT(errcode, @"uuid is nil.");
        return NULL;
    }

    /* --------------------------------- *
     * OS state checks                   *
     * --------------------------------- */

    if (_centralManager.state != CBCentralManagerStatePoweredOn) {
        errcode = ICS_ERROR_IO;
        BLELOG_ERR_PRINT(errcode, @"CentralManager state is not powered on.");
        /*
         * The following method appears the alert prompt for
         * the setting of the bluetooth device to turn on.
         */
        _centralManager =
            [_centralManager initWithDelegate:self queue:GLOBAL_QUEUE];
        return NULL;
    }

    /* --------------------------------- *
     * Member resource checks            *
     * --------------------------------- */

    @synchronized (self) {
        if (_handleList.count >= BLE_MAX_CONNECTION) {
            errcode = ICS_ERROR_BUSY;
            BLELOG_ERR_PRINT(errcode, @"Handle list is max.");
            return NULL;
        }

        if (_connectingHandle != nil) {
            errcode = ICS_ERROR_BUSY;
            BLELOG_ERR_PRINT(errcode, @"open: is already running.");
            return NULL;
        }
    }

    do {

        /* --------------------------------- *
         * Connection member resource resets *
         * --------------------------------- */

        [_semConnect reset];
        errcode = ICS_ERROR_SUCCESS;

        /* --------------------------------- *
         * Member resource allocations       *
         * --------------------------------- */

        @synchronized (self) {
            BLELOG_DBG_PRINT(@"Begin alloc: _connectingHandle");
            _connectingHandle = [[BluetoothHandle alloc] initWithDelegate:self];
            BLELOG_DBG_PRINT(@"End alloc: _connectingHandle");
            if (_connectingHandle == nil) {
                errcode = ICS_ERROR_NO_RESOURCES;
                BLELOG_ERR_PRINT(errcode,
                                 @"_connectingHandle initialization failed.");
                break;
            }
        }

        /* --------------------------------- *
         * Connection start                  *
         * --------------------------------- */

        if (uuid.length > 0) {
            BLELOG_DBG_PRINT(@"Begin alloc: _peripheralUUID");
            _peripheralUUID = CFUUIDCreateFromString(kCFAllocatorDefault,
                                                     (CFStringRef)uuid);
            BLELOG_DBG_PRINT(@"End alloc: _peripheralUUID");
            if (_peripheralUUID == NULL) {
                errcode = ICS_ERROR_IO;
                BLELOG_ERR_PRINT(errcode,
                                 @"_peripheralUUID initialization failed.");
                break;
            }

            @synchronized (self) {
                BOOL hasUUID = NO;
                for (id key in _handleList) {
                    BluetoothHandle* bleh = [_handleList objectForKey:key];
                    if ([bleh isEqualPeripheralUUID:_peripheralUUID]) {
                        errcode = ICS_ERROR_BUSY;
                        BLELOG_ERR_PRINT(errcode,
                                         @"The same UUID is already opened.");
                        hasUUID = YES;
                        break;
                    }
                }
                if (hasUUID) {
                    break;
                }
            }

            [_centralManager retrieveConnectedPeripherals];

            rc = [_semConnect waitTimeout:timeout];
            if (rc != ICS_ERROR_SUCCESS) {
                errcode = ICS_ERROR_TIMEOUT;
                BLELOG_ERR_PRINT(errcode, @"A connection timeout occurred.");
                break;
            }

            if (errcode != ICS_ERROR_SUCCESS) {
                if (errcode != ICS_ERROR_BUSY) {
                    errcode = ICS_ERROR_IO;
                    BLELOG_ERR_PRINT(errcode, @"Some error occurred.");
                }
                break;
            }

            rc = [self connectRetrievedPeripheral:timeout];
            if (rc != ICS_ERROR_SUCCESS) {
                BLELOG_ERR_PRINT(rc, @"Some error occurred.");
                break;
            }
        } else {
            rc = [self connectScannedPeripheral:timeout];
            if (rc != ICS_ERROR_SUCCESS) {
                BLELOG_ERR_PRINT(rc, @"Some error occurred.");
                break;
            }
        }

        /* --------------------------------- *
         * Device state settings             *
         * --------------------------------- */

        /* Set notify value to read characteristic */

        timeout = dispatch_time(DISPATCH_TIME_NOW,
                                NSEC_PER_MSEC * _readChTimeout);

        rc = [_connectingHandle setNotifyValueToReadCharacteristic:YES
                                                           timeout:timeout];
        if (rc != ICS_ERROR_SUCCESS) {
            if (rc == ICS_ERROR_TIMEOUT) {
                errcode = ICS_ERROR_TIMEOUT;
                BLELOG_ERR_PRINT(
                    errcode,
                    @"setNotifyValueToReadCharacteristic timeout.");
            } else {
                errcode = ICS_ERROR_IO;
                BLELOG_ERR_PRINT(
                    errcode,
                    @"setNotifyValueToReadCharacteristic failed.");
            }
            break;
        }

        /* Set notify value to notify characteristic */

        timeout = dispatch_time(DISPATCH_TIME_NOW,
                                NSEC_PER_MSEC * _notifyChTimeout);

        rc = [_connectingHandle setNotifyValueToNotifyCharacteristic:YES
                                                             timeout:timeout];
        if (rc != ICS_ERROR_SUCCESS) {
            if (rc == ICS_ERROR_TIMEOUT) {
                errcode = ICS_ERROR_TIMEOUT;
                BLELOG_ERR_PRINT(
                    errcode,
                    @"setNotifyValueToNotifyCharacteristic timeout.");
            } else {
                errcode = ICS_ERROR_IO;
                BLELOG_ERR_PRINT(
                    errcode,
                    @"setNotifyValueToNotifyCharacteristic failed.");
            }
            break;
        }

        /* --------------------------------- *
         * Handle register                   *
         * --------------------------------- */

        handle = (__bridge void*)_connectingHandle;

        [self setHandleObject:handle object:_connectingHandle];

        errcode = ICS_ERROR_SUCCESS;
    } while(0);

    /* --------------------------------- *
     * Connection resource releases      *
     * --------------------------------- */

    [_centralManager stopScan];

    if (_peripheralUUID != NULL) {
        CFRelease(_peripheralUUID);
        _peripheralUUID = NULL;
    }

    @synchronized (self) {
        _connectingHandle = nil;
    }

    ICSLOG_FUNC_END;
    return handle;
}

/**
 * This method closes the handle.
 *
 * \param  handle                 [IN] The handle to close.
 *
 * Error codes (the value can be gotten from errcode).
 * ICS_ERROR_SUCCESS                   No error.
 * ICS_ERROR_IO                        Other I/O error occurred.
 */
- (UInt32)close:(void*)handle
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:close"
    BluetoothHandle* bleh;
    CBPeripheral* peripheral;
    ICSLOG_FUNC_BEGIN;

    bleh = [self getHandleObject:handle];
    if (bleh == nil) {
        errcode = ICS_ERROR_IO;
        BLELOG_ERR_PRINT(errcode, @"The device is not opened.");
        return errcode;
    }

    peripheral = [bleh getPeripheral];
    if (peripheral == nil) {
        errcode = ICS_ERROR_IO;
        BLELOG_ERR_PRINT(errcode, @"peripheral is nil.");
        return errcode;
    }

    [_centralManager cancelPeripheralConnection:peripheral];

    /*
     * Waiting disconnection (max 100ms)
     * CoreBluetooth[WARNING] will occur, when the peripheral is being
     * dealloc'ed while connected.
     */
    for (int i = 0; (i < 10) && peripheral.isConnected; i++) {
        [NSThread sleepForTimeInterval:0.01];
    }

    [self removeHandleObject:handle];

    errcode = ICS_ERROR_SUCCESS;

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This method resets the handle.
 *
 * \param  handle                 [IN] The handle to reset.
 *
 * Error codes (the value can be gotten from errcode).
 * ICS_ERROR_SUCCESS                   No error.
 * ICS_ERROR_IO                        Other I/O error occurred.
 */
- (UInt32)reset:(void*)handle
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:reset"
    BluetoothHandle* bleh;
    ICSLOG_FUNC_BEGIN;

    bleh = [self getHandleObject:handle];
    if (bleh == nil) {
        errcode = ICS_ERROR_IO;
        BLELOG_ERR_PRINT(errcode, @"The device is not opened.");
        return errcode;
    }

    [bleh registerNotifyCallback:NULL content:NULL];

    errcode = ICS_ERROR_SUCCESS;

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This method writes the command to the device.
 *
 * \param  handle                 [IN] The handle to write.
 * \param  command                [IN] Command written to the device.
 * \param  timeoutMsecs           [IN] Time-out period. (ms)
 *
 * \retval not -1                      The number of bytes written.
 * \retval -1                          Some error occurred.
 *
 * Error codes (the value can be gotten from errcode).
 * ICS_ERROR_SUCCESS                   No error.
 * ICS_ERROR_INVALID_PARAM             Invalid parameter.
 * ICS_ERROR_TIMEOUT                   Time-out.
 * ICS_ERROR_IO                        Other I/O error occurred.
 */
- (NSInteger)write:(void*)handle
           command:(NSData*)command
      timeoutMsecs:(UInt32)timeoutMsecs;
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:write"
    UInt32 rc;
    dispatch_time_t timeout;
    BluetoothHandle* bleh;
    ICSLOG_FUNC_BEGIN;

    timeout = dispatch_time(DISPATCH_TIME_NOW,
                            NSEC_PER_MSEC * timeoutMsecs);

    bleh = [self getHandleObject:handle];
    if (bleh == nil) {
        errcode = ICS_ERROR_IO;
        BLELOG_ERR_PRINT(errcode, @"The device is not opened.");
        return -1;
    }

    if ([bleh isConnected] == NO) {
        errcode = ICS_ERROR_IO;
        BLELOG_ERR_PRINT(errcode, @"The device is not connected.");
        return -1;
    }

    rc = [bleh write:command timeout:timeout];
    if (rc != ICS_ERROR_SUCCESS) {
        if (rc == ICS_ERROR_TIMEOUT) {
            errcode = ICS_ERROR_TIMEOUT;
            BLELOG_ERR_PRINT(errcode, @"write timeout.");
        } else {
            errcode = ICS_ERROR_IO;
            BLELOG_ERR_PRINT(errcode, @"write failed.");
        }
        return -1;
    }

    errcode = ICS_ERROR_SUCCESS;

    ICSLOG_FUNC_END;
    return command.length;
}

/**
 * This method reads the response from the device.
 *
 * \param  handle                 [IN] The handle to read.
 * \param  response              [OUT] Response data from the device.
 * \param  length                 [IN] Read length.
 * \param  timeoutMsecs           [IN] Time-out period. (ms)
 *
 * \retval not -1                      The number of bytes read.
 * \retval -1                          Some error occurred.
 *
 * Error codes (the value can be gotten from errcode).
 * ICS_ERROR_SUCCESS                   No error.
 * ICS_ERROR_INVALID_PARAM             Invalid parameter.
 * ICS_ERROR_INVALID_RESPONSE          The device responds invalid data.
 * ICS_ERROR_TIMEOUT                   Time-out.
 * ICS_ERROR_IO                        Other I/O error occurred.
 */
- (NSInteger)read:(void*)handle
         response:(NSData* __autoreleasing*)response
           length:(UInt32)length
     timeoutMsecs:(UInt32)timeoutMsecs
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:read"
    UInt32 rc;
    dispatch_time_t timeout;
    BluetoothHandle* bleh;
    ICSLOG_FUNC_BEGIN;

    timeout = dispatch_time(DISPATCH_TIME_NOW,
                            NSEC_PER_MSEC * timeoutMsecs);

    bleh = [self getHandleObject:handle];
    if (bleh == nil) {
        errcode = ICS_ERROR_IO;
        BLELOG_ERR_PRINT(errcode, @"The device is not opened.");
        return -1;
    }

    if ([bleh isConnected] == NO) {
        errcode = ICS_ERROR_IO;
        BLELOG_ERR_PRINT(errcode, @"The device is not connected.");
        return -1;
    }

    rc = [bleh read:response length:length timeout:timeout];
    if (rc != ICS_ERROR_SUCCESS) {
        if (rc == ICS_ERROR_TIMEOUT) {
            errcode = ICS_ERROR_TIMEOUT;
            BLELOG_ERR_PRINT(errcode, @"read timeout.");
        } else {
            errcode = ICS_ERROR_IO;
            BLELOG_ERR_PRINT(errcode, @"read failed.");
        }
        return -1;
    }

    if (*response == nil) {
        errcode = ICS_ERROR_INVALID_RESPONSE;
        BLELOG_ERR_PRINT(errcode, @"read returned nil.");
        return -1;
    }

    errcode = ICS_ERROR_SUCCESS;

    ICSLOG_FUNC_END;
    return (*response).length;
}

/**
 * This method clears the receive buffer of the handle.
 *
 * \param  handle                 [IN] The handle to register.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_IO                Other I/O error occurred.
 *
 * Error codes (the value can be gotten from errcode).
 * ICS_ERROR_SUCCESS                   No error.
 * ICS_ERROR_IO                        Other I/O error occurred.
 */
- (UInt32)clearReceiveBuffer:(void*)handle
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:clearReceiveBuffer"
    BluetoothHandle* bleh;
    ICSLOG_FUNC_BEGIN;

    bleh = [self getHandleObject:handle];
    if (bleh == nil) {
        errcode = ICS_ERROR_IO;
        BLELOG_ERR_PRINT(errcode, @"The device is not opened.");
        return errcode;
    }

    [bleh clearReceiveBuffer];

    errcode = ICS_ERROR_SUCCESS;

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This method registers the notify callback function to the handle.
 *
 * \param  handle                 [IN] The handle to register.
 * \param  notifyCallback         [IN] The notification callback function to
 *                                     set.
 * \param  content                [IN] The content sending with a callback.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_IO                Other I/O error occurred.
 *
 * Error codes (the value can be gotten from errcode).
 * ICS_ERROR_SUCCESS                   No error.
 * ICS_ERROR_IO                        Other I/O error occurred.
 */
- (UInt32)registerNotifyCallback:(void*)handle
                  notifyCallback:(BLENotifyCallback)notifyCallback
                         content:(id)content
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:registerNotifyCallback"
    BluetoothHandle* bleh;
    ICSLOG_FUNC_BEGIN;

    bleh = [self getHandleObject:handle];
    if (bleh == nil) {
        errcode = ICS_ERROR_IO;
        BLELOG_ERR_PRINT(errcode, @"The device is not opened.");
        return errcode;
    }

    [bleh registerNotifyCallback:notifyCallback content:content];

    errcode = ICS_ERROR_SUCCESS;

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This method registers the connection state callback function.
 *
 * \param  callback               [IN] The connection callback function to set.
 * \param  content                [IN] The content sending with a callback.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 *
 * Error codes (the value can be gotten from errcode).
 * ICS_ERROR_SUCCESS                   No error.
 */
- (UInt32)registerConnectionStateCallback:(BLEConnectionStateCallback)callback
                                  content:(id)content
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:registerConnectionStateCallback"
    ICSLOG_FUNC_BEGIN;

    @synchronized (self) {
        _connectionStateCallback = callback;
        _connectionStateCallbackContent = content;
    }

    errcode = ICS_ERROR_SUCCESS;

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This method returns the peripheral UUID of the handle.
 *
 * \param  handle                 [IN] The handle.
 * \param  uuid                  [OUT] The peripheral's UUID.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_NO_RESOURCES      Failed to allocate an instance.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_IO                Other I/O error occurred.
 *
 * Error codes (the value can be gotten from errcode).
 * ICS_ERROR_SUCCESS                   No error.
 * ICS_ERROR_NO_RESOURCES              Failed to allocate an instance.
 * ICS_ERROR_INVALID_PARAM             Invalid parameter.
 * ICS_ERROR_IO                        Other I/O error occurred.
 */
- (UInt32)getPeripheralUUID:(void *)handle
             uuid:(NSString *__autoreleasing *)uuid
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:getPeripheralUUID"
    BluetoothHandle* bleh;
    ICSLOG_FUNC_BEGIN;

    if (uuid == nil) {
        errcode = ICS_ERROR_INVALID_PARAM;
        BLELOG_ERR_PRINT(errcode, @"attr is nil.");
        return errcode;
    }

    bleh = [self getHandleObject:handle];
    if (bleh == nil) {
        errcode = ICS_ERROR_IO;
        BLELOG_ERR_PRINT(errcode, @"The device is not opened.");
        return errcode;
    }

    CBPeripheral* peripheral = [bleh getPeripheral];
    if (peripheral == nil) {
        errcode = ICS_ERROR_IO;
        BLELOG_ERR_PRINT(errcode, @"peripheral is nil.");
        return errcode;
    }

    CFUUIDRef uuidRef = peripheral.UUID;
    if (uuidRef == NULL) {
        errcode = ICS_ERROR_IO;
        BLELOG_ERR_PRINT(errcode, @"uuidRef is NULL.");
        return errcode;
    }

    BLELOG_DBG_PRINT(@"Begin alloc: uuidCFStr");
    CFStringRef uuidCFStr = CFUUIDCreateString(kCFAllocatorDefault, uuidRef);
    BLELOG_DBG_PRINT(@"End alloc: uuidCFStr");
    if (uuidCFStr == NULL) {
        errcode = ICS_ERROR_NO_RESOURCES;
        BLELOG_ERR_PRINT(errcode, @"uuidCFStr is nil.");
        return errcode;
    }

    *uuid = (__bridge_transfer NSString*)uuidCFStr;

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

#pragma mark - private methods

/**
 * This method sets the handle object with handle key.
 *
 * \param  handle                 [IN] The handle pointer.
 * \param  object                 [IN] The object to set.
 */
- (void)setHandleObject:(void*)handle object:(id)object
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:setHandleObject"
    NSValue* handleKey;
    ICSLOG_FUNC_BEGIN;

    if (object == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_INVALID_PARAM,
                         @"object is nil.");
        return;
    }

    BLELOG_DBG_PRINT(@"Begin alloc: NSValue");
    handleKey = [NSValue valueWithPointer:handle];
    BLELOG_DBG_PRINT(@"End alloc: NSValue");
    if (handleKey == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_NO_RESOURCES,
                         @"handleKey initialization failed.");
        return;
    }

    @synchronized (self) {
        [_handleList setObject:object forKey:handleKey];
    }

    ICSLOG_FUNC_END;
}

/**
 * This method returns the handle object match to the specified handle.
 *
 * \param  handle                 [IN] The handle pointer.
 *
 * \retval not nil                     No error.
 * \retval nil                         No match handle object.
 */
- (BluetoothHandle*)getHandleObject:(void*)handle
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:getHandleObject"
    NSValue* handleKey;
    BluetoothHandle* bleh;
    ICSLOG_FUNC_BEGIN;

    BLELOG_DBG_PRINT(@"Begin alloc: NSValue");
    handleKey = [NSValue valueWithPointer:handle];
    BLELOG_DBG_PRINT(@"End alloc: NSValue");
    if (handleKey == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_NO_RESOURCES,
                         @"handleKey initialization failed.");
        return nil;
    }

    @synchronized (self) {
        bleh = [_handleList objectForKey:handleKey];
    }

    ICSLOG_FUNC_END;
    return bleh;
}

/**
 * This method removes the handle object match to the specified handle.
 *
 * \param  handle                 [IN] The handle pointer.
 */
- (void)removeHandleObject:(void*)handle
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:removeHandleObject"
    NSValue* handleKey;
    ICSLOG_FUNC_BEGIN;

    BLELOG_DBG_PRINT(@"Begin alloc: NSValue");
    handleKey = [NSValue valueWithPointer:handle];
    BLELOG_DBG_PRINT(@"End alloc: NSValue");
    if (handleKey == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_NO_RESOURCES,
                         @"handleKey initialization failed.");
        return;
    }

    @synchronized (self) {
        [_handleList removeObjectForKey:handleKey];
    }

    ICSLOG_FUNC_END;
}

/**
 * This method connects to the scanned peripheral.
 *
 * \param  timeout                [IN] timeout.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_NO_RESOURCES      Failed to allocate an instance.
 * \retval ICS_ERROR_BUSY              open method is already running, or the
 *                                     specified device by uuid is already
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other I/O error occurred.
 *
 * Error codes (the value can be gotten from errcode).
 * ICS_ERROR_SUCCESS                   No error.
 * ICS_ERROR_NO_RESOURCES              Failed to allocate an instance.
 * ICS_ERROR_BUSY                      open method is already running, or the
 *                                     specified device by uuid is already
 * ICS_ERROR_TIMEOUT                   Time-out.
 * ICS_ERROR_IO                        Other I/O error occurred.
 */
- (UInt32)connectScannedPeripheral:(dispatch_time_t)timeout
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:connectScannedPeripheral"
    UInt32 rc;
    ICSLOG_FUNC_BEGIN;

    BLELOG_DBG_PRINT(@"Begin alloc: services");
    NSArray* services = @[_serviceUUID];
    BLELOG_DBG_PRINT(@"End alloc: services");
    if (services == nil) {
        rc = ICS_ERROR_NO_RESOURCES;
        errcode = rc;
        BLELOG_ERR_PRINT(rc, @"services initialization failed.");
        return rc;
    }

    /*
     * Default scan options:
     *   CBCentralManagerScanOptionAllowDuplicatesKey:NO
     */
    [_centralManager scanForPeripheralsWithServices:services
                                            options:nil];

    rc = [_semConnect waitTimeout:timeout];
    if (rc != ICS_ERROR_SUCCESS) {
        rc = ICS_ERROR_TIMEOUT;
        errcode = rc;
        BLELOG_ERR_PRINT(rc, @"scanForPeripheralsWithServices timeout.");
        return rc;
    }

    if (errcode != ICS_ERROR_SUCCESS) {
        if (errcode != ICS_ERROR_BUSY) {
            rc = ICS_ERROR_IO;
            errcode = rc;
        } else {
            rc = errcode;
        }
        BLELOG_ERR_PRINT(rc, @"scanForPeripheralsWithServices failed.");
        return rc;
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This method connects to the retrieved peripheral.
 *
 * \param  timeout                [IN] timeout.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_NO_RESOURCES      Failed to allocate an instance.
 * \retval ICS_ERROR_BUSY              open method is already running, or the
 *                                     specified device by uuid is already
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other I/O error occurred.
 *
 * Error codes (the value can be gotten from errcode).
 * ICS_ERROR_SUCCESS                   No error.
 * ICS_ERROR_NO_RESOURCES              Failed to allocate an instance.
 * ICS_ERROR_BUSY                      open method is already running, or the
 *                                     specified device by uuid is already
 * ICS_ERROR_TIMEOUT                   Time-out.
 * ICS_ERROR_IO                        Other I/O error occurred.
 */
- (UInt32)connectRetrievedPeripheral:(dispatch_time_t)timeout
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:connectRetrievedPeripheral"
    UInt32 rc;
    ICSLOG_FUNC_BEGIN;

    BLELOG_DBG_PRINT(@"UUID: %@", _peripheralUUID);
    if (_peripheralUUID == NULL) {
        rc = ICS_ERROR_IO;
        errcode = rc;
        BLELOG_ERR_PRINT(rc, @"UUID is not specified.");
        return rc;
    }

    BLELOG_DBG_PRINT(@"Begin alloc: UUIDs");
    NSArray* UUIDs = @[(__bridge id)_peripheralUUID];
    BLELOG_DBG_PRINT(@"End alloc: UUIDs");
    if (UUIDs == nil) {
        rc = ICS_ERROR_NO_RESOURCES;
        errcode = rc;
        BLELOG_ERR_PRINT(rc, @"UUIDs initialization failed.");
        return rc;
    }

    [_centralManager retrievePeripherals:UUIDs];

    rc = [_semConnect waitTimeout:timeout];
    if (rc != ICS_ERROR_SUCCESS) {
        rc = ICS_ERROR_TIMEOUT;
        errcode = rc;
        BLELOG_ERR_PRINT(rc, @"retrievePeripherals timeout.");
        return rc;
    }

    if (errcode != ICS_ERROR_SUCCESS) {
        if (errcode != ICS_ERROR_BUSY) {
            rc = ICS_ERROR_IO;
            errcode = rc;
        } else {
            rc = errcode;
        }
        BLELOG_ERR_PRINT(rc, @"retrievePeripherals failed.");
        return rc;
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This method calls the registered connection state callback function with
 * user's content.
 *
 * \param  peripheral             [IN] The state changed peripheral.
 * \param  state                  [IN] Sending data by the callback function.
 */
- (void)callConnectionStateCallback:(CBPeripheral*)peripheral
                              state:(BLEConnectionState)state
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:callConnectionStateCallback"
    BLEConnectionStateCallback connectionStateCallback;
    void* handle;
    id content;
    ICSLOG_FUNC_BEGIN;

    if (peripheral == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_INVALID_PARAM, @"Invalid parameter.");
        return;
    }

    do {
        @synchronized (self) {
            if (_connectionStateCallback == NULL) {
                BLELOG_DBG_PRINT(@"_connectionStateCallback is NULL.");
                break;
            }

            handle = NULL;
            CFUUIDRef uuid = peripheral.UUID;
            if (uuid != NULL) {
                for (id key in _handleList) {
                    BluetoothHandle* bleh = [_handleList objectForKey:key];
                    if ([bleh isEqualPeripheralUUID:uuid]) {
                        handle = [key pointerValue];
                        break;
                    }
                }
            }

            connectionStateCallback = _connectionStateCallback;
            content = _connectionStateCallbackContent;
        }

        connectionStateCallback(state, handle, content);
    } while(0);

    ICSLOG_FUNC_END;
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager*)central
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:centralManagerDidUpdateState"
    ICSLOG_FUNC_BEGIN;

    /* If central is nil, nothing occurs. */
    switch (central.state) {
        case CBCentralManagerStatePoweredOn:
            BLELOG_DBG_PRINT(@"CBCentralManager state PoweredOn.");
            break;

        case CBCentralManagerStatePoweredOff:
            BLELOG_DBG_PRINT(@"CBCentralManager state PoweredOff.");
            break;

        case CBCentralManagerStateResetting:
            BLELOG_DBG_PRINT(@"CBCentralManager state Resetting.");
            break;

        case CBCentralManagerStateUnauthorized:
            BLELOG_DBG_PRINT(@"CBCentralManager state Unauthorized.");
            break;

        case CBCentralManagerStateUnsupported:
            BLELOG_DBG_PRINT(@"CBCentralManager state Unsupported.");
            break;

        case CBCentralManagerStateUnknown:
            BLELOG_DBG_PRINT(@"CBCentralManager state Unknown.");
            break;

        default:
            BLELOG_DBG_PRINT(@"CBCentralManager unknown state: %ld.",
                             (long)central.state);
            break;
    }

    /* If _semUpdateState is nil, nothing occurs. */
    [_semUpdateState signal];

    ICSLOG_FUNC_END;
}

- (void)centralManager:(CBCentralManager*)central
    didRetrieveConnectedPeripherals:(NSArray*)peripherals
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:didRetrieveConnectedPeripherals"
    ICSLOG_FUNC_BEGIN;

    @synchronized (self) {
        if ((_connectingHandle != nil) && (_peripheralUUID != NULL)) {
            for (CBPeripheral* peripheral in peripherals) {
                BLELOG_DBG_PRINT(@"A connected peripheral: %@", peripheral);
                CFUUIDBytes uuidBytes1 = CFUUIDGetUUIDBytes(peripheral.UUID);
                CFUUIDBytes uuidBytes2 = CFUUIDGetUUIDBytes(_peripheralUUID);
                if (CMP_UUID(uuidBytes1, uuidBytes2)) {
                    errcode = ICS_ERROR_BUSY;
                    BLELOG_ERR_PRINT(errcode,
                                     @"The UUID is already connected.");
                }
            }

            [_semConnect signal];
        }
    }

    ICSLOG_FUNC_END;
}

- (void)centralManager:(CBCentralManager*)central
didRetrievePeripherals:(NSArray*)peripherals
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:didRetrievePeripherals"
    ICSLOG_FUNC_BEGIN;

    if (central == nil) {
        errcode = ICS_ERROR_IO;
        BLELOG_ERR_PRINT(errcode, @"central is nil.");
        [_semConnect signal];
        return;
    }

    if (peripherals.count == 0) {
        errcode = ICS_ERROR_IO;
        BLELOG_ERR_PRINT(errcode, @"No peripherals.");
        [_semConnect signal];
        return;
    }

    CBPeripheral* peripheral = peripherals[0];

    @synchronized (self) {
        if (_connectingHandle == nil) {
            BLELOG_DBG_PRINT(@"The connection process has ended.");
            return;
        }

        CBPeripheral* hPeripheral = [_connectingHandle getPeripheral];
        if (hPeripheral != nil) {
            BLELOG_DBG_PRINT(@"A peripheral is already discovered: %@",
                             peripheral);
            return;
        }

        [_connectingHandle setPeripheral:peripheral];
    }

    if (_connectOptionEnable == YES) {
        BLELOG_DBG_PRINT(@"connectPeripheral:%@ options:%@",
                         peripheral,
                         _connectOption);
        [central connectPeripheral:peripheral options:_connectOption];
    } else {
        BLELOG_DBG_PRINT(@"connectPeripheral:%@ options:nil", peripheral);
        [central connectPeripheral:peripheral options:nil];
    }

    ICSLOG_FUNC_END;
}

- (void)centralManager:(CBCentralManager*)central
 didDiscoverPeripheral:(CBPeripheral*)peripheral
     advertisementData:(NSDictionary*)advertisementData
                  RSSI:(NSNumber*)RSSI
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:didDiscoverPeripheral"
    ICSLOG_FUNC_BEGIN;

    if (central == nil) {
        errcode = ICS_ERROR_IO;
        BLELOG_ERR_PRINT(errcode, @"central is nil.");
        [_semConnect signal];
        return;
    }

    if (peripheral == nil) {
        errcode = ICS_ERROR_IO;
        BLELOG_ERR_PRINT(errcode, @"The discovered peripheral is nil.");
        [central stopScan];
        [_semConnect signal];
        return;
    }

    if (advertisementData == nil) {
        errcode = ICS_ERROR_IO;
        BLELOG_ERR_PRINT(errcode, @"advertisementData is nil.");
        [central stopScan];
        [_semConnect signal];
        return;
    }

    if (RSSI == nil) {
        errcode = ICS_ERROR_IO;
        BLELOG_ERR_PRINT(errcode, @"RSSI is nil.");
        [central stopScan];
        [_semConnect signal];
        return;
    }

    @synchronized (self) {
        if (_connectingHandle == nil) {
            BLELOG_DBG_PRINT(@"connect method has been ended.");
            return;
        }

        CBPeripheral* hPeripheral = [_connectingHandle getPeripheral];
        if (hPeripheral != nil) {
            BLELOG_DBG_PRINT(@"A peripheral is already discovered: %@",
                             peripheral);
            return;
        }

        CFUUIDRef uuid = peripheral.UUID;

        BLELOG_DBG_PRINT(@"UUID:%@ advertisementData:%@ RSSI:%@",
                         uuid,
                         [advertisementData description],
                         RSSI);

        if (_RSSIMinForDiscoverPeripheral != BLE_INVALID_RSSI) {
            SInt32 rssi = [RSSI intValue];
            if (rssi < _RSSIMinForDiscoverPeripheral) {
                BLELOG_DBG_PRINT(
                  @"RSSI(%d) is smaller than the specified parameter rssi(%d).",
                  (int)rssi,
                  (int)_RSSIMinForDiscoverPeripheral);
                return;
            }
        }

        if (uuid != NULL) {
            for (id key in _handleList) {
                BluetoothHandle* bleh = [_handleList objectForKey:key];
                if ([bleh isEqualPeripheralUUID:uuid]) {
                    BLELOG_DBG_PRINT(@"The same peripheral is already opened.");
                    return;
                }
            }
        }

        [central stopScan];

        [_connectingHandle setPeripheral:peripheral];
    }

    if (_connectOptionEnable == YES) {
        BLELOG_DBG_PRINT(@"connectPeripheral:%@ options:%@",
                         peripheral,
                         _connectOption);
        [central connectPeripheral:peripheral options:_connectOption];
    } else {
        BLELOG_DBG_PRINT(@"connectPeripheral:%@ options:nil", peripheral);
        [central connectPeripheral:peripheral options:nil];
    }

    ICSLOG_FUNC_END;
}

- (void)centralManager:(CBCentralManager*)central
  didConnectPeripheral:(CBPeripheral*)peripheral
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:didConnectPeripheral"
    UInt32 rc;
    ICSLOG_FUNC_BEGIN;

    dispatch_async(GLOBAL_QUEUE, ^{
        @autoreleasepool {
            [self callConnectionStateCallback:peripheral
                                        state:BLEConnectionStateConnected];
        }
    });

    @synchronized (self) {
        if (_connectingHandle != nil) {
            rc = [_connectingHandle prepareServices:_serviceUUID
                                         readChUUID:_readUUID
                                       notifyChUUID:_notifyUUID
                                        writeChUUID:_writeUUID];
            if (rc != ICS_ERROR_SUCCESS) {
                errcode = ICS_ERROR_IO;
                BLELOG_ERR_PRINT(errcode, @"prepareServices failed.");
                [_semConnect signal];
                return;
            }
        }
    }

    ICSLOG_FUNC_END;
}

- (void)centralManager:(CBCentralManager*)central
    didFailToConnectPeripheral:(CBPeripheral*)peripheral
    error:(NSError*)error
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:didFailToConnectPeripheral"
    ICSLOG_FUNC_BEGIN;

    if (error != nil) {
        BLELOG_DBG_PRINT(@"%@", error.localizedDescription);
    }

    @synchronized (self) {
        if (_connectingHandle != nil) {
            errcode = ICS_ERROR_IO;
            BLELOG_ERR_PRINT(errcode,
                             @"The connection failed while openning.");
            [_semConnect signal];
        }
    }

    ICSLOG_FUNC_END;
}

- (void)centralManager:(CBCentralManager*)central
    didDisconnectPeripheral:(CBPeripheral*)peripheral
    error:(NSError*)error
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:didDisconnectPeripheral"
    ICSLOG_FUNC_BEGIN;

    if (error != nil) {
        BLELOG_DBG_PRINT(@"%@", error.localizedDescription);
    }

    dispatch_async(GLOBAL_QUEUE, ^{
        @autoreleasepool {
            [self callConnectionStateCallback:peripheral
                                        state:BLEConnectionStateDisconnected];
        }
    });

    @synchronized (self) {
        if (_connectingHandle != nil) {
            if ([_connectingHandle isEqualPeripheralUUID:peripheral.UUID]) {
                errcode = ICS_ERROR_IO;
                BLELOG_ERR_PRINT(errcode,
                                 @"A disconnection occurred while openning.");
                [_semConnect signal];
            }
        }
    }

    ICSLOG_FUNC_END;
}

#pragma mark - BluetoothHandleDelegate

- (void)bluetoothHandle:(BluetoothHandle*)bluetoothHandle
     didPrepareServices:(NSError*)error
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Bluetooth:didPrepareServices"
    ICSLOG_FUNC_BEGIN;

    @synchronized (self) {
        if (_connectingHandle != nil) {
            if (error != nil) {
                errcode = ICS_ERROR_IO;
            }

            [_semConnect signal];
        }
    }

    ICSLOG_FUNC_END;
}

@end
