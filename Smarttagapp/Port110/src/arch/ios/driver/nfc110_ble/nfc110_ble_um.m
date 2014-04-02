/**
 * \brief    NFC Port-110 BLE Driver (iOS)
 * \date     2013/08/26
 * \author   Copyright 2013 Sony Corporation
 */

#undef ICSLOG_MODULE
#define ICSLOG_MODULE "DBb"

#include "ics_types.h"
#include "ics_error.h"
#include "icslib_chk.h"
#include "icslog.h"
#include "utl.h"
#include "nfc110_ble.h"

#import "Bluetooth.h"

/* --------------------------------
 * Constant
 * -------------------------------- */

#define NFC110_BLE_COMMAND_BUF_LEN \
    (8 + (3 + NFC110_MAX_TRANSMIT_DATA_LEN) + 2)
#define NFC110_BLE_MAX_BULK_LEN             20U
#define NFC110_ALARM_PACKET_MIN_SIZE        3U

/* --------------------------------
 * Prototype Declaration
 * -------------------------------- */

static void nfc110_ble_raw_on_notify(
    NSData* data,
    id content);

static void nfc110_ble_raw_on_notify2(
    NSData* data,
    id content);

static void nfc110_ble_raw_on_change_connection_state(
    BLEConnectionState state,
    void* handle,
    id content);

static void nfc110_ble_raw_on_change_connection_state2(
    BLEConnectionState state,
    void* handle,
    id content);

/* --------------------------------
 * Struct Declaration
 * -------------------------------- */

typedef struct {
    nfc110_notify_callback2_func_t callback;
    void* obj;
} nfc110_ble_raw_notify_callback2_content_t;

typedef struct {
    nfc110_on_change_conn_status2_func_t callback;
    void* obj;
} nfc110_ble_raw_change_conn_status_callback2_content_t;

/* --------------------------------
 * Private data
 * -------------------------------- */

static Bluetooth* s_bluetooth;

/* ------------------------
 * Exported
 * ------------------------ */

/**
 * This function opens a port to the device.
 *
 * \param  handle                [OUT] The handle to access the port.
 * \param  port_name              [IN] The port name to open.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_BUSY              Device busy.
 * \retval ICS_ERROR_TIMEOUT           Connection timeout.
 * \retval ICS_ERROR_IO                Other driver error.
 */
UINT32 nfc110_ble_raw_open(
    ICS_HANDLE* handle,
    const char* port_name)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_ble_raw_open"
    @autoreleasepool {
        UINT32 rc;
        unsigned int port_name_len;
        void* ret_handle;
        NSString* uuid;
        ICSLOG_FUNC_BEGIN;

        /* check the prameters */
        ICSLIB_CHKARG_NE(handle, NULL, ICS_ERROR_INVALID_PARAM);
        ICSLIB_CHKARG_NE(port_name, NULL, ICS_ERROR_INVALID_PARAM);

        port_name_len = utl_strlen(port_name);
        ICSLIB_CHKARG_LE(port_name_len, 128, ICS_ERROR_INVALID_PARAM);

        ICSLOG_DBG_PTR(handle);
        ICSLOG_DBG_STR(port_name);
        ICSLOG_DBG_UINT(port_name_len);

        if (s_bluetooth == nil) {
            ICSLOG_DBG_PRINT(("Begin alloc: Bluetooth\n"));
            s_bluetooth = [[Bluetooth alloc] init];
            ICSLOG_DBG_PRINT(("End alloc: Bluetooth\n"));
            if (s_bluetooth == nil) {
                rc = ICS_ERROR_IO;
                ICSLOG_ERR_STR(rc, "Bluetooth initialization failed.");
                return rc;
            }
        }

        ICSLOG_DBG_PRINT(("Begin alloc: uuid\n"));
        uuid = [NSString stringWithUTF8String:port_name];
        ICSLOG_DBG_PRINT(("End alloc: uuid\n"));
        if (uuid == nil) {
            rc = ICS_ERROR_IO;
            ICSLOG_ERR_STR(rc, "uuid initialization failed.");
            return rc;
        }

        ret_handle = [s_bluetooth open:uuid];
        if (ret_handle == NULL) {
            if (s_bluetooth.errcode == ICS_ERROR_BUSY) {
                rc = ICS_ERROR_BUSY;
            } else if (s_bluetooth.errcode == ICS_ERROR_TIMEOUT) {
                rc = ICS_ERROR_TIMEOUT;
            } else {
                rc = ICS_ERROR_IO;
            }
            ICSLOG_ERR_STR(rc, "Bluetooth open");
            return rc;
        }

        *handle = ret_handle;

        ICSLOG_DBG_PTR(*handle);

        ICSLOG_FUNC_END;
        return ICS_ERROR_SUCCESS;
    }
}

