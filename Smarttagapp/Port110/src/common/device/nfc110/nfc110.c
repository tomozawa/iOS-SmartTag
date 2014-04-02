/**
 * \brief    NFC Port-110 Driver
 * \date     2013/11/28
 * \author   Copyright 2013 Sony Corporation
 */

#undef ICSLOG_MODULE
#define ICSLOG_MODULE "DBC"

#include "ics_types.h"
#include "ics_error.h"
#include "icslib_chk.h"
#include "icslog.h"
#include "utl.h"

#include "nfc110.h"

/* --------------------------------
 * Constant
 * -------------------------------- */

#define NFC110_MAX_COMMAND_LEN          (3 + NFC110_MAX_TRANSMIT_DATA_LEN)
#define NFC110_MAX_RESPONSE_LEN         (3 + NFC110_MAX_RECEIVE_DATA_LEN)
#define NFC110_MAX_RF_COMMAND_LEN       290

#define NFC110_COMMAND_BUF_LEN          (8 + NFC110_MAX_COMMAND_LEN + 2)
#define NFC110_COMMAND_POS              8
#define NFC110_RESPONSE_POS             8

#define NFC110_COMMAND_TYPE_LEN         8

#define NFC110_DEFAULT_SPEED            NFC110_BLE_SPEED

#define NFC110_DEFAULT_MODE             NFC110_MODE_INITIATOR
#define NFC110_DEFAULT_RF_RBT_TX        NFC110_RBT_INITIATOR_ISO18092_212K
#define NFC110_DEFAULT_RF_RBT_RX        NFC110_RBT_INITIATOR_ISO18092_212K
#define NFC110_DEFAULT_RF_SPEED_TX      NFC110_RF_INITIATOR_ISO18092_212K
#define NFC110_DEFAULT_RF_SPEED_RX      NFC110_RF_INITIATOR_ISO18092_212K

#define NFC110_CANCEL_COMMAND_ACK_TIMEOUT                   500  /* ms */
#define NFC110_CANCEL_COMMAND_PURGE_TIMEOUT                 2000 /* ms */
#define NFC110_CANCEL_COMMAND_GET_COMMAND_TYPE_TIME_OUT     1500 /* ms */

/* the time until a finish to send a 1013bytes data at 400bps. */
#define NFC110_CANCEL_COMMAND_SWEEP_TIME_OUT                26000 /* ms */

/* --------------------------------
 * Prototype Declaration
 * -------------------------------- */

static UINT32 nfc110_get_command_type(
    ICS_HW_DEVICE* nfc110,
    UINT8 cmd_type[NFC110_COMMAND_TYPE_LEN],
    UINT32 timeout);

static UINT32 nfc110_execute_command_internal(
    ICS_HW_DEVICE* nfc110,
    UINT8 command_buf[NFC110_COMMAND_BUF_LEN],
    UINT32 command_len,
    UINT32* response_pos,
    UINT32* response_len,
    UINT32 timeout);

static UINT32 nfc110_sweep(
    ICS_HW_DEVICE* nfc110);

static UINT8 nfc110_calc_dcs(
    const UINT8* data,
    UINT32 data_len);

static UINT32 nfc110_convert_dev_status(
    UINT8 status);

static UINT32 nfc110_convert_rf_status(
    UINT32 status);

/* --------------------------------
 * Function
 * -------------------------------- */

/* ------------------------
 * Macro
 * ------------------------ */

#define NFC110_ACK_TIME(nfc110) ((nfc110)->priv_value)
#define NFC110_RAW_FUNC(nfc110) ((icsdrv_raw_func_t*)((nfc110)->priv_data))
#define NFC110_RAW_EXT_FUNC(nfc110) \
    ((nfc110_raw_ext_func_t*)(NFC110_RAW_FUNC(nfc110)->ext))

/* ------------------------
 * Exported
 * ------------------------ */

/**
 * This function initializes the driver.
 *
 * \param  nfc110                [OUT] Handle to access the port.
 * \param  raw_func               [IN] Raw driver functions.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 */
UINT32 nfc110_initialize(
    ICS_HW_DEVICE* nfc110,
    const icsdrv_raw_func_t* raw_func)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_initialize"
    ICSLOG_FUNC_BEGIN;

    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(raw_func, NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_PTR(raw_func);

    nfc110->priv_data = (void*)raw_func;

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function opens a port to the device.
 *
 * \param  nfc110                [OUT] Handle to access the port.
 * \param  port_name              [IN] The port name to open.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_BUSY              Device busy.
 * \retval ICS_ERROR_PERMISSION        Permission denied.
 * \retval ICS_ERROR_TIMEOUT           Connection timeout.
 * \retval ICS_ERROR_IO                Other driver error.
 */
UINT32 nfc110_open(
    ICS_HW_DEVICE* nfc110,
    const char* port_name)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_open"
    UINT32 rc;
    ICSLOG_FUNC_BEGIN;

    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(port_name, NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_STR(port_name);

    /* open the device */
    if (NFC110_RAW_FUNC(nfc110)->open != NULL) {
        rc = NFC110_RAW_FUNC(nfc110)->open(&(nfc110->handle), port_name);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc, "icsdrv_raw_func->open()");
            return rc;
        }
    }

    if (NFC110_RAW_FUNC(nfc110)->set_speed != NULL) {
        rc = NFC110_RAW_FUNC(nfc110)->set_speed(nfc110->handle,
                                                NFC110_DEFAULT_SPEED);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc, "icsdrv_raw_func->set_speed()");
            if (NFC110_RAW_FUNC(nfc110)->close != NULL) {
                NFC110_RAW_FUNC(nfc110)->close(nfc110->handle);
            }
            return rc;
        }
    }
    NFC110_SET_SPEED(nfc110, NFC110_DEFAULT_SPEED);

    if (NFC110_RAW_FUNC(nfc110)->clear_rx_queue != NULL) {
        rc = NFC110_RAW_FUNC(nfc110)->clear_rx_queue(nfc110->handle);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc, "icsdrv_raw_func->clear_rx_queue()");
            /* ignore error */
        }
    }

    NFC110_ACK_TIME(nfc110) = 0;

    ICSLOG_DBG_HEX(nfc110->handle);

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function closes the port.
 *
 * \param  nfc110                 [IN] The handle to access the port.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_IO                Other driver error.
 */
