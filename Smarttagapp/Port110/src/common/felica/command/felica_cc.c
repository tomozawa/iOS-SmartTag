/**
 * \brief    The Felica Card Command Library
 * \date     2008/10/14
 * \author   Copyright 2005,2006,2007,2008 Sony Corporation
 */

#undef ICSLOG_MODULE
#define ICSLOG_MODULE "FCC"

#include "ics_types.h"
#include "ics_error.h"
#include "icslib_chk.h"
#include "icslog.h"
#include "utl.h"
#include "felica_cc.h"

/* --------------------------------
 * Constant
 * -------------------------------- */

#define FELICA_CC_CMD_POLLING                   0x00
#define FELICA_CC_RES_POLLING                   0x01
#define FELICA_CC_CMD_REQUEST_SERVICE           0x02
#define FELICA_CC_RES_REQUEST_SERVICE           0x03
#define FELICA_CC_CMD_REQUEST_RESPONSE          0x04
#define FELICA_CC_RES_REQUEST_RESPONSE          0x05
#define FELICA_CC_CMD_READ_WITHOUT_ENCRYPTION   0x06
#define FELICA_CC_RES_READ_WITHOUT_ENCRYPTION   0x07
#define FELICA_CC_CMD_WRITE_WITHOUT_ENCRYPTION  0x08
#define FELICA_CC_RES_WRITE_WITHOUT_ENCRYPTION  0x09
#define FELICA_CC_CMD_REQUEST_SYSTEM_CODE       0x0c
#define FELICA_CC_RES_REQUEST_SYSTEM_CODE       0x0d

/* --------------------------------
 * Prototype Declaration
 * -------------------------------- */

static UINT32 felica_cc_thru_polling(
    const felica_cc_devf_t* devf,
    const UINT8 polling_param[4],
    felica_card_t* card,
    felica_card_option_t* card_option,
    UINT32 timeout);

/* --------------------------------
 * Macro
 * -------------------------------- */

/* --------------------------------
 * Function
 * -------------------------------- */

/* ------------------------
 * Exported
 * ------------------------ */

/**
 * This function detects a remote card using Polling command.
 *
 * \param  devf                   [IN] My device.
 * \param  polling_param          [IN] Polling command except for command code.
 * \param  card                  [OUT] Detected card.
 * \param  card_option           [OUT] Option of the detected card.
 * \param  timeout                [IN] Time-out period.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid argument.
 * \retval ICS_ERROR_TIMEOUT           Not detected.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_DEVICE            Error at device.
 * \retval ICS_ERROR_FRAME_CRC         CRC error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Received an invalid response packet.
 */