/**
 * This function closes the port.
 *
 * \param  handle                 [IN] The handle to access the port.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_IO                Other driver error.
 */
UINT32 nfc110_ble_raw_close(
    ICS_HANDLE handle)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_ble_raw_close"
    @autoreleasepool {
        UINT32 rc;
        ICSLOG_FUNC_BEGIN;

        /* check the prameters */
        ICSLIB_CHKARG_NE(s_bluetooth, nil, ICS_ERROR_IO);
        ICSLIB_CHKARG_NE(handle, NULL, ICS_ERROR_INVALID_PARAM);
        ICSLIB_CHKARG_NE(handle, ICS_INVALID_HANDLE, ICS_ERROR_INVALID_PARAM);

        ICSLOG_DBG_PTR(handle);

        rc = [s_bluetooth close:handle];
        if (rc != ICS_ERROR_SUCCESS) {
            rc = ICS_ERROR_IO;
            ICSLOG_ERR_STR(rc, "Bluetooth close");
            return rc;
        }

        ICSLOG_FUNC_END;
        return ICS_ERROR_SUCCESS;
    }
}

/*
 * This function writes data to the device.
 *
 * \param  handle                 [IN] The handle to access the port.
 * \param  data                   [IN] The data to write.
 * \param  data_len               [IN] The length of the data.
 * \param  time0                  [IN] The base time for time-out. (ms)
 * \param  timeout                [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 */
UINT32 nfc110_ble_raw_write(
    ICS_HANDLE handle,
    const UINT8* data,
    UINT32 data_len,
    UINT32 time0,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_ble_raw_write"
    @autoreleasepool {
        UINT32 rc;
        NSInteger res;
        unsigned int nfc110_bulk_len;
        UINT32 nwritten;
        UINT32 write_len;
        UINT32 current_time;
        UINT32 rest_timeout;
        NSData* command;
        ICSLOG_FUNC_BEGIN;

        /* check the prameters */
        ICSLIB_CHKARG_NE(s_bluetooth, nil, ICS_ERROR_IO);
        ICSLIB_CHKARG_NE(handle, NULL, ICS_ERROR_INVALID_PARAM);
        ICSLIB_CHKARG_NE(handle, ICS_INVALID_HANDLE, ICS_ERROR_INVALID_PARAM);
        ICSLIB_CHKARG_NE(data, NULL, ICS_ERROR_INVALID_PARAM);

        ICSLOG_DBG_PTR(handle);
        ICSLOG_DBG_UINT(data_len);
        ICSLOG_DUMP(data, data_len);
        ICSLOG_DBG_UINT(time0);
        ICSLOG_DBG_UINT(timeout);

        nfc110_bulk_len = NFC110_BLE_MAX_BULK_LEN;

        ICSLOG_DBG_UINT(nfc110_bulk_len);

        nwritten = 0;
        do {
            rest_timeout = utl_get_rest_timeout(time0, timeout, &current_time);
            if (rest_timeout == 0) {
                rc = ICS_ERROR_TIMEOUT;
                ICSLOG_ERR_STR(rc, "Time-out.");
                return rc;
            }

            write_len = (data_len - nwritten);
            if (write_len > nfc110_bulk_len) {
                write_len = nfc110_bulk_len;
            }

            command = [NSData dataWithBytesNoCopy:(void*)(data + nwritten)
                                           length:write_len
                                     freeWhenDone:NO];

            res = [s_bluetooth write:handle
                             command:command
                        timeoutMsecs:rest_timeout];
            if (res < 0) {
                if (s_bluetooth.errcode == ICS_ERROR_TIMEOUT) {
                    rc = ICS_ERROR_TIMEOUT;
                } else {
                    rc = ICS_ERROR_IO;
                }
                ICSLOG_ERR_STR(rc, "Bluetooth write");
                return rc;
            }
            nwritten += res;
        } while (nwritten < data_len);

        ICSLOG_FUNC_END;
        return ICS_ERROR_SUCCESS;
    }
}

/**
 * This function reads data from the device.
 *
 * \param  handle                 [IN] The handle to access the port.
 * \param  min_read_len           [IN] The minimum length of read data.
 * \param  max_read_len           [IN] The maximum length of read data.
 * \param  data                  [OUT] The read data.
 * \param  read_len              [OUT] The length of read data or NULL.
 *                                     (NULL means reading the whole data)
 * \param  time0                  [IN] The base time for time-out. (ms)
 * \param  timeout                [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_BUF_OVERFLOW      Response buffer overflow.
 */
