/**
 * \brief    The stub functions binding felica_cc to nfc110usb.
 * \date     2013/05/14
 * \author   Copyright 2011,2013 Sony Corporation
 */

#undef ICSLOG_MODULE
#define ICSLOG_MODULE "fcg"

#include "ics_types.h"
#include "ics_error.h"
#include "icslib_chk.h"
#include "icslog.h"
#include "utl.h"
#include "nfc110.h"
#include "felica_cc.h"
#include "stub/felica_cc_stub_nfc110.h"

/* --------------------------------
 * Constant
 * -------------------------------- */

#define FELICA_CC_STUB_NFC110_ADD_TIMEOUT               300
#define FELICA_CC_STUB_NFC110_MIN_SPEED                 NFC110_BLE_SPEED

#define FELICA_CC_STUB_NFC110_IN_SET_PROTOCOL_TIMEOUT   2500  /* TODO */
#define FELICA_CC_STUB_NFC110_IN_SET_RF_TIMEOUT         1500  /* TODO */

/* Default RBT */
#define FELICA_CC_STUB_NFC110_RBT       NFC110_RBT_INITIATOR_ISO18092_212K
#define FELICA_CC_STUB_NFC110_SPEED     NFC110_RF_INITIATOR_ISO18092_212K

/* --------------------------------
 * Prototype Declaration
 * -------------------------------- */

static UINT32 felica_cc_stub_nfc110_polling(
    void* dev,
    const UINT8 polling_param[4],
    UINT32 max_num_of_cards,
    UINT32* num_of_cards,
    felica_card_t* cards,
    felica_card_option_t* card_options,
    UINT32 timeout);
static UINT32 felica_cc_stub_nfc110_thru(
    void* dev,
    const UINT8* command,
    UINT32 command_len,
    UINT32 max_response_len,
    UINT8* response,
    UINT32* response_len,
    UINT32 timeout);

static UINT32 felica_cc_stub_nfc110_setup_initiator(
    ICS_HW_DEVICE* nfc110,
    UINT32 max_num_of_cards);

/* --------------------------------
 * Macro
 * -------------------------------- */

#define FELICA_CC_STUB_UNIT_MS(x) \
    ((((x) + 13560) - 1) / 13560) /* = x/fc (ms) */

#define FELICA_CC_STUB_T_DELAY      FELICA_CC_STUB_UNIT_MS(512 * 64)
#define FELICA_CC_STUB_T_TIMESLOT   FELICA_CC_STUB_UNIT_MS(256 * 64)

/* --------------------------------
 * Function
 * -------------------------------- */

/* ------------------------
 * Exported
 * ------------------------ */

/**
 * This function initializes the device structure for felica_cc.
 *
 * \param  devf                  [OUT] The device structure for felica_cc.
 * \param  nfc110_dev             [IN] The device structure for nfc110.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid argument.
 */
