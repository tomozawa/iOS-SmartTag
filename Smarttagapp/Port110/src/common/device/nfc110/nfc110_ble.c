/**
 * \brief    NFC Port-110 BLE Driver
 * \date     2013/03/20
 * \author   Copyright 2013 Sony Corporation
 */

#undef ICSLOG_MODULE
#define ICSLOG_MODULE "DBB"

#include "ics_types.h"
#include "ics_error.h"
#include "icslib_chk.h"
#include "icslog.h"
#include "utl.h"

#include "nfc110_ble.h"

/* --------------------------------
 * Function
 * -------------------------------- */

/* ------------------------
 * Exported
 * ------------------------ */

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
UINT32 nfc110_ble_open(
    ICS_HW_DEVICE* nfc110,
    const char* port_name)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "nfc110_ble_open"
    UINT32 rc;
    ICSLOG_FUNC_BEGIN;

    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(port_name, NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(nfc110);
    ICSLOG_DBG_STR(port_name);

    rc = nfc110_initialize(nfc110, &nfc110_ble_raw_func);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_initialize()");
        return rc;
    }

    rc = nfc110_open(nfc110, port_name);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_open()");
        return rc;
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}