UINT32 nfc110_ble_raw_read(
    ICS_HANDLE handle,
    UINT32 min_read_len,
    UINT32 max_read_len,
    UINT8* data,
    UINT32* read_len,
    UINT32 time0,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_ble_raw_read"
    @autoreleasepool {
        UINT32 rc;
        NSInteger res;
        unsigned int nfc110_bulk_len;
        UINT32 nread;
        UINT32 n;
        UINT32 current_time;
        UINT32 rest_timeout;
        NSData* response;
        ICSLOG_FUNC_BEGIN;

        /* check the prameters */
        ICSLIB_CHKARG_NE(s_bluetooth, nil, ICS_ERROR_IO);
        ICSLIB_CHKARG_NE(handle, NULL, ICS_ERROR_INVALID_PARAM);
        ICSLIB_CHKARG_NE(handle, ICS_INVALID_HANDLE, ICS_ERROR_INVALID_PARAM);
        ICSLIB_CHKARG_NE(data, NULL, ICS_ERROR_INVALID_PARAM);
        ICSLIB_CHKARG_LE(min_read_len, max_read_len, ICS_ERROR_INVALID_PARAM);

        ICSLOG_DBG_PTR(handle);
        ICSLOG_DBG_UINT(max_read_len);
        ICSLOG_DBG_UINT(time0);
        ICSLOG_DBG_UINT(timeout);

        nfc110_bulk_len = NFC110_BLE_MAX_BULK_LEN;

        ICSLOG_DBG_UINT(nfc110_bulk_len);

        nread = 0;
        do {
            n = (max_read_len - nread);
            if (n > nfc110_bulk_len) {
                n = nfc110_bulk_len;
            }

            rest_timeout = utl_get_rest_timeout(time0, timeout, &current_time);
            if (rest_timeout == 0) {
                rc = ICS_ERROR_TIMEOUT;
                ICSLOG_ERR_STR(rc, "Time-out.");
                return rc;
            }

            res = [s_bluetooth read:handle
                           response:&response
                             length:n
                       timeoutMsecs:rest_timeout];
            if (res < 0) {
                if (s_bluetooth.errcode == ICS_ERROR_TIMEOUT) {
                    rc = ICS_ERROR_TIMEOUT;
                } else {
                    rc = ICS_ERROR_IO;
                }
                ICSLOG_ERR_STR(rc, "Bluetooth read");
                return rc;
            }
            if ((UINT32)res > n) {
                rc = ICS_ERROR_BUF_OVERFLOW;
                ICSLOG_ERR_STR(rc, "Buffer overflow.");
                return rc;
            }
            utl_memcpy(data + nread, [response bytes], res);

            nread += res;
        } while (nread < min_read_len);

        if (read_len != NULL) {
            *read_len = nread;
        }
        ICSLOG_DBG_UINT(nread);
        ICSLOG_DUMP(data, nread);

        ICSLOG_FUNC_END;
        return ICS_ERROR_SUCCESS;
    }
}

/**
 * This function clears the receiving queue of the BLE.
 *
 * \param  handle                 [IN] The handle to access the port.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_IO                Other driver error.
 */
UINT32 nfc110_ble_raw_clear_rx_queue(
    ICS_HANDLE handle)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_ble_raw_clear_rx_queue"
    @autoreleasepool {
        UINT32 rc;
        ICSLOG_FUNC_BEGIN;

        ICSLIB_CHKARG_NE(handle, NULL, ICS_ERROR_INVALID_PARAM);
        ICSLIB_CHKARG_NE(handle, ICS_INVALID_HANDLE, ICS_ERROR_INVALID_PARAM);

        ICSLOG_DBG_PTR(handle);

        rc = [s_bluetooth clearReceiveBuffer:handle];
        if (rc != ICS_ERROR_SUCCESS) {
            rc = ICS_ERROR_IO;
            ICSLOG_ERR_STR(rc, "Bluetooth clearReceiveBuffer");
            return rc;
        }

        ICSLOG_FUNC_END;
        return ICS_ERROR_SUCCESS;
    }
}

/**
 * This function waits until all data written to the BLE (no effect for BLE).
 *
 * \param  handle                 [IN] The handle to access the port.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 */