UINT32 nfc110_close(
    ICS_HW_DEVICE* nfc110)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_close"
    UINT32 rc;
    ICSLOG_FUNC_BEGIN;

    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);

    if (NFC110_RAW_FUNC(nfc110)->close != NULL) {
        rc = NFC110_RAW_FUNC(nfc110)->close(nfc110->handle);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc, "icsdrv_raw_func->close()");
            return rc;
        }
    }
    nfc110->handle = ICS_INVALID_HANDLE;

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function initializes the device.
 *
 * \param  nfc110                 [IN] The handle to access the port.
 * \param  timeout                [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Invalid response.
 * \retval ICS_ERROR_NOT_SUPPORTED     Not supported.
 * \retval ICS_ERROR_DEVICE            Error at device.
 */
UINT32 nfc110_initialize_device(
    ICS_HW_DEVICE* nfc110,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_initialize_device"
    UINT32 rc;
    UINT8 command[3];
    UINT8 response[10];
    UINT32 response_len;
    UINT8 cmd_type[NFC110_COMMAND_TYPE_LEN];
    UINT8 cmd_type_offset_byte;
    ICSLOG_FUNC_BEGIN;

    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_UINT(timeout);

    /* cancel the previous command */
    rc = nfc110_cancel_command(nfc110);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_cancel_command()");
        return rc;
    }

    /* send a GetCommandType command */
    rc = nfc110_get_command_type(nfc110, cmd_type, timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_get_command_type()");
        return rc;
    }

    /* check the command type */
    cmd_type_offset_byte =
        ((NFC110_COMMAND_TYPE_LEN - 1) - (NFC110_SUPPORTED_COMMAND_TYPE / 8));
    if (((cmd_type[cmd_type_offset_byte] >>
          (NFC110_SUPPORTED_COMMAND_TYPE % 8)) & 0x01) == 0x00) {
        rc = ICS_ERROR_NOT_SUPPORTED;
        ICSLOG_ERR_STR(rc, "Unsupported command type.");
        return rc;
    }

    /* send a SetCommandType */
    command[0] = NFC110_COMMAND_CODE;
    command[1] = NFC110_CMD_SET_COMMAND_TYPE;
    command[2] = NFC110_SUPPORTED_COMMAND_TYPE;
    rc = nfc110_execute_command(nfc110,
                                command,
                                3,
                                3,
                                response,
                                &response_len,
                                timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_execute_command()");
        if (rc == ICS_ERROR_BUF_OVERFLOW) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Buffer overflow.");
        }
        return rc;
    }
    if ((response_len != 3) ||
        (response[0] != NFC110_RESPONSE_CODE) ||
        (response[1] != NFC110_RES_SET_COMMAND_TYPE)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response.");
        return rc;
    }

    /* check the response status */
    rc = nfc110_convert_dev_status(response[2]);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_convert_dev_status()");
        return rc;
    }

    /* reset the mode of driver */
    rc = nfc110_reset(nfc110, timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_reset()");
        return rc;
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function gets version of the FW.
 *
 * \param  nfc110                 [IN] The handle to access the port.
 * \param  version               [OUT] Version of firmware.
 * \param  timeout                [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Received an invalid response.
 */
UINT32 nfc110_get_firmware_version(
    ICS_HW_DEVICE* nfc110,
    UINT16* version,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_get_firmware_version"
    UINT32 rc;
    UINT8 command[2];
    UINT8 response[4];
    UINT32 response_len;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(version, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_UINT(timeout);

    /* send a GetFirmwareVersion command */
    command[0] = NFC110_COMMAND_CODE;
    command[1] = NFC110_CMD_GET_FIRMWARE_VERSION;
    rc = nfc110_execute_command(nfc110,
                                command,
                                sizeof(command),
                                sizeof(response),
                                response,
                                &response_len,
                                timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_execute_command()");
        if (rc == ICS_ERROR_BUF_OVERFLOW) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Buffer overflow.");
        }
        return rc;
    }
    if ((response_len != sizeof(response)) ||
        (response[0] != NFC110_RESPONSE_CODE) ||
        (response[1] != NFC110_RES_GET_FIRMWARE_VERSION)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response.");
        return rc;
    }

    /* firmware version */
    *version = (((UINT16)response[2] << 0) |
                ((UINT16)response[3] << 8));
    ICSLOG_DBG_HEX(*version);

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function checks the device is alive.
 *
 * \param  nfc110                 [IN] The handle to access the port.
 * \param  timeout                [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Invalid response.
 */
UINT32 nfc110_ping(
    ICS_HW_DEVICE* nfc110,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_ping"
    UINT32 rc;
    UINT16 version;
    ICSLOG_FUNC_BEGIN;

    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_UINT(timeout);

    /* send a GetFirmwareVersion command */
    rc = nfc110_get_firmware_version(nfc110, &version, timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_get_firmware_version()");
        return rc;
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function resets the mode of the driver.
 *
 * \param  nfc110                 [IN] The handle to access the port.
 * \param  timeout                [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 */
UINT32 nfc110_reset(
    ICS_HW_DEVICE* nfc110,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_reset"
    UINT32 rc;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_UINT(timeout);

    /* reset NFC Port-110 to default protocol setting */
    rc = nfc110_set_rf_speed(nfc110,
                             NFC110_DEFAULT_RF_RBT_TX,
                             NFC110_DEFAULT_RF_SPEED_TX,
                             NFC110_DEFAULT_RF_RBT_RX,
                             NFC110_DEFAULT_RF_SPEED_RX,
                             timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_set_rf_speed()");
        return rc;
    }
    NFC110_SET_LAST_MODE(nfc110, NFC110_DEFAULT_MODE);

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function sends a command to the device and receives response.
 *
 * \param  nfc110                 [IN] The handle to access the port.
 * \param  command                [IN] A command to write.
 * \param  command_len            [IN] The length of the command.
 * \param  max_response_len       [IN] The size of response buffer.
 * \param  response              [OUT] Recieved response.
 * \param  response_len          [OUT] The length of the response.
 * \param  timeout                [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Invalid response.
 * \retval ICS_ERROR_BUF_OVERFLOW      Response buffer overflow.
 */
UINT32 nfc110_execute_command(
    ICS_HW_DEVICE* nfc110,
    const UINT8* command,
    UINT32 command_len,
    UINT32 max_response_len,
    UINT8* response,
    UINT32* response_len,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_execute_command"
    UINT32 rc;
    UINT32 response_pos;
    UINT8 buf[NFC110_COMMAND_BUF_LEN];
    ICSLOG_FUNC_BEGIN;

    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(command, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(response, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(response_len, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_IN_RANGE(command_len, 1, NFC110_MAX_COMMAND_LEN,
                           ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_UINT(command_len);
    ICSLOG_DUMP(command, command_len);
    ICSLOG_DBG_UINT(max_response_len);
    ICSLOG_DBG_UINT(timeout);

    /* copy the command to the buffer */
    utl_memcpy((buf + NFC110_COMMAND_POS), command, command_len);

    /* execute the command */
    rc = nfc110_execute_command_internal(nfc110,
                                         buf,
                                         command_len,
                                         &response_pos,
                                         response_len,
                                         timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_execute_command_internal()");
        return rc;
    }
    ICSLOG_DBG_UINT(*response_len);

    if (*response_len <= max_response_len) {
        utl_memcpy(response, (buf + response_pos), *response_len);
        ICSLOG_DUMP(response, *response_len);
    } else {
        utl_memcpy(response, (buf + response_pos), max_response_len);
        ICSLOG_DUMP(response, max_response_len);
        rc = ICS_ERROR_BUF_OVERFLOW;
        return rc;
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function sends a command to RF front-end and receives response.
 *
 * \param  nfc110                 [IN] The handle to access the port.
 * \param  command                [IN] A command to write.
 * \param  command_len            [IN] The length of the command.
 * \param  max_response_len       [IN] The size of response buffer.
 * \param  response              [OUT] Recieved response.
 * \param  response_len          [OUT] The length of the response.
 * \param  rf_status             [OUT] The result of rf communication.
 * \param  valid_bit             [OUT] The number of valid bit of last byte.
 * \param  need_len               [IN] If the length is needed or not.
 * \param  command_timeout        [IN] Time-out at the device. (ms)
 * \param  timeout                [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_RF_OFF            RF was turned off.
 * \retval ICS_ERROR_FRAME_CRC         CRC error.
 * \retval ICS_ERROR_DEVICE            Error at device.
 * \retval ICS_ERROR_INVALID_RESPONSE  Invalid response.
 * \retval ICS_ERROR_BUF_OVERFLOW      Response buffer overflow.
 */
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
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_rf_command"
    UINT32 rc;
    UINT32 rc2;
    UINT32 nfield;
    UINT32 timeout_0_1;
    UINT32 nfc110_command_len;
    UINT32 nfc110_response_len;
    UINT32 nfc110_response_pos;
    UINT8 buf[NFC110_COMMAND_BUF_LEN];
    UINT32 stat;
    UINT8 vbit;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);
    if (command_len > 0) {
        ICSLIB_CHKARG_NE(command, NULL, ICS_ERROR_INVALID_PARAM);
    }
    if (max_response_len > 0) {
        ICSLIB_CHKARG_NE(response, NULL, ICS_ERROR_INVALID_PARAM);
    }
    if (response != NULL) {
        ICSLIB_CHKARG_NE(response_len, NULL, ICS_ERROR_INVALID_PARAM);
    }
    if (need_len) {
        nfield = 1;
    } else {
        nfield = 0;
    }
    ICSLIB_CHKARG_LE(command_len + nfield, NFC110_MAX_RF_COMMAND_LEN,
                     ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_UINT(command_len);
    ICSLOG_DUMP(command, command_len);
    ICSLOG_DBG_UINT(max_response_len);
    ICSLOG_DBG_UINT(need_len);
    ICSLOG_DBG_UINT(command_timeout);
    ICSLOG_DBG_UINT(timeout);

    /* in this case, don't send rf command */
    if (command_timeout == 0) {
        rc = ICS_ERROR_TIMEOUT;
        ICSLOG_ERR_STR(rc, "Time-out.");
        return rc;
    }

    /* make a command packet for NFC Port-110 */
    if (command_timeout >= ((UINT32)0x10000 / 10)) {
        timeout_0_1 = 0xffff;
    } else {
        timeout_0_1 = (command_timeout * 10);
    }

    buf[NFC110_COMMAND_POS + 0] = NFC110_COMMAND_CODE;
    buf[NFC110_COMMAND_POS + 1] = NFC110_CMD_IN_COMM_RF;
    if (response == NULL) {
        buf[NFC110_COMMAND_POS + 2] = 0; /* no data to receive */
        buf[NFC110_COMMAND_POS + 3] = 0;
    } else {
        buf[NFC110_COMMAND_POS + 2] = (UINT8)((timeout_0_1 >> 0) & 0xff);
        buf[NFC110_COMMAND_POS + 3] = (UINT8)((timeout_0_1 >> 8) & 0xff);
    }
    if (command_len > 0) {
        if (need_len) {
            buf[NFC110_COMMAND_POS + 4] = (command_len + 1);
        }
        utl_memcpy(
            (buf + NFC110_COMMAND_POS + 4 + nfield), command, command_len);
        nfc110_command_len = (4 + nfield + command_len);
    } else {
        nfc110_command_len = 4;
    }

    /* send the packet to NFC Port-110 */
    rc = nfc110_execute_command_internal(nfc110,
                                         buf,
                                         nfc110_command_len,
                                         &nfc110_response_pos,
                                         &nfc110_response_len,
                                         timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_execute_command_internal()");
        if ((rc == ICS_ERROR_TIMEOUT) ||
            (rc == ICS_ERROR_INVALID_RESPONSE)) {
            /* cancel the command */
            rc2 = nfc110_cancel_command(nfc110);
            if (rc2 != ICS_ERROR_SUCCESS) {
                ICSLOG_ERR_STR(rc2, "nfc110_cancel_command()");
                /* Note: ignore error*/
            }
        }
        return rc;
    }
    /* when InCommRF command fails,
     response does not include "RxLastBit" field */
    if ((nfc110_response_pos != NFC110_RESPONSE_POS) ||
        (nfc110_response_len < 6) ||
        (buf[nfc110_response_pos + 0] != NFC110_RESPONSE_CODE) ||
        (buf[nfc110_response_pos + 1] != NFC110_RES_IN_COMM_RF)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response.");

        /* cancel the command */
        rc2 = nfc110_cancel_command(nfc110);
        if (rc2 != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc2, "nfc110_cancel_command()");
            /* Note: ignore error*/
        }
        return rc;
    }

    vbit = 0;
    if ((nfc110_response_len > 7) && (response != NULL)) {
        vbit = buf[nfc110_response_pos + 6];
        if ((vbit != 8) && (valid_bit == NULL)) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Invalid RxLastBit.");
            return rc;
        }

        if (need_len &&
            (buf[nfc110_response_pos + 7] != (nfc110_response_len - 7))) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Invalid response.");
            return rc;
        }
        *response_len = (nfc110_response_len - 7 - nfield);
        ICSLOG_DBG_UINT(*response_len);
        if (*response_len > max_response_len) {
            utl_memcpy(response,
                       (buf + nfc110_response_pos + 7 + nfield),
                       max_response_len);
            ICSLOG_DUMP(response, max_response_len);

            rc = ICS_ERROR_BUF_OVERFLOW;
            ICSLOG_ERR_STR(rc, "Buffer overflow.");
            return rc;
        }
        utl_memcpy(response,
                   (buf + nfc110_response_pos + 7 + nfield),
                   *response_len);
        ICSLOG_DUMP(response, *response_len);
    } else if (response_len != NULL) {
        vbit = 0;
        *response_len = 0;
        ICSLOG_DBG_UINT(*response_len);
    }

    stat = (((UINT32)buf[nfc110_response_pos + 2] <<  0) |
            ((UINT32)buf[nfc110_response_pos + 3] <<  8) |
            ((UINT32)buf[nfc110_response_pos + 4] << 16) |
            ((UINT32)buf[nfc110_response_pos + 5] << 24));

    ICSLOG_DBG_HEX(stat);
    ICSLOG_DBG_UINT(vbit);

    if (rf_status != NULL) {
        *rf_status = stat;
    }
    if (valid_bit != NULL) {
        *valid_bit = vbit;
    }

    /* check the response status */
    rc = nfc110_convert_rf_status(stat);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_convert_rf_status()");
        return rc;
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function sends an ACK to the device.
 *
 * \param  nfc110                 [IN] The handle to access the port.
 * \param  timeout                [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 */
UINT32 nfc110_send_ack(
    ICS_HW_DEVICE* nfc110,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_send_ack"
    UINT32 rc;
    static const UINT8 ack[6] = {0x00, 0x00, 0xff, 0x00, 0xff, 0x00};
    UINT32 time0;
    ICSLOG_FUNC_BEGIN;

    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_UINT(timeout);

    time0 = utl_get_time_msec();

    /* send command */
    if (NFC110_RAW_FUNC(nfc110)->write != NULL) {
        rc = NFC110_RAW_FUNC(nfc110)->write(nfc110->handle,
                                            ack,
                                            sizeof(ack),
                                            time0,
                                            timeout);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc, "icsdrv_raw_func->write()");
            return rc;
        }
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function cancels the previous command.
 *
 * \param  nfc110                 [IN] The handle to access the port.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 */
UINT32 nfc110_cancel_command(
    ICS_HW_DEVICE* nfc110)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_cancel_command"
    UINT32 rc;
    ICSLOG_FUNC_BEGIN;

    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);

    /* drain the transmitting queue */
    if (NFC110_RAW_FUNC(nfc110)->drain_tx_queue != NULL) {
        rc = NFC110_RAW_FUNC(nfc110)->drain_tx_queue(nfc110->handle);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc, "icsdrv_raw_func->drain_tx_queue()");
            return rc;
        }
    }
    rc = utl_msleep(1);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "utl_msleep()");
        return rc;
    }

    /* send a GetCommandType command */
    rc = nfc110_get_command_type(
        nfc110,
        NULL,
        NFC110_CANCEL_COMMAND_GET_COMMAND_TYPE_TIME_OUT);
    if (rc != ICS_ERROR_SUCCESS) {
        /* swept away the unnecessary data */
        rc = nfc110_sweep(nfc110);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc, "nfc110_sweep()");
            return rc;
        }
    }

    /* clear the queue for receiving */
    if (NFC110_RAW_FUNC(nfc110)->clear_rx_queue != NULL) {
        rc = NFC110_RAW_FUNC(nfc110)->clear_rx_queue(nfc110->handle);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc, "icsdrv_raw_func->clear_rx_queue()");
            return rc;
        }
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function sends the FeliCa command and receives a FeliCa response.
 *
 * \param  nfc110                 [IN] The handle to access the port.
 * \param  command                [IN] The card command to send.
 * \param  command_len            [IN] The length of the card command.
 * \param  max_response_len       [IN] The maximum length of response.
 * \param  response              [OUT] Received response.
 * \param  response_len          [OUT] The length of the response.
 * \param  command_timeout        [IN] Time-out at the device. (ms)
 * \param  timeout                [IN] Time-out. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_DEVICE            Error at device.
 * \retval ICS_ERROR_FRAME_CRC         CRC error.
 * \retval ICS_ERROR_RF_OFF            RF was turned off.
 * \retval ICS_ERROR_INVALID_RESPONSE  Received an invalid response packet.
 * \retval ICS_ERROR_BUF_OVERFLOW      The length of the received response
 *                                     exceeded max_response_len.
 */
UINT32 nfc110_felica_command(
    ICS_HW_DEVICE* nfc110,
    const UINT8* command,
    UINT32 command_len,
    UINT32 max_response_len,
    UINT8* response,
    UINT32* response_len,
    UINT32 command_timeout,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_felica_command"
    UINT32 rc;
    ICSLOG_FUNC_BEGIN;

    ICSLIB_CHKARG_LE(command_len, NFC110_MAX_FELICA_COMMAND_LEN,
                     ICS_ERROR_INVALID_PARAM);

    rc = nfc110_rf_command(nfc110,
                           command,
                           command_len,
                           max_response_len,
                           response,
                           response_len,
                           NULL,
                           NULL,
                           TRUE,
                           command_timeout,
                           timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_rf_command()");
        return rc;
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function turns RF off.
 *
 * \param  nfc110                 [IN] The handle to access the port.
 * \param  timeout                [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Received an invalid response.
 * \retval ICS_ERROR_DEVICE            Error at device.
 */
UINT32 nfc110_rf_off(
    ICS_HW_DEVICE* nfc110,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_rf_off"
    UINT32 rc;
    UINT8 command[3];
    UINT8 response[3];
    UINT32 response_len;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_UINT(timeout);

    /* send a SwitchRF command (RF off) */
    command[0] = NFC110_COMMAND_CODE;
    command[1] = NFC110_CMD_SWITCH_RF;
    command[2] = 0x00; /* RF off */
    rc = nfc110_execute_command(nfc110,
                                command,
                                sizeof(command),
                                sizeof(response),
                                response,
                                &response_len,
                                timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_execute_command()");
        if (rc == ICS_ERROR_BUF_OVERFLOW) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Buffer overflow.");
        }
        return rc;
    }
    if ((response_len != 3) ||
        (response[0] != NFC110_RESPONSE_CODE) ||
        (response[1] != NFC110_RES_SWITCH_RF)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response.");
        return rc;
    }

    /* check the response status */
    rc = nfc110_convert_dev_status(response[2]);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_convert_dev_status()");
        return rc;
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function turns RF on.
 *
 * \param  nfc110                 [IN] The handle to access the port.
 * \param  timeout                [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Received an invalid response.
 * \retval ICS_ERROR_DEVICE            Error at device.
 */
UINT32 nfc110_rf_on(
    ICS_HW_DEVICE* nfc110,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_rf_on"
    UINT32 rc;
    UINT8 command[3];
    UINT8 response[3];
    UINT32 response_len;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_UINT(timeout);

    /* send a SwitchRF command (RF on) */
    command[0] = NFC110_COMMAND_CODE;
    command[1] = NFC110_CMD_SWITCH_RF;
    command[2] = 0x01; /* RF on */
    rc = nfc110_execute_command(nfc110,
                                command,
                                sizeof(command),
                                sizeof(response),
                                response,
                                &response_len,
                                timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_execute_command()");
        if (rc == ICS_ERROR_BUF_OVERFLOW) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Buffer overflow.");
        }
        return rc;
    }
    if ((response_len != 3) ||
        (response[0] != NFC110_RESPONSE_CODE) ||
        (response[1] != NFC110_RES_SWITCH_RF)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response.");
        return rc;
    }

    /* check the response status */
    rc = nfc110_convert_dev_status(response[2]);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_convert_dev_status()");
        return rc;
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function sets the RF speed of the device.
 *
 * \param  nfc110                 [IN] The handle to access the port.
 * \param  tx_rbt                 [IN] The TX RBT number to set.
 * \param  tx_speed               [IN] The TX RF speed to set.
 * \param  rx_rbt                 [IN] The RX RBT number to set.
 * \param  rx_speed               [IN] The RX RF speed to set.
 * \param  timeout                [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Invalid response.
 * \retval ICS_ERROR_DEVICE            Error at device.
 */
UINT32 nfc110_set_rf_speed(
    ICS_HW_DEVICE* nfc110,
    UINT8 tx_rbt,
    UINT8 tx_speed,
    UINT8 rx_rbt,
    UINT8 rx_speed,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_set_rf_speed"
    UINT32 rc;
    UINT8 command[6];
    UINT32 command_len;
    UINT8 response[3];
    UINT32 response_len;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_IN_RANGE(tx_rbt, 0x01, 0x0f, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_IN_RANGE(rx_rbt, 0x01, 0x0f, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_IN_RANGE(tx_speed,
                           NFC110_RF_INITIATOR_ISO18092_212K,
                           NFC110_RF_INITIATOR_ISO14443B_848K,
                           ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_IN_RANGE(rx_speed,
                           NFC110_RF_INITIATOR_ISO18092_212K,
                           NFC110_RF_INITIATOR_ISO14443B_848K,
                           ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_HEX8(tx_rbt);
    ICSLOG_DBG_HEX8(tx_speed);
    ICSLOG_DBG_HEX8(rx_rbt);
    ICSLOG_DBG_HEX8(rx_speed);
    ICSLOG_DBG_UINT(timeout);

    /* send a InSetRF command */
    command[0] = NFC110_COMMAND_CODE;
    command[1] = NFC110_CMD_IN_SET_RF;
    command[2] = tx_rbt;
    command[3] = tx_speed;
    command[4] = rx_rbt;
    command[5] = rx_speed;
    command_len = 6;
    rc = nfc110_execute_command(nfc110,
                                command,
                                command_len,
                                sizeof(response),
                                response,
                                &response_len,
                                timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_execute_command()");
        if (rc == ICS_ERROR_BUF_OVERFLOW) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Buffer overflow.");
        }
        return rc;
    }
    if ((response_len != 3) ||
        (response[0] != NFC110_RESPONSE_CODE) ||
        (response[1] != NFC110_RES_IN_SET_RF)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response.");
        return rc;
    }

    /* check the response status */
    rc = nfc110_convert_dev_status(response[2]);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_convert_dev_status()");
        return rc;
    }

    NFC110_SET_TX_RBT(nfc110, tx_rbt);
    NFC110_SET_RX_RBT(nfc110, rx_rbt);
    NFC110_SET_TX_SPEED(nfc110, tx_speed);
    NFC110_SET_RX_SPEED(nfc110, rx_speed);

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function sets the rf protocol setting data of the device.
 *
 * \param  nfc110                 [IN] The handle to access the port.
 * \param  setting                [IN] The bytes of setting data.
 * \param  setting_len            [IN] The length of the setting data.
 * \param  timeout                [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Invalid response.
 * \retval ICS_ERROR_DEVICE            Error at device.
 */
UINT32 nfc110_set_protocol(
    ICS_HW_DEVICE* nfc110,
    const UINT8* setting,
    UINT32 setting_len,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_set_protocol"
    UINT32 rc;
    UINT8 command[42];
    UINT32 command_len;
    UINT8 response[3];
    UINT32 response_len;
    UINT32 len;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(setting, NULL, ICS_ERROR_INVALID_PARAM);
    len = (setting_len % 2);
    ICSLIB_CHKARG_EQ(len, 0, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_IN_RANGE((setting_len / 2),
                           1, NFC110_MAX_IN_SET_PROTOCOL_SETTING_NUM,
                           ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_UINT(setting_len);
    ICSLOG_DUMP(setting, setting_len);
    ICSLOG_DBG_UINT(timeout);

    /* send a InSetProtocol command */
    command[0] = NFC110_COMMAND_CODE;
    command[1] = NFC110_CMD_IN_SET_PROTOCOL;
    utl_memcpy((command + 2), setting, setting_len);
    command_len = (2 + setting_len);
    rc = nfc110_execute_command(nfc110,
                                command,
                                command_len,
                                sizeof(response),
                                response,
                                &response_len,
                                timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_execute_command()");
        if (rc == ICS_ERROR_BUF_OVERFLOW) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Buffer overflow.");
        }
        return rc;
    }
    if ((response_len != 3) ||
        (response[0] != NFC110_RESPONSE_CODE) ||
        (response[1] != NFC110_RES_IN_SET_PROTOCOL)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response.");
        return rc;
    }

    /* check the response status */
    rc = nfc110_convert_dev_status(response[2]);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_convert_dev_status()");
        return rc;
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function gets the rf protocol setting data of the device.
 *
 * \param  nfc110                 [IN] The handle to access the port.
 * \param  setting_num            [IN] The array of setting numbers.
 * \param  setting_num_len        [IN] The length of setting numbers.
 * \param  setting               [OUT] The array of setting data.
 * \param  setting_len        [IN/OUT] The length of the setting data.
 * \param  timeout                [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Invalid response.
 * \retval ICS_ERROR_DEVICE            Error at device.
 * \retval ICS_ERROR_BUF_OVERFLOW      The length of the received response
 *                                     exceeded input setting_len.
 */
UINT32 nfc110_get_protocol(
    ICS_HW_DEVICE* nfc110,
    const UINT8* setting_num,
    UINT32 setting_num_len,
    UINT8* setting,
    UINT32* setting_len,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_get_protocol"
    UINT32 rc;
    UINT8 command[22];
    UINT32 command_len;
    UINT8 response[42];
    UINT32 response_len;
    ICSLOG_FUNC_BEGIN;

    /* check the prameter */
    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(setting_num, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(setting, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(setting_len, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_BE(*setting_len, (setting_num_len * 2),
                     ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_IN_RANGE(setting_num_len,
                           1, NFC110_MAX_IN_SET_PROTOCOL_SETTING_NUM,
                           ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_UINT(setting_num_len);
    ICSLOG_DUMP(setting_num, setting_num_len);
    ICSLOG_DBG_UINT(*setting_len);
    ICSLOG_DBG_UINT(timeout);

    /* send a InGetProtocol command */
    command[0] = NFC110_COMMAND_CODE;
    command[1] = NFC110_CMD_IN_GET_PROTOCOL;
    utl_memcpy((command + 2), setting_num, setting_num_len);
    command_len = (2 + setting_num_len);
    rc = nfc110_execute_command(nfc110,
                                command,
                                command_len,
                                sizeof(response),
                                response,
                                &response_len,
                                timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_execute_command()");
        if (rc == ICS_ERROR_BUF_OVERFLOW) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Buffer overflow.");
        }
        return rc;
    }
    if ((response_len < 3) ||
        (response[0] != NFC110_RESPONSE_CODE) ||
        (response[1] != NFC110_RES_IN_GET_PROTOCOL) ||
        (response_len < (2 + (2 * setting_num_len))) ||
        ((response_len % 2) != 0)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response.");
        return rc;
    } else if (response_len > (2 + (2 * setting_num_len))) {
        rc = ICS_ERROR_BUF_OVERFLOW;
        ICSLOG_ERR_STR(rc, "Buffer overflow.");

        *setting_len = (response_len - 2);
        utl_memcpy(setting, (response + 2), (setting_num_len * 2));
        ICSLOG_DBG_UINT(*setting_len);
        ICSLOG_DUMP(setting, *setting_len);
        return rc;
    }

    *setting_len = (setting_num_len * 2);
    utl_memcpy(setting, (response + 2), *setting_len);
    ICSLOG_DBG_UINT(*setting_len);
    ICSLOG_DUMP(setting, *setting_len);

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function clears the receiving queue.
 *
 * \param  nfc110                 [IN] The handle to access the port.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_IO                Other driver error.
 */
UINT32 nfc110_clear_rx_queue(
    ICS_HW_DEVICE* nfc110)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_clear_rx_queue"
    UINT32 rc;
    ICSLOG_FUNC_BEGIN;

    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);

    if (NFC110_RAW_FUNC(nfc110)->clear_rx_queue != NULL) {
        rc = NFC110_RAW_FUNC(nfc110)->clear_rx_queue(nfc110->handle);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc, "icsdrv_raw_clear_rx_queue()");
            return rc;
        }
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function returns the time when this driver received the last ACK.
 *
 * \param  nfc110                 [IN] The handle to access the port.
 * \param  ack_time              [OUT] The time when received an ACK.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 */
UINT32 nfc110_get_ack_time(
    ICS_HW_DEVICE* nfc110,
    UINT32* ack_time)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_get_ack_time"
    ICSLOG_FUNC_BEGIN;

    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(ack_time, NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);

    *ack_time = NFC110_ACK_TIME(nfc110);

    ICSLOG_DBG_UINT(*ack_time);

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function gets version of the BLE.
 *
 * \param  nfc110                 [IN] The handle to access the port.
 * \param  fw_version            [OUT] Version of firmware.
 * \param  ble_version           [OUT] Version of BLE firmware.
 * \param  timeout                [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Received an invalid response.
 */
UINT32 nfc110_get_version_information(
    ICS_HW_DEVICE* nfc110,
    UINT16* fw_version,
    UINT16* ble_version,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_get_version_information"
    UINT32 rc;
    UINT8 command[3];
    UINT32 command_len;
    UINT8 response[4];
    UINT32 response_len;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(fw_version, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(ble_version, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_UINT(timeout);

    /* send a GetFirmwareVersion command with no option (firmware version) */
    command[0] = NFC110_COMMAND_CODE;
    command[1] = NFC110_CMD_GET_FIRMWARE_VERSION;
    command_len = 2;
    rc = nfc110_execute_command(nfc110,
                                command,
                                command_len,
                                sizeof(response),
                                response,
                                &response_len,
                                timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_execute_command()");
        if (rc == ICS_ERROR_BUF_OVERFLOW) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Buffer overflow.");
        }
        return rc;
    }
    if ((response_len != 4) ||
        (response[0] != NFC110_RESPONSE_CODE) ||
        (response[1] != NFC110_RES_GET_FIRMWARE_VERSION)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response.");
        return rc;
    }

    /* Firmware version */
    *fw_version = (((UINT16)response[2] << 0) |
                   ((UINT16)response[3] << 8));
    ICSLOG_DBG_HEX(*fw_version);

    /* send a GetFirmwareVersion command with option BLE firmware version */
    command[0] = NFC110_COMMAND_CODE;
    command[1] = NFC110_CMD_GET_FIRMWARE_VERSION;
    command[2] = NFC110_GETFWOPT_BLE_VERSION;
    command_len = 3;
    rc = nfc110_execute_command(nfc110,
                                command,
                                command_len,
                                sizeof(response),
                                response,
                                &response_len,
                                timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_execute_command()");
        if (rc == ICS_ERROR_BUF_OVERFLOW) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Buffer overflow.");
        }
        return rc;
    }
    if ((response_len != 4) ||
        (response[0] != NFC110_RESPONSE_CODE) ||
        (response[1] != NFC110_RES_GET_FIRMWARE_VERSION)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response.");
        return rc;
    }

    /* BLE firmware version */
    *ble_version = (((UINT16)response[2] << 0) |
                    ((UINT16)response[3] << 8));
    ICSLOG_DBG_HEX(*ble_version);

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function gets the power status of the device.
 *
 * \param  nfc110                 [IN] The handle to access the port.
 * \param  power_status          [OUT] The power status of the device.
 * \param  timeout                [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Invalid response.
 */
UINT32 nfc110_get_battery_information(
    ICS_HW_DEVICE* nfc110,
    UINT8* power_status,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_get_battery_information"
    UINT32 rc;
    UINT8 command[3];
    UINT32 command_len;
    UINT8 response[4];
    UINT32 response_len;
    ICSLOG_FUNC_BEGIN;

    /* check the prameter */
    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(power_status, NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_UINT(timeout);

    /* send a diagnose command with option testnum power status */
    command[0] = NFC110_COMMAND_CODE;
    command[1] = NFC110_CMD_DIAGNOSE;
    command[2] = NFC110_TESTNUM_POWERSTATUS;
    command_len = 3;
    rc = nfc110_execute_command(nfc110,
                                command,
                                command_len,
                                sizeof(response),
                                response,
                                &response_len,
                                timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_execute_command()");
        if (rc == ICS_ERROR_BUF_OVERFLOW) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Buffer overflow.");
        }
        return rc;
    }
    if ((response_len != 4) ||
        (response[0] != NFC110_RESPONSE_CODE) ||
        (response[1] != NFC110_RES_DIAGNOSE) ||
        (response[2] != NFC110_TESTNUM_POWERSTATUS)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response.");
        return rc;
    }

    if ((response[3] != 0x01) &&
        (response[3] != 0x02) &&
        (response[3] != 0x03) &&
        (response[3] != 0xFF)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response.");
        return rc;
    }

    *power_status = response[3];
    ICSLOG_DBG_HEX8(*power_status);

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function sets the alarm setting of the device.
 *
 * \param  nfc110     [IN] The handle to access the port.
 * \param  count      [IN] The time interval (min) for the alarm notification.
 * \param  timeout    [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Invalid response.
 */
UINT32 nfc110_set_alarm(
    ICS_HW_DEVICE* nfc110,
    UINT16 count,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_set_alarm"
    UINT32 rc;
    UINT8 command[4];
    UINT32 command_len;
    UINT8 response[3];
    UINT32 response_len;
    ICSLOG_FUNC_BEGIN;

    /* check the prameter */
    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_UINT(count);
    ICSLOG_DBG_UINT(timeout);

    /* send a SetAlarm command */
    command[0] = NFC110_COMMAND_CODE;
    command[1] = NFC110_CMD_SET_ALARM;
    command[2] = (count & 0xFF);
    command[3] = ((count >> 8) & 0xFF);
    command_len = 4;
    rc = nfc110_execute_command(nfc110,
                                command,
                                command_len,
                                sizeof(response),
                                response,
                                &response_len,
                                timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_execute_command()");
        if (rc == ICS_ERROR_BUF_OVERFLOW) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Buffer overflow.");
        }
        return rc;
    }
    if ((response_len != 3) ||
        (response[0] != NFC110_RESPONSE_CODE) ||
        (response[1] != NFC110_RES_SET_ALARM)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response.");
        return rc;
    }

    /* check the response status */
    if (response[2] != 0x00) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response.");
        return rc;
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function gets the alarm setting of the device.
 *
 * \param  nfc110         [IN] The handle to access the port.
 * \param  rest_count    [OUT] The remaining time of the alarm notification.
 * \param  count         [OUT] The time interval of the alarm notification.
 * \param  timeout        [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Received an invalid response.
 */
UINT32 nfc110_get_alarm(
    ICS_HW_DEVICE* nfc110,
    UINT16* rest_count,
    UINT16* count,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_get_alarm"
    UINT32 rc;
    UINT8 command[2];
    UINT32 command_len;
    UINT8 response[6];
    UINT32 response_len;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(rest_count, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(count, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_UINT(timeout);

    /* send a GetAlarm command */
    command[0] = NFC110_COMMAND_CODE;
    command[1] = NFC110_CMD_GET_ALARM;
    command_len = 2;
    rc = nfc110_execute_command(nfc110,
                                command,
                                command_len,
                                sizeof(response),
                                response,
                                &response_len,
                                timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_execute_command()");
        if (rc == ICS_ERROR_BUF_OVERFLOW) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Buffer overflow.");
        }
        return rc;
    }
    if ((response_len != 6) ||
        (response[0] != NFC110_RESPONSE_CODE) ||
        (response[1] != NFC110_RES_GET_ALARM)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response.");
        return rc;
    }

    *rest_count = (((UINT16)response[2] << 0) |
                   ((UINT16)response[3] << 8));
    *count      = (((UINT16)response[4] << 0) |
                   ((UINT16)response[5] << 8));
    ICSLOG_DBG_UINT(*rest_count);
    ICSLOG_DBG_UINT(*count);

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function gets the current BLE connection parameters of the device.
 *
 * \param  nfc110               [IN] The handle to access the port.
 * \param  connection_interval [OUT] The current connection interval.
 * \param  slave_latency       [OUT] The current slave latency.
 * \param  connection_timeout  [OUT] The current connection time-out.
 * \param  timeout              [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Received an invalid response.
 * \retval ICS_ERROR_DEVICE            Error at device.
 */
UINT32 nfc110_get_ble_peripheral_parameter(
    ICS_HW_DEVICE* nfc110,
    UINT16* connection_interval,
    UINT16* slave_latency,
    UINT16* connection_timeout,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_get_ble_peripheral_parameter"
    UINT32 rc;
    UINT8 command[2];
    UINT32 command_len;
    UINT8 response[9];
    UINT32 response_len;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_EQ(((connection_interval == NULL) &&
                      (slave_latency == NULL) &&
                      (connection_timeout == NULL)),
                     FALSE,
                     ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_UINT(timeout);

    /* send a GetBLEParameter command */
    command[0] = NFC110_COMMAND_CODE;
    command[1] = NFC110_CMD_GET_BLE_PARAMETER;
    command_len = 2;
    rc = nfc110_execute_command(nfc110,
                                command,
                                command_len,
                                sizeof(response),
                                response,
                                &response_len,
                                timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_execute_command()");
        if (rc == ICS_ERROR_BUF_OVERFLOW) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Buffer overflow.");
        }
        return rc;
    }
    if ((response_len != 9) ||
        (response[0] != NFC110_RESPONSE_CODE) ||
        (response[1] != NFC110_RES_GET_BLE_PARAMETER)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response.");
        return rc;
    }

    /* check the response status */
    rc = nfc110_convert_dev_status(response[2]);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_convert_dev_status()");
        return rc;
    }

    /* peripheral parameter */
    if (connection_interval != NULL) {
        *connection_interval = (((UINT16)response[3] << 0) |
                                ((UINT16)response[4] << 8));
        ICSLOG_DBG_HEX(*connection_interval);
    }
    if (slave_latency != NULL) {
        *slave_latency = (((UINT16)response[5] << 0) |
                          ((UINT16)response[6] << 8));
        ICSLOG_DBG_HEX(*slave_latency);
    }
    if (connection_timeout != NULL) {
        *connection_timeout = (((UINT16)response[7] << 0) |
                               ((UINT16)response[8] << 8));
        ICSLOG_DBG_HEX(*connection_timeout);
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function sets the BLE connection parameters of the device.
 *
 * \param  nfc110               [IN] The handle to access the port.
 * \param  interval_min         [IN] The minimum interval value to set.
 * \param  interval_max         [IN] The maximum interval value to set.
 * \param  slave_latency        [IN] The slave latency value to set.
 * \param  timeout_multiplier   [IN] The time-out multiplier value to set.
 * \param  timeout              [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Received an invalid response.
 * \retval ICS_ERROR_DEVICE            Error at device.
 */
UINT32 nfc110_set_ble_peripheral_parameter(
    ICS_HW_DEVICE* nfc110,
    UINT16 interval_min,
    UINT16 interval_max,
    UINT16 slave_latency,
    UINT16 timeout_multiplier,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_set_ble_peripheral_parameter"
    UINT32 rc;
    UINT8 command[10];
    UINT32 command_len;
    UINT8 response[3];
    UINT32 response_len;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_UINT(interval_min);
    ICSLOG_DBG_UINT(interval_max);
    ICSLOG_DBG_UINT(slave_latency);
    ICSLOG_DBG_UINT(timeout_multiplier);
    ICSLOG_DBG_UINT(timeout);

    /* send a SetBLEParameter command */
    command[0] = NFC110_COMMAND_CODE;
    command[1] = NFC110_CMD_SET_BLE_PARAMETER;
    command[2] = (interval_min & 0xFF);
    command[3] = ((interval_min >> 8) & 0xFF);
    command[4] = (interval_max & 0xFF);
    command[5] = ((interval_max >> 8) & 0xFF);
    command[6] = (slave_latency & 0xFF);
    command[7] = ((slave_latency >> 8) & 0xFF);
    command[8] = (timeout_multiplier & 0xFF);
    command[9] = ((timeout_multiplier >> 8) & 0xFF);
    command_len = 10;
    rc = nfc110_execute_command(nfc110,
                                command,
                                command_len,
                                sizeof(response),
                                response,
                                &response_len,
                                timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_execute_command()");
        if (rc == ICS_ERROR_BUF_OVERFLOW) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Buffer overflow.");
        }
        return rc;
    }
    if ((response_len != 3) ||
        (response[0] != NFC110_RESPONSE_CODE) ||
        (response[1] != NFC110_RES_SET_BLE_PARAMETER)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response.");
        return rc;
    }

    /* check the response status */
    rc = nfc110_convert_dev_status(response[2]);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_convert_dev_status()");
        return rc;
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function gets information of the device.
 *
 * \param  nfc110               [IN] The handle to access the port.
 * \param  arg                 [OUT] Information of the device
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_IO                Other driver error.
 */
UINT32 nfc110_get_attribute(
    ICS_HW_DEVICE* nfc110,
    void* arg)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_get_attribute"
    UINT32 rc;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(
        NFC110_RAW_EXT_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(arg, NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_PTR(arg);

    if (NFC110_RAW_EXT_FUNC(nfc110)->get_attribute != NULL) {
        rc = NFC110_RAW_EXT_FUNC(nfc110)->get_attribute(nfc110->handle, arg);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc, "icsdrv_raw_func->ext->get_attribute()");
            return rc;
        }
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function registers a callback function for notifications
 * from the device.
 *
 * \param  nfc110                   [IN] The handle to access the port.
 * \param  callback                 [IN] The notify callback function.
 *                                       If NULL is specified, the registered
 *                                       callback function will be cleared.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_IO                Other driver error.
 */
UINT32 nfc110_register_notify_callback(
    ICS_HW_DEVICE* nfc110,
    nfc110_notify_callback callback)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_register_norify_callback"
    UINT32 rc;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(
        NFC110_RAW_EXT_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_PTR(callback);

    if (NFC110_RAW_EXT_FUNC(nfc110)->register_notify_callback != NULL) {
        rc = NFC110_RAW_EXT_FUNC(
            nfc110)->register_notify_callback(nfc110->handle, callback);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(
                rc, "icsdrv_raw_func->ext->register_notify_callback()");
            return rc;
        }
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function registers a callback function for notifications
 * from the device.
 *
 * \param  nfc110                   [IN] The handle to access the port.
 * \param  callback                 [IN] The notify callback function.
 *                                       If NULL is specified, the registered
 *                                       callback function will be cleared.
 * \param  obj                      [IN] An user object which will be returned
 *                                       to the callback function.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_IO                Other driver error.
 */
UINT32 nfc110_register_notify_callback2(
    ICS_HW_DEVICE* nfc110,
    nfc110_notify_callback2_func_t callback,
    void* obj)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_register_notify_callback2"
    UINT32 rc;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(
        NFC110_RAW_EXT_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_PTR(callback);
    ICSLOG_DBG_PTR(obj);

    if (NFC110_RAW_EXT_FUNC(nfc110)->register_notify_callback2 != NULL) {
        rc = NFC110_RAW_EXT_FUNC(
                 nfc110)->register_notify_callback2(nfc110->handle,
                                                    callback,
                                                    obj);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(
                rc, "icsdrv_raw_func->ext->register_notify_callback2()");
            return rc;
        }
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function resets the device.
 *
 * \param  nfc110                 [IN] The handle to access the port.
 * \param  delay_time             [IN] The delay time before the device
                                       is in operating mode after reset.
 * \param  option                 [IN] The option of ResetDevice command.
 * \param  timeout                [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Invalid response.
 */
UINT32 nfc110_reset_device(
    ICS_HW_DEVICE* nfc110,
    UINT16 delay_time,
    UINT8 option,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_reset_device"
    UINT32 rc;
    UINT8 command[5];
    UINT32 command_len;
    UINT8 response[2];
    UINT32 response_len;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_UINT(delay_time);
    ICSLOG_DBG_HEX8(option);
    ICSLOG_DBG_UINT(timeout);

    /* send a ResetDevice command */
    command[0] = NFC110_COMMAND_CODE;
    command[1] = NFC110_CMD_RESET_DEVICE;
    command[2] = (UINT8)((delay_time >> 0) & 0xff);
    command[3] = (UINT8)((delay_time >> 8) & 0xff);
#if (NFC110_SUPPORTED_COMMAND_TYPE == 3)
    command[4] = option;
    command_len = 5;
#else
    command_len = 4;
#endif
    rc = nfc110_execute_command(nfc110,
                                command,
                                command_len,
                                sizeof(response),
                                response,
                                &response_len,
                                timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_execute_command()");
        if (rc == ICS_ERROR_BUF_OVERFLOW) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Buffer overflow.");
        }
        return rc;
    }
    if ((response_len != sizeof(response)) ||
        (response[0] != NFC110_RESPONSE_CODE) ||
        (response[1] != NFC110_RES_RESET_DEVICE)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response.");
        return rc;
    }

    /* send an ACK packet */
    rc = nfc110_send_ack(nfc110, NFC110_CANCEL_COMMAND_ACK_TIMEOUT);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_send_ack()");
        return rc;
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/* ------------------------
 * Internal
 * ------------------------ */

/**
 * This function gets information of command type.
 *
 * \param  nfc110         [IN] The handle to access the port.
 * \param  cmd_type      [OUT] Information of command type.
 * \param  timeout        [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Received an invalid response.
 */
static UINT32 nfc110_get_command_type(
    ICS_HW_DEVICE* nfc110,
    UINT8 cmd_type[NFC110_COMMAND_TYPE_LEN],
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_get_command_type"
    UINT32 rc;
    UINT8 command[2];
    UINT32 command_len;
    UINT8 response[10];
    UINT32 response_len;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_UINT(timeout);

    command[0] = NFC110_COMMAND_CODE;
    command[1] = NFC110_CMD_GET_COMMAND_TYPE;
    command_len = 2;
    rc = nfc110_execute_command(nfc110,
                                command,
                                command_len,
                                sizeof(response),
                                response,
                                &response_len,
                                timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_execute_command()");
        if (rc == ICS_ERROR_BUF_OVERFLOW) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Buffer overflow.");
        }
        return rc;
    }
    if ((response_len != 10) ||
        (response[0] != NFC110_RESPONSE_CODE) ||
        (response[1] != NFC110_RES_GET_COMMAND_TYPE)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response.");
        return rc;
    }

    if (cmd_type != NULL) {
        utl_memcpy(cmd_type, &response[2], NFC110_COMMAND_TYPE_LEN);
        ICSLOG_DUMP(cmd_type, NFC110_COMMAND_TYPE_LEN);
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function sends a command to the device and receives response.
 *
 * \param  nfc110                 [IN] The handle to access the port.
 * \param  command_buf        [IN/OUT] The buffer for command and response.
 *                                     The command should be placed at
 *                                     NFC110_COMMAND_POS.
 * \param  command_len            [IN] The length of the command.
 * \param  response_pos          [OUT] Start position of the recieved response.
 * \param  response_len          [OUT] The length of the response.
 * \param  timeout                [IN] Time-out period. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Invalid response.
 * \retval ICS_ERROR_BUF_OVERFLOW      Response buffer overflow.
 */
static UINT32 nfc110_execute_command_internal(
    ICS_HW_DEVICE* nfc110,
    UINT8 command_buf[NFC110_COMMAND_BUF_LEN],
    UINT32 command_len,
    UINT32* response_pos,
    UINT32* response_len,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_execute_command_internal"
    UINT32 rc;
    UINT8 dcs;
    UINT32 time0;
    UINT32 read_len;
    UINT32 n;
    BOOL ack_read;
    UINT32 preamble_len;
    ICSLOG_FUNC_BEGIN;

    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110)->write, NULL,
                     ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110)->read, NULL,
                     ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_IN_RANGE(command_len, 1, NFC110_MAX_COMMAND_LEN,
                           ICS_ERROR_INVALID_PARAM);

    preamble_len = 8; /* default */
    ack_read = FALSE;

    /* clear the queue for receiving */
    if (NFC110_RAW_FUNC(nfc110)->clear_rx_queue != NULL) {
        rc = NFC110_RAW_FUNC(nfc110)->clear_rx_queue(nfc110->handle);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc, "icsdrv_raw_clear_rx_queue()");
            return rc;
        }
    }

    time0 = utl_get_time_msec();

    /* send command (extended frame) */
    command_buf[NFC110_COMMAND_POS - 8] = 0x00;
    command_buf[NFC110_COMMAND_POS - 7] = 0x00;
    command_buf[NFC110_COMMAND_POS - 6] = 0xff;
    command_buf[NFC110_COMMAND_POS - 5] = 0xff;
    command_buf[NFC110_COMMAND_POS - 4] = 0xff;
    command_buf[NFC110_COMMAND_POS - 3] =
        (UINT8)((command_len >> 0) & 0xff);
    command_buf[NFC110_COMMAND_POS - 2] =
        (UINT8)((command_len >> 8) & 0xff);
    command_buf[NFC110_COMMAND_POS - 1] =
        (UINT8)-(command_buf[NFC110_COMMAND_POS - 3] +
        command_buf[NFC110_COMMAND_POS - 2]);

    dcs = nfc110_calc_dcs(command_buf + NFC110_COMMAND_POS, command_len);
    command_buf[NFC110_COMMAND_POS + command_len] = dcs;
    command_buf[NFC110_COMMAND_POS + command_len + 1] = 0x00;

    rc = NFC110_RAW_FUNC(nfc110)->write(nfc110->handle,
                                        command_buf,
                                        (preamble_len + command_len + 2),
                                        time0,
                                        timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "icsdrv_raw_write()");
        return rc;
    }

    /* receive ACK, response header */
    rc = NFC110_RAW_FUNC(nfc110)->read(nfc110->handle,
                                       6,
                                       NFC110_COMMAND_BUF_LEN,
                                       command_buf,
                                       &read_len,
                                       time0,
                                       timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "icsdrv_raw_read() - ack");
        return rc;
    }
    if (utl_memcmp(command_buf, "\x00\x00\xff\x00\xff\x00", 6) == 0) {
        NFC110_ACK_TIME(nfc110) = utl_get_time_msec();
        ICSLOG_DBG_UINT(NFC110_ACK_TIME(nfc110));

        ack_read = TRUE;
        read_len -= 6;
        utl_memcpy(command_buf, (command_buf + 6), read_len);

        if (read_len < 6) {
            n = read_len;
            rc = NFC110_RAW_FUNC(nfc110)->read(nfc110->handle,
                                               (6 - read_len),
                                               (NFC110_COMMAND_BUF_LEN - n),
                                               (command_buf + n),
                                               &read_len,
                                               time0,
                                               timeout);
            if (rc != ICS_ERROR_SUCCESS) {
                ICSLOG_ERR_STR(rc, "icsdrv_raw_read() - response header");
                return rc;
            }
            read_len += n;
        }
    }

    /* check header */
    if (utl_memcmp(command_buf, "\x00\x00\xff", 3) != 0) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response header.");
        return rc;
    }
    if ((command_buf[3] == 0xff) && (command_buf[4] == 0xff)) {
        /* extended frame */
        if (read_len < 9) {
            n = read_len;
            rc = NFC110_RAW_FUNC(nfc110)->read(nfc110->handle,
                                               (9 - read_len),
                                               (NFC110_COMMAND_BUF_LEN - n),
                                               (command_buf + n),
                                               &read_len,
                                               time0,
                                               timeout);
            if (rc != ICS_ERROR_SUCCESS) {
                ICSLOG_ERR_STR(rc, "icsdrv_raw_read() - response");
                return rc;
            }
            read_len += n;
        }
        if (((command_buf[5] + command_buf[6] + command_buf[7]) & 0xff) != 0) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Invalid response - lcs");
        }
        preamble_len = 8;
        *response_pos = 8;
        *response_len = (((UINT32)command_buf[5] << 0) |
                         ((UINT32)command_buf[6] << 8));
    } else {
        /* normal frame */
        if (((command_buf[3] + command_buf[4]) & 0xff) != 0) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Invalid response header.");
            return rc;
        }
        preamble_len = 5;
        *response_pos = 5;
        *response_len = command_buf[3];
    }
    ICSLOG_DBG_UINT(*response_pos);
    ICSLOG_DBG_UINT(*response_len);

    if (*response_len > NFC110_MAX_RESPONSE_LEN) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Too long response length.");
        return rc;
    }

    /* read the rest of packet */
    if (read_len < (preamble_len + *response_len + 2)) {
        n = ((preamble_len + *response_len + 2) - read_len);
        rc = NFC110_RAW_FUNC(nfc110)->read(nfc110->handle,
                                           n,
                                           n,
                                           (command_buf + read_len),
                                           NULL,
                                           time0,
                                           timeout);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc, "icsdrv_raw_read() - rest of packet");
            return rc;
        }
    }

    /* check response */
    dcs = nfc110_calc_dcs(command_buf + preamble_len, *response_len);
    if ((command_buf[preamble_len + *response_len + 0] != dcs) ||
        (command_buf[preamble_len + *response_len + 1] != 0x00)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response body.");
        return rc;
    }

    if (!ack_read) {
        NFC110_ACK_TIME(nfc110) = utl_get_time_msec();
        ICSLOG_DBG_UINT(NFC110_ACK_TIME(nfc110));
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function sweeps away unnecessary data.
 *
 * \param  nfc110                 [IN] The handle to access the port.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 */
static UINT32 nfc110_sweep(
    ICS_HW_DEVICE* nfc110)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_sweep"
    UINT32 rc;
    UINT32 time0;
    UINT8 purge_buf[64];
    const UINT8 zero_buf[NFC110_COMMAND_BUF_LEN] = {0};
    ICSLOG_FUNC_BEGIN;

    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(NFC110_RAW_FUNC(nfc110), NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);

    time0 = utl_get_time_msec();

    /* swept away the unnecessary data */
    if (NFC110_RAW_FUNC(nfc110)->write != NULL) {
        rc = NFC110_RAW_FUNC(nfc110)->write(
            nfc110->handle,
            zero_buf,
            sizeof(zero_buf),
            time0,
            NFC110_CANCEL_COMMAND_SWEEP_TIME_OUT);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc, "icsdrv_raw_func->write()");
            return rc;
        }
    }

    /* send an ACK packet */
    rc = nfc110_send_ack(nfc110, NFC110_CANCEL_COMMAND_ACK_TIMEOUT);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_send_ack()");
        return rc;
    }

    /* drain the transmitting queue */
    if (NFC110_RAW_FUNC(nfc110)->drain_tx_queue != NULL) {
        rc = NFC110_RAW_FUNC(nfc110)->drain_tx_queue(nfc110->handle);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc, "icsdrv_raw_func->drain_tx_queue()");
            return rc;
        }
    }
    rc = utl_msleep(1);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "utl_msleep()");
        return rc;
    }

    /* purge the received packet */
    rc = ICS_ERROR_TIMEOUT;
    do {
        if (NFC110_RAW_FUNC(nfc110)->read != NULL) {
            time0 = utl_get_time_msec();
            rc = NFC110_RAW_FUNC(nfc110)->read(
                nfc110->handle,
                1,
                sizeof(purge_buf),
                purge_buf,
                NULL,
                time0,
                NFC110_CANCEL_COMMAND_PURGE_TIMEOUT);
            if (rc == ICS_ERROR_SUCCESS) {
                continue;
            } else if (rc == ICS_ERROR_TIMEOUT) {
                break;
            } else {
                ICSLOG_ERR_STR(rc, "icsdrv_raw_func->read()");
                if (rc == ICS_ERROR_BUF_OVERFLOW) {
                    rc = ICS_ERROR_IO;
                    ICSLOG_ERR_STR(rc, "Buffer overflow.");
                }
                return rc;
            }
        }
    } while (rc != ICS_ERROR_TIMEOUT);

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function calculates the DCS of a data.
 *
 * \param  data                   [IN] A data.
 * \param  data_len               [IN] The length of the data.
 *
 * \return The DCS of the data.
 */
static UINT8 nfc110_calc_dcs(
    const UINT8* data,
    UINT32 data_len)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_calc_dcs"
    UINT8 sum;
    UINT32 i;
    UINT8 dcs;
    ICSLOG_FUNC_BEGIN;

    sum = 0;
    for (i = 0; i < data_len; i++) {
        sum += data[i];
    }
    dcs = (UINT8)-(sum & 0xff);
    ICSLOG_DBG_HEX8(dcs);

    ICSLOG_FUNC_END;
    return dcs;
}

/**
 * This function converts the status at device to return code.
 *
 * \param  status                 [IN] The status at device.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_DEVICE            Error at device.
 */
static UINT32 nfc110_convert_dev_status(
    UINT8 status)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_convert_dev_status"
    UINT32 rc;
    ICSLOG_FUNC_BEGIN;

    ICSLOG_DBG_HEX8(status);

    switch (status) {
    case NFC110_DEV_STATUS_SUCCESS:
        rc = ICS_ERROR_SUCCESS;
        break;
    case NFC110_DEV_STATUS_RFCA_ERROR:
        rc = ICS_ERROR_TIMEOUT;
        break;
    case NFC110_DEV_STATUS_INTTEMPRFOFF_ERROR:
        rc = ICS_ERROR_INTTEMP_RF_OFF;
        break;
    case NFC110_DEV_STATUS_PARAMETER_ERROR:
    case NFC110_DEV_STATUS_PB_ERROR:
    case NFC110_DEV_STATUS_TEMPERATURE_ERROR:
    case NFC110_DEV_STATUS_PWD_ERROR:
    case NFC110_DEV_STATUS_RECEIVE_ERROR:
    case NFC110_DEV_STATUS_COMMANDTYPE_ERROR:
    default:
        ICSLOG_ERR_STR(status, "status error at device");
        rc = ICS_ERROR_DEVICE;
        break;
    }
    ICSLOG_DBG_UINT(rc);

    ICSLOG_FUNC_END;
    return rc;
}

/**
 * This function converts the rf communication status to return code.
 *
 * \param  status                 [IN] The rf communication status.(Bitmap)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_RF_OFF            RF was turned off.
 * \retval ICS_ERROR_FRAME_CRC         CRC error.
 * \retval ICS_ERROR_DEVICE            Error at device.
 */
static UINT32 nfc110_convert_rf_status(
    UINT32 status)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_convert_rf_status"
    UINT32 rc;
    ICSLOG_FUNC_BEGIN;

    ICSLOG_DBG_HEX(status);

    rc = ICS_ERROR_SUCCESS;
    if (((status & NFC110_RF_STATUS_REC_TIMEOUT_ERROR) != 0) ||
        ((status & NFC110_RF_STATUS_TRA_TIMEOUT_ERROR) != 0) ||
        ((status & NFC110_RF_STATUS_RFCA_ERROR) != 0)) {
        rc = ICS_ERROR_TIMEOUT;
        ICSLOG_ERR_STR(rc, "Time-out at the device.");
    } else if ((status & NFC110_RF_STATUS_RF_OFF) != 0) {
        rc = ICS_ERROR_RF_OFF;
        ICSLOG_ERR_STR(rc, "RF was turned off.");
    } else if (((status & NFC110_RF_STATUS_PARITY_ERROR) != 0) ||
               ((status & NFC110_RF_STATUS_CRC_ERROR) != 0)) {
        rc = ICS_ERROR_FRAME_CRC;
        ICSLOG_ERR_STR(rc, "CRC error.");
    } else if ((status & NFC110_RF_STATUS_INTTEMPRFOFF_ERROR) != 0) {
        rc = ICS_ERROR_INTTEMP_RF_OFF;
        ICSLOG_ERR_STR(rc, "Temperature error at the device.");
    } else if (status != NFC110_RF_STATUS_SUCCESS) {
        rc = ICS_ERROR_DEVICE;
        ICSLOG_ERR_STR(rc, "Error at the device.");
    }
    ICSLOG_DBG_UINT(rc);

    ICSLOG_FUNC_END;
    return rc;
}