UINT32 felica_cc_stub_nfc110_initialize(
    felica_cc_devf_t* devf,
    ICS_HW_DEVICE* nfc110_dev)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "felica_cc_stub_nfc110_initialize"
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(devf, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(nfc110_dev, NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(devf);
    ICSLOG_DBG_PTR(nfc110_dev);

    /* initialize the members */
    devf->dev = nfc110_dev;
    devf->polling_func = felica_cc_stub_nfc110_polling;
    devf->thru_func = felica_cc_stub_nfc110_thru;

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/* ------------------------
 * Internal
 * ------------------------ */

/**
 * This function detects remote cards using Polling command.
 *
 * \param  dev                    [IN] My ICS device.
 * \param  polling_param          [IN] Polling command except for command code.
 * \param  max_num_of_cards       [IN] The maximum number of cards to detect.
 * \param  num_of_cards          [OUT] The number of detected cards.
 * \param  cards                 [OUT] Detected cards.
 * \param  card_options          [OUT] Options of the detected cards.
 * \param  timeout                [IN] Time-out period.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Received an invalid response packet.
 * \retval ICS_ERROR_BUF_OVERFLOW      The number of cards exceeded the limit.
 */
static UINT32 felica_cc_stub_nfc110_polling(
    void* dev,
    const UINT8 polling_param[4],
    UINT32 max_num_of_cards,
    UINT32* num_of_cards,
    felica_card_t* cards,
    felica_card_option_t* card_options,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "felica_cc_stub_nfc110_polling"
    UINT32 rc;
    ICS_HW_DEVICE* nfc110;
    UINT8 felica_command[10];
    UINT8 felica_response[7 + 290];
    UINT32 felica_response_len;
    UINT32 response_timeout;
    UINT32 rest_len;
    UINT32 pos;
    UINT32 n;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(polling_param, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_BE(max_num_of_cards, 1, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(num_of_cards, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(cards, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(card_options, NULL, ICS_ERROR_INVALID_PARAM);

    /* set up NFC Port-110 for initiator mode */
    nfc110 = dev;
    rc = felica_cc_stub_nfc110_setup_initiator(nfc110, max_num_of_cards);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "felica_cc_stub_nfc110_setup_initiator()");
        return rc;
    }

    /* make a Polling command for NFC Port-110 */
    felica_command[0] = 6;
    felica_command[1] = 0x00;
    utl_memcpy((felica_command + 2), polling_param, 4);

    response_timeout = (FELICA_CC_STUB_T_DELAY +
                        (polling_param[3] + 1) * FELICA_CC_STUB_T_TIMESLOT);
    ICSLOG_DBG_UINT(response_timeout);

    /* send the Polling command to NFC Port-110 */
    rc = nfc110_rf_command(nfc110,
                           felica_command,
                           6,
                           sizeof(felica_response),
                           felica_response,
                           &felica_response_len,
                           NULL,
                           NULL,
                           FALSE,
                           response_timeout,
                           timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_felica_command()");
        if (rc == ICS_ERROR_BUF_OVERFLOW) {
            rc = ICS_ERROR_INVALID_RESPONSE;
            ICSLOG_ERR_STR(rc, "Buffer overflow.");
        }
        return rc;
    }
    if (felica_response_len < 18) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response.");
        return rc;
    }

    /* parse the response from multi cards */
    rest_len = felica_response_len;
    pos = 0;
    n = 0;

    while (rest_len > 0) {
        if (((felica_response[pos] != 18) &&
             (felica_response[pos] != 20)) ||
            (felica_response[pos + 1] != 0x01)) {
            /* Invalid polling response */
            break;
        }

        if (n >= max_num_of_cards) {
            *num_of_cards = n;
            ICSLOG_DBG_UINT(*num_of_cards);

            rc = ICS_ERROR_BUF_OVERFLOW;
            ICSLOG_ERR_STR(rc, "The number of cards exceeded the limit.");
            return rc;
        }

        utl_memcpy(cards[n].idm, (felica_response + pos +  2), 8);
        utl_memcpy(cards[n].pmm, (felica_response + pos + 10), 8);

        if ((felica_response[pos] == 20) && (card_options != NULL)) {
            card_options[n].option_len = 2;
            utl_memcpy(card_options[n].option,
                       (felica_response + pos + 18), 2);
        } else if (card_options != NULL) {
            card_options[n].option_len = 0;
        }

        rest_len -= felica_response[pos];
        pos += felica_response[pos];
        n++;
    }
    if (n == 0) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response.");
        return rc;
    }

    *num_of_cards = n;
    ICSLOG_DBG_UINT(*num_of_cards);

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function sends the FeliCa card command and receives a response.
 *
 * \param  dev                    [IN] My ICS device.
 * \param  command                [IN] The card command to send.
 * \param  command_len            [IN] The length of the card command.
 * \param  max_response_len       [IN] The maximum length of response.
 * \param  response              [OUT] Received response.
 * \param  response_len          [OUT] The length of the response.
 * \param  timeout                [IN] Time-out. (ms)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_DEVICE            Error at device.
 * \retval ICS_ERROR_FRAME_CRC         CRC error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Received an invalid response packet.
 * \retval ICS_ERROR_BUF_OVERFLOW      The length of the received response
 *                                     exceeded max_response_len.
 */
static UINT32 felica_cc_stub_nfc110_thru(
    void* dev,
    const UINT8* command,
    UINT32 command_len,
    UINT32 max_response_len,
    UINT8* response,
    UINT32* response_len,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "felica_cc_stub_nfc110_thru"
    UINT32 rc;
    ICS_HW_DEVICE* nfc110;
    UINT32 speed;
    UINT32 nbits;
    UINT32 add_time;
    UINT32 driver_timeout;
    ICSLOG_FUNC_BEGIN;

    /* check the parameter */
    ICSLIB_CHKARG_LE(command_len,
                     FELICA_CC_STUB_NFC110_MAX_COMMAND_LEN,
                     ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(dev, NULL, ICS_ERROR_INVALID_PARAM);

    /* calculate additional time */
    nfc110 = dev;
    speed = NFC110_SPEED(nfc110);
    if (speed < FELICA_CC_STUB_NFC110_MIN_SPEED) {
        speed = FELICA_CC_STUB_NFC110_MIN_SPEED;
    }

    /*
     * extra timeout period between the controller and NFC Port-110
     *
     * 15 + command_len:command packet size
     * 6:ack packet size
     * 14 + MAX_RESPONSE_LEN:response packet size(max)
     * 10:1 byte = 10 bits
     */
    nbits = (((15 + command_len) + 6 +
              (14 + FELICA_CC_STUB_NFC110_MAX_RESPONSE_LEN)) * 10);
    add_time = (((nbits * 1000) + (speed - 1)) / speed);

    /*
     * extra timeout period for RF communication between
     * NFC Port-110 and the card,
     * calculated by assuming the worst case (Largest command and response)
     *
     * Command len  = Preamble + Sync Code + LEN + MAX_COMMAND_LEN + CRC
     *              = 6 + 2 + 1 + MAX_COMMAND_LEN + 2
     *              = MAX_COMMAND_LEN + 11
     * Response len (without preamble and sync code because they are already
     *               included in the timeout)
     *              = LEN + MAX_RESPONSE_LEN + CRC
     *              = 1 + MAX_RESPONSE_LEN + 2
     *              = MAX_RESPONSE_LEN + 3
     * RF Speed     = 212kbps by assumption
     * Bits per byte = 8
     */
    add_time +=
        (((FELICA_CC_STUB_NFC110_MAX_COMMAND_LEN + 11 +
           FELICA_CC_STUB_NFC110_MAX_RESPONSE_LEN + 3) * 8 * 1000) / 211875);

    /* extra timeout for period in the controller and NFC Port-110 */
    add_time += FELICA_CC_STUB_NFC110_ADD_TIMEOUT;

    if ((0xffffffff - add_time) >= timeout) {
        driver_timeout = (timeout + add_time);
    } else {
        driver_timeout = 0xffffffff;
    }

    /* transceive the command */
    rc = nfc110_felica_command(nfc110,
                               command,
                               command_len,
                               max_response_len,
                               response,
                               response_len,
                               timeout,
                               driver_timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "nfc110_felica_command()");
        return rc;
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function sets up NFC Port-110 for initiator mode.
 *
 * \param  nfc110                 [IN] NFC Port-110 device.
 * \param  max_num_of_cards       [IN] The maximum number of cards to detect.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid parameter.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Received an invalid response packet.
 */
static UINT32 felica_cc_stub_nfc110_setup_initiator(
    ICS_HW_DEVICE* nfc110,
    UINT32 max_num_of_cards)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "felica_cc_stub_nfc110_setup_initiator"
    UINT32 rc;
    UINT8 setting[NFC110_MAX_IN_SET_PROTOCOL_SETTING_NUM * 2];
    UINT32 setting_len;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(nfc110, NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_UINT(max_num_of_cards);

    if (NFC110_LAST_MODE(nfc110) != NFC110_MODE_INITIATOR_TYPEF) {
        /* make and send an InSetRF command for NFC Port-110 */
        rc = nfc110_set_rf_speed(
            nfc110,
            FELICA_CC_STUB_NFC110_RBT,
            FELICA_CC_STUB_NFC110_SPEED,
            FELICA_CC_STUB_NFC110_RBT,
            FELICA_CC_STUB_NFC110_SPEED,
            FELICA_CC_STUB_NFC110_IN_SET_RF_TIMEOUT);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc, "nfc110_set_rf_speed()");
            return rc;
        }

        /* send an InSetProtocol command for NFC Port-110 */
        setting_len = sizeof(nfc110_felica_default_protocol);
        utl_memcpy(setting, nfc110_felica_default_protocol, setting_len);
        if (max_num_of_cards > 1) {
            setting[7] = 0x01; /* Multi card = on */
        } else {
            setting[7] = 0x00; /* Multi card = off */
        }

        rc = nfc110_set_protocol(
            nfc110, setting, setting_len,
            FELICA_CC_STUB_NFC110_IN_SET_PROTOCOL_TIMEOUT);

        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc, "nfc110_set_protocol()");
            return rc;
        }
        NFC110_SET_LAST_MODE(nfc110, NFC110_MODE_INITIATOR_TYPEF);
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}