UINT32 nfc110_ble_raw_drain_tx_queue(
    ICS_HANDLE handle)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_ble_raw_drain_tx_queue"
    @autoreleasepool {
        ICSLOG_FUNC_BEGIN;

        ICSLIB_CHKARG_NE(handle, NULL, ICS_ERROR_INVALID_PARAM);
        ICSLIB_CHKARG_NE(handle, ICS_INVALID_HANDLE, ICS_ERROR_INVALID_PARAM);

        ICSLOG_DBG_PTR(handle);

        /* Do nothing. */

        ICSLOG_FUNC_END;
        return ICS_ERROR_SUCCESS;
    }
}

/**
 * This function resets the BLE device.
 *
 * \param  handle                 [IN] The handle to access the port.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_IO                Other driver error.
 */
UINT32 nfc110_ble_raw_reset(
    ICS_HANDLE handle)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_ble_raw_reset"
    @autoreleasepool {
        UINT32 rc;
        ICSLOG_FUNC_BEGIN;

        ICSLIB_CHKARG_NE(s_bluetooth, nil, ICS_ERROR_IO);
        ICSLIB_CHKARG_NE(handle, NULL, ICS_ERROR_INVALID_PARAM);
        ICSLIB_CHKARG_NE(handle, ICS_INVALID_HANDLE, ICS_ERROR_INVALID_PARAM);

        ICSLOG_DBG_PTR(handle);

        rc = [s_bluetooth reset:handle];
        if (rc != ICS_ERROR_SUCCESS) {
            rc = ICS_ERROR_IO;
            ICSLOG_ERR_STR(rc, "Bluetooth reset");
            return rc;
        }

        ICSLOG_FUNC_END;
        return ICS_ERROR_SUCCESS;
    }
}

/**
 * This function registers a notification callback function.
 *
 * \param  handle                 [IN] The handle to access the port.
 * \param  callback               [IN] The notification callback function.
 *                                     If NULL is specified, the registered
 *                                     callback function will be cleared.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_IO                Other driver error.
 */
UINT32 nfc110_ble_raw_register_notify_callback(
    ICS_HANDLE handle,
    nfc110_notify_callback callback)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_ble_raw_register_notify_callback"
    @autoreleasepool {
        UINT32 rc;
        NSValue* content;
        ICSLOG_FUNC_BEGIN;

        /* check the prameters */
        ICSLIB_CHKARG_NE(s_bluetooth, nil, ICS_ERROR_IO);
        ICSLIB_CHKARG_NE(handle, NULL, ICS_ERROR_INVALID_PARAM);
        ICSLIB_CHKARG_NE(handle, ICS_INVALID_HANDLE, ICS_ERROR_INVALID_PARAM);

        ICSLOG_DBG_PTR(handle);
        ICSLOG_DBG_PTR(callback);

        if (callback == NULL) {
            rc = [s_bluetooth registerNotifyCallback:handle
                                      notifyCallback:NULL
                                             content:nil];
        } else {
            ICSLOG_DBG_PRINT(("Begin alloc: content\n"));
            content = [NSValue valueWithPointer:callback];
            ICSLOG_DBG_PRINT(("End alloc: content\n"));
            if (content == nil) {
                rc = ICS_ERROR_IO;
                ICSLOG_ERR_STR(rc, "content initialization failed.");
                return rc;
            }

            rc = [s_bluetooth
                      registerNotifyCallback:handle
                              notifyCallback:nfc110_ble_raw_on_notify
                                     content:content];
        }
        if (rc != ICS_ERROR_SUCCESS) {
            rc = ICS_ERROR_IO;
            ICSLOG_ERR_STR(rc, "Bluetooth registerNotifyCallback");
            return rc;
        }

        ICSLOG_FUNC_END;
        return ICS_ERROR_SUCCESS;
    }
}

/**
 * This function registers a notification callback(2) function.
 *
 * \param  handle                 [IN] The handle to access the port.
 * \param  callback               [IN] The notify callback function.
 *                                     If NULL is specified, the registered
 *                                     callback function will be cleared.
 * \param  obj                    [IN] An user object which will be returned
 *                                     to the callback function.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_IO                Other driver error.
 */