UINT32 felica_cc_polling(
    const felica_cc_devf_t* devf,
    const UINT8 polling_param[4],
    felica_card_t* card,
    felica_card_option_t* card_option,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "felica_cc_polling"
    UINT32 rc;
    UINT32 num_of_cards;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(devf, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(polling_param, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(card, NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(devf);
    ICSLOG_DUMP(polling_param, 4);
    ICSLOG_DBG_UINT(timeout);

    rc = felica_cc_polling_multiple(devf, polling_param, 1,
                                    &num_of_cards, card, card_option, timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "felica_cc_polling_multiple()");
        return rc;
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function detects remote cards using Polling command.
 *
 * \param  devf                   [IN] My device.
 * \param  polling_param          [IN] Polling command except for command code.
 * \param  max_num_of_cards       [IN] The maximum number of cards to detect.
 * \param  num_of_cards          [OUT] The number of detected cards.
 * \param  cards                 [OUT] Detected cards.
 * \param  card_options          [OUT] Options of the detected cards.
 * \param  timeout                [IN] Time-out period.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid argument.
 * \retval ICS_ERROR_TIMEOUT           Not detected.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_DEVICE            Error at device.
 * \retval ICS_ERROR_FRAME_CRC         CRC error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Received an invalid response packet.
 * \retval ICS_ERROR_BUF_OVERFLOW      The number of cards exceeded the limit.
 */
UINT32 felica_cc_polling_multiple(
    const felica_cc_devf_t* devf,
    const UINT8 polling_param[4],
    UINT32 max_num_of_cards,
    UINT32* num_of_cards,
    felica_card_t* cards,
    felica_card_option_t* card_options,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "felica_cc_polling_multiple"
    UINT32 rc;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(devf, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(polling_param, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_BE(max_num_of_cards, 1, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(num_of_cards, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(cards, NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(devf);
    ICSLOG_DUMP(polling_param, 4);
    ICSLOG_DBG_UINT(max_num_of_cards);
    ICSLOG_DBG_UINT(timeout);

    if (devf->polling_func == NULL) {
        rc = felica_cc_thru_polling(devf, polling_param, cards, card_options,
                                    timeout);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc, "felica_cc_thru_polling()");
            return rc;
        }
        *num_of_cards = 1;
    } else {
        rc = devf->polling_func(devf->dev, polling_param, max_num_of_cards,
                                num_of_cards, cards, card_options, timeout);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc, "polling_func()");
            return rc;
        }
    }

    ICSLOG_DBG_UINT(*num_of_cards);

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function sends a Request Service command to the card.
 *
 * \param  devf                   [IN] My device.
 * \param  card                   [IN] The card to communicate.
 * \param  num_of_nodes           [IN] The number of nodes to request.
 * \param  node_code_list         [IN] The node code list.
 * \param  node_key_version_list [OUT] The key version list of the nodes.
 * \param  timeout                [IN] Time-out period.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid argument.
 * \retval ICS_ERROR_TIMEOUT           No response.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_DEVICE            Error at device.
 * \retval ICS_ERROR_FRAME_CRC         CRC error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Received an invalid response packet.
 */
UINT32 felica_cc_request_service(
    const felica_cc_devf_t* devf,
    const felica_card_t* card,
    UINT8 num_of_nodes,
    const UINT16* node_code_list,
    UINT16* node_key_version_list,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "felica_cc_request_service"
    UINT32 rc;
    UINT8 buf[FELICA_CC_MAX_COMMAND_LEN];
    UINT32 command_len;
    UINT32 response_len;
    UINT i;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(devf, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(devf->thru_func, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(card, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(node_code_list, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(node_key_version_list, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_IN_RANGE(num_of_nodes,
                           FELICA_CC_REQUEST_SERVICE_NUM_OF_NODES_MIN,
                           FELICA_CC_REQUEST_SERVICE_NUM_OF_NODES_MAX,
                           ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(devf);
    ICSLOG_DBG_PTR(card);
    ICSLOG_DBG_UINT(num_of_nodes);
    ICSLOG_DUMP(node_code_list, 2 * num_of_nodes);
    ICSLOG_DBG_UINT(timeout);

    /* make a command packet */
    buf[0] = FELICA_CC_CMD_REQUEST_SERVICE;
    utl_memcpy(buf + 1, card->idm, 8);
    buf[9] = num_of_nodes;
    for (i = 0; i < num_of_nodes; i++) {
        buf[10 + (i * 2) + 0] = ((node_code_list[i] >> 0) & 0xff);
        buf[10 + (i * 2) + 1] = ((node_code_list[i] >> 8) & 0xff);
    }
    command_len = (1 + 8 + 1 + (2 * num_of_nodes));

    /* send the command and receive a response */
    rc = devf->thru_func(devf->dev, buf, command_len,
                         sizeof(buf), buf, &response_len,
                         timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "thru_func()");
        return rc;
    }

    /* check the response */
    if ((response_len < (UINT32)(1 + 8 + 1 + (2 * num_of_nodes))) ||
        (buf[0] != FELICA_CC_RES_REQUEST_SERVICE) ||
        (utl_memcmp(buf + 1, card->idm, 8) != 0) ||
        (buf[9] != num_of_nodes)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Received an invalid response.");
        return rc;
    }

    /* decode the response */
    for (i = 0; i < num_of_nodes; i++) {
        node_key_version_list[i] = (((UINT16)buf[10 + (i * 2) + 0] << 0) |
                                    ((UINT16)buf[10 + (i * 2) + 1] << 8));
    }

    ICSLOG_DUMP(node_key_version_list, 2 * num_of_nodes);

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function sends a Request Response command to the card.
 *
 * \param  devf                   [IN] My device.
 * \param  card                   [IN] The card to communicate.
 * \param  mode                  [OUT] The current mode of the card.
 * \param  timeout                [IN] Time-out period.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid argument.
 * \retval ICS_ERROR_TIMEOUT           No response.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_DEVICE            Error at device.
 * \retval ICS_ERROR_FRAME_CRC         CRC error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Received an invalid response packet.
 */
UINT32 felica_cc_request_response(
    const felica_cc_devf_t* devf,
    const felica_card_t* card,
    UINT8* mode,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "felica_cc_request_response"
    UINT32 rc;
    UINT8 buf[FELICA_CC_MAX_COMMAND_LEN];
    UINT32 command_len;
    UINT32 response_len;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(devf, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(devf->thru_func, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(card, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(mode, NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(devf);
    ICSLOG_DBG_PTR(card);
    ICSLOG_DBG_UINT(timeout);

    /* make a command packet */
    buf[0] = FELICA_CC_CMD_REQUEST_RESPONSE;
    utl_memcpy(buf + 1, card->idm, 8);
    command_len = (1 + 8);

    /* send the command and receive a response */
    rc = devf->thru_func(devf->dev, buf, command_len,
                         sizeof(buf), buf, &response_len,
                         timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "thru_func()");
        return rc;
    }

    /* check the response */
    if ((response_len < (1 + 8 + 1)) ||
        (buf[0] != FELICA_CC_RES_REQUEST_RESPONSE) ||
        (utl_memcmp(buf + 1, card->idm, 8) != 0)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Received an invalid response.");
        return rc;
    }

    /* decode the response */
    *mode = buf[9];

    ICSLOG_DBG_HEX8(*mode);

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function sends a Read Without Encryption command to the card.
 *
 * \param  devf                   [IN] My device.
 * \param  card                   [IN] The card to communicate.
 * \param  num_of_services        [IN] The number of the services.
 * \param  service_code_list      [IN] The service code list.
 * \param  num_of_blocks          [IN] The number of blocks.
 * \param  block_list             [IN] The block list.
 * \param  block_data            [OUT] The block data.
 * \param  status_flag1          [OUT] Status flag 1.
 * \param  status_flag2          [OUT] Status flag 2.
 * \param  timeout                [IN] Time-out period.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid argument.
 * \retval ICS_ERROR_TIMEOUT           No response.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_DEVICE            Error at device.
 * \retval ICS_ERROR_FRAME_CRC         CRC error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Received an invalid response packet.
 * \retval ICS_ERROR_STATUS_FLAG1      Status flag1 is not 0.
 */
UINT32 felica_cc_read_without_encryption(
    const felica_cc_devf_t* devf,
    const felica_card_t* card,
    UINT8 num_of_services,
    const UINT16* service_code_list,
    UINT8 num_of_blocks,
    const UINT8* block_list,
    UINT8* block_data,
    UINT8* status_flag1,
    UINT8* status_flag2,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "felica_cc_read_without_encryption"
    UINT32 rc;
    UINT i;
    const UINT8* p;
    UINT8 buf[FELICA_CC_MAX_COMMAND_LEN];
    UINT32 command_len;
    UINT32 response_len;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(devf, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(devf->thru_func, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(card, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_IN_RANGE(num_of_services,
                           FELICA_CC_READ_WE_NUM_OF_SERVICES_MIN,
                           FELICA_CC_READ_WE_NUM_OF_SERVICES_MAX,
                           ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(service_code_list, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_IN_RANGE(num_of_blocks,
                           FELICA_CC_READ_WE_NUM_OF_BLOCKS_MIN,
                           FELICA_CC_READ_WE_NUM_OF_BLOCKS_MAX,
                           ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(block_list, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(block_data, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(status_flag1, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(status_flag2, NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(devf);
    ICSLOG_DBG_PTR(card);
    ICSLOG_DBG_UINT(num_of_services);
    ICSLOG_DUMP(service_code_list, 2 * num_of_services);
    ICSLOG_DBG_UINT(num_of_blocks);
    ICSLOG_DBG_UINT(timeout);

    /* make a command packet */
    buf[0] = FELICA_CC_CMD_READ_WITHOUT_ENCRYPTION;
    utl_memcpy(buf + 1, card->idm, 8);
    buf[9] = num_of_services;
    for (i = 0; i < num_of_services; i++) {
        buf[10 + (i * 2) + 0] = (UINT8)((service_code_list[i] >>  0) & 0xff);
        buf[10 + (i * 2) + 1] = (UINT8)((service_code_list[i] >>  8) & 0xff);
    }
    command_len = (1 + 8 + 1 + (2 * num_of_services));
    buf[command_len] = num_of_blocks;
    command_len++;
    p = block_list;
    for (i = 0; i < num_of_blocks; i++) {
        if (*p & 0x80) {
            p += 2;
        } else {
            p += 3;
        }
    }
    utl_memcpy(buf + command_len, block_list, (p - block_list));
    command_len += (p - block_list);

    /* send the command and receive a response */
    rc = devf->thru_func(devf->dev, buf, command_len,
                         sizeof(buf), buf, &response_len,
                         timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "thru_func()");
        return rc;
    }

    /* check the response */
    if ((response_len < (1 + 8 + 2)) ||
        (buf[0] != FELICA_CC_RES_READ_WITHOUT_ENCRYPTION) ||
        (utl_memcmp(buf + 1, card->idm, 8) != 0)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Received an invalid response.");
        return rc;
    }

    /* decode the response */
    *status_flag1 = buf[9];
    *status_flag2 = buf[10];
    ICSLOG_DBG_HEX8(*status_flag1);
    ICSLOG_DBG_HEX8(*status_flag2);

    if (*status_flag1 != 0) {
        rc = ICS_ERROR_STATUS_FLAG1;
        ICSLOG_ERR_STR(rc, "Status flag1 is not 0.");
        return rc;
    }

    if ((response_len < (UINT32)(1 + 8 + 3 + (16 * num_of_blocks))) ||
        (buf[11] != num_of_blocks)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Received an invalid response.");
        return rc;
    }
    utl_memcpy(block_data, buf + 12, 16 * num_of_blocks);

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function sends a Write Without Encryption command to the card.
 *
 * \param  devf                   [IN] My device.
 * \param  card                   [IN] The card to communicate.
 * \param  num_of_services        [IN] The number of the services.
 * \param  service_code_list      [IN] The service code list.
 * \param  num_of_blocks          [IN] The number of blocks.
 * \param  block_list             [IN] The block list.
 * \param  block_data             [IN] The block data to write.
 * \param  status_flag1          [OUT] Status flag 1.
 * \param  status_flag2          [OUT] Status flag 2.
 * \param  timeout                [IN] Time-out period.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid argument.
 * \retval ICS_ERROR_TIMEOUT           No response.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_DEVICE            Error at device.
 * \retval ICS_ERROR_FRAME_CRC         CRC error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Received an invalid response packet.
 * \retval ICS_ERROR_STATUS_FLAG1      Status flag1 is not 0.
 */
UINT32 felica_cc_write_without_encryption(
    const felica_cc_devf_t* devf,
    const felica_card_t* card,
    UINT8 num_of_services,
    const UINT16* service_code_list,
    UINT8 num_of_blocks,
    const UINT8* block_list,
    const UINT8* block_data,
    UINT8* status_flag1,
    UINT8* status_flag2,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "felica_cc_write_without_encryption"
    UINT32 rc;
    UINT32 i;
    const UINT8* p;
    UINT8 buf[FELICA_CC_MAX_COMMAND_LEN];
    UINT command_len;
    UINT32 response_len;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(devf, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(devf->thru_func, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(card, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_IN_RANGE(num_of_services,
                           FELICA_CC_WRITE_WE_NUM_OF_SERVICES_MIN,
                           FELICA_CC_WRITE_WE_NUM_OF_SERVICES_MAX,
                           ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(service_code_list, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_IN_RANGE(num_of_blocks,
                           FELICA_CC_WRITE_WE_NUM_OF_BLOCKS_MIN,
                           FELICA_CC_WRITE_WE_NUM_OF_BLOCKS_MAX,
                           ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(block_list, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(block_data, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(status_flag1, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(status_flag2, NULL, ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(devf);
    ICSLOG_DBG_PTR(card);
    ICSLOG_DBG_UINT(num_of_services);
    ICSLOG_DUMP(service_code_list, 2 * num_of_services);
    ICSLOG_DBG_UINT(num_of_blocks);
    ICSLOG_DBG_UINT(timeout);

    /* make a command packet */
    buf[0] = FELICA_CC_CMD_WRITE_WITHOUT_ENCRYPTION;
    utl_memcpy(buf + 1, card->idm, 8);
    buf[9] = num_of_services;
    for (i = 0; i < num_of_services; i++) {
        buf[10 + (i * 2) + 0] = (UINT8)((service_code_list[i] >>  0) & 0xff);
        buf[10 + (i * 2) + 1] = (UINT8)((service_code_list[i] >>  8) & 0xff);
    }
    command_len = (1 + 8 + 1 + (2 * num_of_services));
    buf[command_len] = num_of_blocks;
    command_len++;
    p = block_list;
    for (i = 0; i < num_of_blocks; i++) {
        if (*p & 0x80) {
            p += 2;
        } else {
            p += 3;
        }
    }
    utl_memcpy(buf + command_len, block_list, (p - block_list));
    command_len += (p - block_list);

    if ((command_len + (16 * num_of_blocks)) > FELICA_CC_MAX_COMMAND_LEN) {
        rc = ICS_ERROR_INVALID_PARAM;
        ICSLOG_ERR_STR(rc, "Command length is overflow.");
        return rc;
    }
    utl_memcpy(buf + command_len, block_data, 16 * num_of_blocks);
    command_len += (16 * num_of_blocks);

    /* send the command and receive a response */
    rc = devf->thru_func(devf->dev, buf, command_len,
                         sizeof(buf), buf, &response_len,
                         timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "thru_func()");
        return rc;
    }

    /* check the response */
    if ((response_len < (1 + 8 + 2)) ||
        (buf[0] != FELICA_CC_RES_WRITE_WITHOUT_ENCRYPTION) ||
        (utl_memcmp(buf + 1, card->idm, 8) != 0)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Received an invalid response.");
        return rc;
    }

    /* decode the response */
    *status_flag1 = buf[9];
    *status_flag2 = buf[10];
    ICSLOG_DBG_HEX8(*status_flag1);
    ICSLOG_DBG_HEX8(*status_flag2);

    if (*status_flag1 != 0) {
        rc = ICS_ERROR_STATUS_FLAG1;
        ICSLOG_ERR_STR(rc, "Status flag1 is not 0.");
        return rc;
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This function sends a Request System Code to the card.
 *
 * \param  devf                   [IN] My device.
 * \param  card                   [IN] The card to communicate.
 * \param  max_system_codes       [IN] The maximum number of system codes
 *                                     to retrieve.
 * \param  num_of_system_codes   [OUT] The number of retrieved system codes.
 * \param  system_code_list      [OUT] The list of the retrieved system codes.
 * \param  timeout                [IN] Time-out period.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid argument.
 * \retval ICS_ERROR_TIMEOUT           No response.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_DEVICE            Error at device.
 * \retval ICS_ERROR_FRAME_CRC         CRC error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Received an invalid response packet.
 * \retval ICS_ERROR_BUF_OVERFLOW      The number of system codes exceeded
 *                                     the limit.
 */
UINT32 felica_cc_request_system_code(
    const felica_cc_devf_t* devf,
    const felica_card_t* card,
    UINT8 max_system_codes,
    UINT8* num_of_system_codes,
    UINT8* system_code_list,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "felica_cc_request_system_code"
    UINT32 rc;
    UINT8 buf[FELICA_CC_MAX_COMMAND_LEN];
    UINT32 command_len;
    UINT32 response_len;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(devf, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(devf->thru_func, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(card, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(num_of_system_codes, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_NE(system_code_list, NULL, ICS_ERROR_INVALID_PARAM);
    ICSLIB_CHKARG_LE(max_system_codes,
                     FELICA_CC_REQUEST_SYSTEM_CODE_MAX_NUM_OF_SYSTEM_CODES_MAX,
                     ICS_ERROR_INVALID_PARAM);

    ICSLOG_DBG_PTR(devf);
    ICSLOG_DBG_PTR(card);
    ICSLOG_DBG_UINT(max_system_codes);
    ICSLOG_DBG_UINT(timeout);

    /* make a command packet */
    buf[0] = FELICA_CC_CMD_REQUEST_SYSTEM_CODE;
    utl_memcpy(buf + 1, card->idm, 8);
    command_len = (1 + 8);

    /* send the command to the device and receive a response */
    rc = devf->thru_func(devf->dev, buf, command_len,
                         sizeof(buf), buf, &response_len,
                         timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "thru_func()");
        return rc;
    }

    /* check the response */
    if ((response_len < (1 + 8 + 1)) ||
        (buf[0] != FELICA_CC_RES_REQUEST_SYSTEM_CODE) ||
        (utl_memcmp(buf + 1, card->idm, 8) != 0)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Response packet is invalid.");
        return rc;
    }

    /* decode the response */
    *num_of_system_codes = buf[9];
    if (response_len < (UINT32)(1 + 8 + 1 + (2 * *num_of_system_codes))) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Response packet is invalid.");
        return rc;
    }
    if (*num_of_system_codes > max_system_codes) {
        utl_memcpy(system_code_list, buf + 10, 2 * max_system_codes);
        rc = ICS_ERROR_BUF_OVERFLOW;
        ICSLOG_ERR_STR(rc, "The number of system codes is too large.");
        return rc;
    }
    utl_memcpy(system_code_list, buf + 10, 2 * *num_of_system_codes);

    ICSLOG_DBG_UINT(*num_of_system_codes);
    ICSLOG_DUMP(system_code_list, 2 * *num_of_system_codes);

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/* ------------------------
 * Internal
 * ------------------------ */

/**
 * This function detects a remote card using Polling command via thru_func.
 *
 * \param  devf                   [IN] My device.
 * \param  polling_param          [IN] Polling command except for command code.
 * \param  card                  [OUT] Detected card.
 * \param  card_option           [OUT] Option of the detected card.
 * \param  timeout                [IN] Time-out period.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_INVALID_PARAM     Invalid argument.
 * \retval ICS_ERROR_TIMEOUT           Not detected.
 * \retval ICS_ERROR_IO                Other driver error.
 * \retval ICS_ERROR_DEVICE            Error at device.
 * \retval ICS_ERROR_FRAME_CRC         CRC error.
 * \retval ICS_ERROR_INVALID_RESPONSE  Received an invalid response packet.
 */
static UINT32 felica_cc_thru_polling(
    const felica_cc_devf_t* devf,
    const UINT8 polling_param[4],
    felica_card_t* card,
    felica_card_option_t* card_option,
    UINT32 timeout)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "felica_cc_thru_polling"
    UINT32 rc;
    UINT8 command[5];
    UINT8 response[19];
    UINT32 response_len;
    ICSLOG_FUNC_BEGIN;

    /* check the parameters */
    ICSLIB_CHKARG_NE(devf->thru_func, NULL, ICS_ERROR_INVALID_PARAM);

    /* make a command packet */
    command[0] = FELICA_CC_CMD_POLLING;
    utl_memcpy(command + 1, polling_param, 4);

    /* send the command and receive a response */
    rc = devf->thru_func(devf->dev, command, sizeof(command),
                         sizeof(response), response, &response_len,
                         timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "thru_func()");
        if (rc == ICS_ERROR_BUF_OVERFLOW) {
            rc = ICS_ERROR_INVALID_RESPONSE;
        }
        return rc;
    }
    if ((response_len < 17) || (response_len > 19) ||
        (response[0] != FELICA_CC_RES_POLLING)) {
        rc = ICS_ERROR_INVALID_RESPONSE;
        ICSLOG_ERR_STR(rc, "Invalid response.");
        return rc;
    }

    utl_memcpy(card->idm, response + 1, 8);
    utl_memcpy(card->pmm, response + 9, 8);
    if (card_option != NULL) {
        card_option->option_len = (UINT8)(response_len - 17);
        if (card_option->option_len > FELICA_CC_MAX_CARD_OPTION_LEN) {
            card_option->option_len = FELICA_CC_MAX_CARD_OPTION_LEN;
        }
        utl_memcpy(card_option->option, response + 17,
                   card_option->option_len);
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}