UINT32 nfc110_ble_raw_register_notify_callback2(
    ICS_HANDLE handle,
    nfc110_notify_callback2_func_t callback,
    void* obj)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_ble_raw_register_notify_callback2"
    @autoreleasepool {
        UINT32 rc;
        nfc110_ble_raw_notify_callback2_content_t notify_callback2_content;
        NSValue* content;
        ICSLOG_FUNC_BEGIN;

        /* check the prameters */
        ICSLIB_CHKARG_NE(s_bluetooth, nil, ICS_ERROR_IO);
        ICSLIB_CHKARG_NE(handle, NULL, ICS_ERROR_INVALID_PARAM);
        ICSLIB_CHKARG_NE(handle, ICS_INVALID_HANDLE, ICS_ERROR_INVALID_PARAM);

        ICSLOG_DBG_PTR(handle);
        ICSLOG_DBG_PTR(callback);
        ICSLOG_DBG_PTR(obj);

        if (callback == NULL) {
            rc = [s_bluetooth registerNotifyCallback:handle
                                      notifyCallback:NULL
                                             content:nil];
        } else {
            notify_callback2_content.callback = callback;
            notify_callback2_content.obj = obj;

            ICSLOG_DBG_PRINT(("Begin alloc: content\n"));
            content =
                [NSValue
                 valueWithBytes:&notify_callback2_content
                 objCType:@encode(nfc110_ble_raw_notify_callback2_content_t)];
            ICSLOG_DBG_PRINT(("End alloc: content\n"));
            if (content == nil) {
                rc = ICS_ERROR_IO;
                ICSLOG_ERR_STR(rc, "content initialization failed.");
                return rc;
            }

            rc = [s_bluetooth
                      registerNotifyCallback:handle
                              notifyCallback:nfc110_ble_raw_on_notify2
                                     content:content];
        }
        if (rc != ICS_ERROR_SUCCESS) {
            rc = ICS_ERROR_IO;
            ICSLOG_ERR_STR(rc, "Bluetooth registerNotifyCallback");
            return rc;
        }

        ICSLOG_FUNC_END;
        return ICS_ERROR_SUCCESS;
    }
}

/**
 * This function registers a connection callback function.
 *
 * \param  callback               [IN] The connection callback function.
 *                                     If NULL is specified, the registered
 *                                     callback function will be cleared.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_IO                Other driver error.
 */
UINT32 nfc110_ble_raw_register_change_conn_status_callback(
    nfc110_on_change_conn_status callback)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_ble_raw_register_change_conn_status_callback"
    @autoreleasepool {
        UINT32 rc;
        NSValue* content;
        BOOL connect_option_enable;
        ICSLOG_FUNC_BEGIN;

        ICSLOG_DBG_PTR(callback);

        if (s_bluetooth == nil) {
            ICSLOG_DBG_PRINT(("Begin alloc: Bluetooth\n"));
            s_bluetooth = [[Bluetooth alloc] init];
            ICSLOG_DBG_PRINT(("End alloc: Bluetooth\n"));
            if (s_bluetooth == nil) {
                rc = ICS_ERROR_IO;
                ICSLOG_ERR_STR(rc, "Bluetooth initialization failed.");
                return rc;
            }
        }

        connect_option_enable = NO;

        if (callback == NULL) {
            connect_option_enable = NO;
            rc = [s_bluetooth registerConnectionStateCallback:NULL
                                                      content:nil];
        } else {
            connect_option_enable = YES;

            ICSLOG_DBG_PRINT(("Begin alloc: content\n"));
            content = [NSValue valueWithPointer:callback];
            ICSLOG_DBG_PRINT(("End alloc: content\n"));
            if (content == nil) {
                rc = ICS_ERROR_IO;
                ICSLOG_ERR_STR(rc, "content initialization failed.");
                return rc;
            }

            rc = [s_bluetooth registerConnectionStateCallback:
                  nfc110_ble_raw_on_change_connection_state
                                                      content:content];
        }
        if (rc != ICS_ERROR_SUCCESS) {
            rc = ICS_ERROR_IO;
            ICSLOG_ERR_STR(rc, "Bluetooth registerConnectionStateCallback");
            return rc;
        }

        s_bluetooth.connectOptionEnable = connect_option_enable;

        ICSLOG_DBG_INT(connect_option_enable);

        ICSLOG_FUNC_END;
        return ICS_ERROR_SUCCESS;
    }
}

/**
 * This function registers a connection callback(2) function.
 *
 * \param  callback               [IN] The connection callback function.
 *                                     If NULL is specified, the registered
 *                                     callback function will be cleared.
 * \param  obj                    [IN] An user object which will be returned
 *                                     to the callback function.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_IO                Other driver error.
 */
UINT32 nfc110_ble_raw_register_change_conn_status_callback2(
    nfc110_on_change_conn_status2_func_t callback,
    void* obj)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_ble_raw_register_change_conn_status_callback2"
    @autoreleasepool {
        UINT32 rc;
        BOOL connect_option_enable;
        nfc110_ble_raw_change_conn_status_callback2_content_t
            connection_state_callback_content;
        NSValue* content;
        ICSLOG_FUNC_BEGIN;

        ICSLOG_DBG_PTR(callback);
        ICSLOG_DBG_PTR(obj);

        if (s_bluetooth == nil) {
            ICSLOG_DBG_PRINT(("Begin alloc: Bluetooth\n"));
            s_bluetooth = [[Bluetooth alloc] init];
            ICSLOG_DBG_PRINT(("End alloc: Bluetooth\n"));
            if (s_bluetooth == nil) {
                rc = ICS_ERROR_IO;
                ICSLOG_ERR_STR(rc, "Bluetooth initialization failed.");
                return rc;
            }
        }

        connect_option_enable = NO;

        if (callback == NULL) {
            connect_option_enable = NO;
            rc = [s_bluetooth registerConnectionStateCallback:NULL
                                                      content:nil];
        } else {
            connect_option_enable = YES;

            connection_state_callback_content.callback = callback;
            connection_state_callback_content.obj = obj;

            ICSLOG_DBG_PRINT(("Begin alloc: content\n"));
            content =
             [NSValue
              valueWithBytes:&connection_state_callback_content
              objCType:
                @encode(nfc110_ble_raw_change_conn_status_callback2_content_t)];
            ICSLOG_DBG_PRINT(("End alloc: content\n"));
            if (content == nil) {
                rc = ICS_ERROR_IO;
                ICSLOG_ERR_STR(rc, "content initialization failed.");
                return rc;
            }

            rc = [s_bluetooth registerConnectionStateCallback:
                  nfc110_ble_raw_on_change_connection_state2
                                                      content:content];
        }
        if (rc != ICS_ERROR_SUCCESS) {
            rc = ICS_ERROR_IO;
            ICSLOG_ERR_STR(rc, "Bluetooth registerConnectionStateCallback");
            return rc;
        }

        s_bluetooth.connectOptionEnable = connect_option_enable;

        ICSLOG_DBG_INT(connect_option_enable);

        ICSLOG_FUNC_END;
        return ICS_ERROR_SUCCESS;
    }
}

/**
 * This function sets parameters for the next open.
 *
 * \param  cm_init_timeout        [IN] The time-out period for CBCentralManager
 *                                     initialization proccessing while
 *                                     connecting.
 * \param  rssi                   [IN] RSSI for discovering peripheral. The RSSI
 *                                     of the discovered peripheral is equal to
 *                                     or larger than rssi.
 * \param  readch_timeout         [IN] The time-out period for setNotifyValue
 *                                     method with read characteristic.
 * \param  notifych_timeout       [IN] The time-out period for setNotifyValue
 *                                     method with notify characteristic.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_IO                Other driver error.
 */
UINT32 nfc110_ble_raw_set_cb_parameter(
    UINT32 cm_init_timeout,
    INT32 rssi,
    UINT32 readch_timeout,
    UINT32 notifych_timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_ble_raw_set_cb_parameter"
    @autoreleasepool {
        UINT32 rc;
        ICSLOG_FUNC_BEGIN;

        ICSLOG_DBG_UINT(cm_init_timeout);
        ICSLOG_DBG_INT(rssi);
        ICSLOG_DBG_UINT(readch_timeout);
        ICSLOG_DBG_UINT(notifych_timeout);

        if (s_bluetooth == nil) {
            ICSLOG_DBG_PRINT(("Begin alloc: Bluetooth\n"));
            s_bluetooth = [[Bluetooth alloc] init];
            ICSLOG_DBG_PRINT(("End alloc: Bluetooth\n"));
            if (s_bluetooth == nil) {
                rc = ICS_ERROR_IO;
                ICSLOG_ERR_STR(rc, "Bluetooth initialization failed.");
                return rc;
            }
        }

        if (cm_init_timeout != 0xffffffff) {
            s_bluetooth.initTimeout = cm_init_timeout;
        }

        if (rssi != 0xffffffff) {
            s_bluetooth.RSSIMinForDiscoverPeripheral = rssi;
        }

        if (readch_timeout != 0xffffffff) {
            s_bluetooth.readChTimeout = readch_timeout;
        }

        if (notifych_timeout != 0xffffffff) {
            s_bluetooth.notifyChTimeout = notifych_timeout;
        }

        ICSLOG_FUNC_END;
        return ICS_ERROR_SUCCESS;
    }
}

/**
 * This function gets BLE attributes.
 *
 * \param  handle                 [IN] The handle to get the attributes.
 * \param  arg                   [OUT] The buffer to be set the attributes.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_IO                Other driver error.
 */
UINT32 nfc110_ble_raw_get_attribute(
    ICS_HANDLE handle,
    void* arg)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_ble_raw_get_attribute"
    @autoreleasepool {
        UINT32 rc;
        NSString* uuid;
        ICSLOG_FUNC_BEGIN;

        /* check the prameters */
        ICSLIB_CHKARG_NE(s_bluetooth, nil, ICS_ERROR_IO);
        ICSLIB_CHKARG_NE(handle, NULL, ICS_ERROR_INVALID_PARAM);
        ICSLIB_CHKARG_NE(handle, ICS_INVALID_HANDLE, ICS_ERROR_INVALID_PARAM);
        ICSLIB_CHKARG_NE(arg, NULL, ICS_ERROR_INVALID_PARAM);

        ICSLOG_DBG_PTR(handle);
        ICSLOG_DBG_PTR(arg);

        rc = [s_bluetooth getPeripheralUUID:handle uuid:&uuid];
        if (rc != ICS_ERROR_SUCCESS) {
            rc = ICS_ERROR_IO;
            ICSLOG_ERR_STR(rc, "Bluetooth getPeripheralUUID");
            return rc;
        }

        const char* uuidCStr = [uuid UTF8String];
        if (uuidCStr == NULL) {
            rc = ICS_ERROR_IO;
            ICSLOG_ERR_STR(rc, "uuid returns NULL string.");
            return rc;
        }

        utl_memcpy(arg, uuidCStr, uuid.length + 1);

        ICSLOG_DBG_STR(arg);

        ICSLOG_FUNC_END;
        return ICS_ERROR_SUCCESS;
    }
}

/* ------------------------
 * Internal
 * ------------------------ */

/* ------------------------
 * Callback
 * ------------------------ */

/**
 * This function receives notification callbacks from the device,
 * and calls nfc110_notify_callback.
 *
 * \param  data                   [IN] The data of the callback.
 * \param  content                [IN] notify_callback.
 */
static void nfc110_ble_raw_on_notify(
    NSData* data,
    id content)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_ble_raw_on_notify"
    @autoreleasepool {
        UINT32 rc;
        nfc110_notify_callback callback;
        const UINT8* data_bytes;
        UINT8 cl_dcs;
        ICSLOG_FUNC_BEGIN;

        /* check the prameters */
        if (data == nil) {
            ICSLOG_ERR_STR(ICS_ERROR_INVALID_PARAM, "data is nil");
            return;
        }
        if (content == nil) {
            ICSLOG_ERR_STR(ICS_ERROR_IO, "content is nil");
            return;
        }

        callback = [content pointerValue];

        ICSLOG_DBG_PTR(callback);

        if (callback == NULL) {
            ICSLOG_ERR_STR(ICS_ERROR_IO, "callback is NULL");
            return;
        }

        if (data.length < NFC110_ALARM_PACKET_MIN_SIZE) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Invalid notify response");
            callback(rc, 1, NULL);
            return;
        }

        data_bytes = [data bytes];

        cl_dcs = 0;
        for (int i = 0; i < data.length; i++) {
            cl_dcs += data_bytes[i];
        }
        if (cl_dcs != 0) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "DCS calculation error");
            callback(rc, 1, NULL);
            return;
        }

        callback(ICS_ERROR_SUCCESS, 1, NULL);

        ICSLOG_FUNC_END;
    }
}

/**
 * This function receives notification callbacks from the device,
 * and calls nfc110_notify_callback2.
 *
 * \param  data                   [IN] The data of the callback.
 * \param  content                [IN] notify_callback2, obj.
 */
static void nfc110_ble_raw_on_notify2(
    NSData* data,
    id content)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_ble_raw_on_notify2"
    @autoreleasepool {
        UINT32 rc;
        nfc110_ble_raw_notify_callback2_content_t notify_callback2_content;
        nfc110_notify_callback2_func_t callback;
        void* obj;
        const UINT8* data_bytes;
        UINT8 cl_dcs;
        ICSLOG_FUNC_BEGIN;

        /* check the prameters */
        if (data == nil) {
            ICSLOG_ERR_STR(ICS_ERROR_INVALID_PARAM, "data is nil");
            return;
        }
        if (content == nil) {
            ICSLOG_ERR_STR(ICS_ERROR_IO, "content is nil");
            return;
        }

        [content getValue:&notify_callback2_content];
        callback = notify_callback2_content.callback;
        obj = notify_callback2_content.obj;

        ICSLOG_DBG_PTR(callback);
        ICSLOG_DBG_PTR(obj);

        if (callback == NULL) {
            ICSLOG_ERR_STR(ICS_ERROR_IO, "callback is NULL");
            return;
        }

        if (data.length < NFC110_ALARM_PACKET_MIN_SIZE) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Invalid notify response");
            callback(obj, rc, 1, NULL);
            return;
        }

        data_bytes = [data bytes];

        cl_dcs = 0;
        for (int i = 0; i < data.length; i++) {
            cl_dcs += data_bytes[i];
        }
        if (cl_dcs != 0) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "DCS calculation error");
            callback(obj, rc, 1, NULL);
            return;
        }

        callback(obj, ICS_ERROR_SUCCESS, 1, NULL);

        ICSLOG_FUNC_END;
    }
}

/**
 * This function receives connection state callbacks,
 * and calls nfc110_on_change_conn_status.
 *
 * \param  state                  [IN] The state of the connection.
 * \param  handle                 [IN] The handle of the state changed device.
 * \param  content                [IN] nfc110_on_change_conn_status.
 */
static void nfc110_ble_raw_on_change_connection_state(
    BLEConnectionState state,
    void* handle,
    id content)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_ble_raw_on_change_connection_state"
    @autoreleasepool {
        nfc110_on_change_conn_status callback;
        ICSLOG_FUNC_BEGIN;

        ICSLOG_DBG_INT(state);
        ICSLOG_DBG_PTR(handle);

        /* check the prameters */
        if (content == nil) {
            ICSLOG_ERR_STR(ICS_ERROR_IO, "content is nil");
            return;
        }

        callback = [content pointerValue];

        ICSLOG_DBG_PTR(callback);

        if (callback == NULL) {
            ICSLOG_ERR_STR(ICS_ERROR_IO, "callback is NULL");
            return;
        }

        switch (state) {
            case BLEConnectionStateConnected:{
                callback(NFC110_CONN_STATUS_CONNECTION,
                         (ICS_HANDLE)handle,
                         NULL);
                break;
            }

            case BLEConnectionStateDisconnected:{
                callback(NFC110_CONN_STATUS_DISCONNECTION,
                         (ICS_HANDLE)handle,
                         NULL);
                break;
            }

            default:{
                ICSLOG_ERR_STR(ICS_ERROR_IO, "Unknown connection state");
                return;
            }
        }

        ICSLOG_FUNC_END;
    }
}

/**
 * This function receives connection state callbacks,
 * and calls nfc110_on_change_conn_status2.
 *
 * \param  state                  [IN] The state of the connection.
 * \param  handle                 [IN] The handle of the state changed device.
 * \param  content                [IN] nfc110_on_change_conn_status2, obj.
 */
static void nfc110_ble_raw_on_change_connection_state2(
    BLEConnectionState state,
    void* handle,
    id content)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_ble_raw_on_change_connection_state2"
    @autoreleasepool {
        nfc110_ble_raw_change_conn_status_callback2_content_t
            connection_state_callback_content;
        nfc110_on_change_conn_status2_func_t callback;
        void* obj;
        ICSLOG_FUNC_BEGIN;

        ICSLOG_DBG_INT(state);
        ICSLOG_DBG_PTR(handle);

        /* check the prameters */
        if (content == nil) {
            ICSLOG_ERR_STR(ICS_ERROR_IO, "content is nil");
            return;
        }

        [content getValue:&connection_state_callback_content];
        callback = connection_state_callback_content.callback;
        obj = connection_state_callback_content.obj;

        ICSLOG_DBG_PTR(callback);
        ICSLOG_DBG_PTR(obj);

        if (callback == NULL) {
            ICSLOG_ERR_STR(ICS_ERROR_IO, "callback is NULL");
            return;
        }

        switch (state) {
            case BLEConnectionStateConnected:{
                callback(obj,
                         NFC110_CONN_STATUS_CONNECTION,
                         (ICS_HANDLE)handle,
                         NULL);
                break;
            }

            case BLEConnectionStateDisconnected:{
                callback(obj,
                         NFC110_CONN_STATUS_DISCONNECTION,
                         (ICS_HANDLE)handle,
                         NULL);
                break;
            }

            default:{
                ICSLOG_ERR_STR(ICS_ERROR_IO, "Unknown connection state");
                return;
            }
        }

        ICSLOG_FUNC_END;
    }
}
