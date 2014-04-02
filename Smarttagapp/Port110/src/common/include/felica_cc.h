/**
 * \brief    The header file for the FeliCa Card Command Library
 * \date     2008/10/14
 * \author   Copyright 2005,2006,2007,2008 Sony Corporation
 */

#include "ics_types.h"
#include "felica_card.h"
#include "felica_cc_stub.h"

#ifndef FELICA_CC_H_
#define FELICA_CC_H_

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Constant
 */

#define FELICA_CC_REQUEST_SERVICE_NUM_OF_NODES_MIN         1
#define FELICA_CC_REQUEST_SERVICE_NUM_OF_NODES_MAX        32
#define FELICA_CC_READ_WE_NUM_OF_SERVICES_MIN              1
#define FELICA_CC_READ_WE_NUM_OF_SERVICES_MAX             16
#define FELICA_CC_READ_WE_NUM_OF_BLOCKS_MIN                1
#define FELICA_CC_READ_WE_NUM_OF_BLOCKS_MAX               15
#define FELICA_CC_WRITE_WE_NUM_OF_SERVICES_MIN             1
#define FELICA_CC_WRITE_WE_NUM_OF_SERVICES_MAX            16
#define FELICA_CC_WRITE_WE_NUM_OF_BLOCKS_MIN               1
#define FELICA_CC_WRITE_WE_NUM_OF_BLOCKS_MAX              13
#define FELICA_CC_REQUEST_SYSTEM_CODE_MAX_NUM_OF_SYSTEM_CODES_MAX 32

#define FELICA_CC_PMM_REQUEST_SERVICE                   2
#define FELICA_CC_PMM_REQUEST_RESPONSE                  3
#define FELICA_CC_PMM_READ_WITHOUT_ENCRYPTION           5
#define FELICA_CC_PMM_WRITE_WITHOUT_ENCRYPTION          6
#define FELICA_CC_PMM_REQUEST_SYSTEM_CODE               3

/*
 * Prototype declaration
 */

UINT32 felica_cc_polling(
    const felica_cc_devf_t* devf,
    const UINT8 polling_param[4],
    felica_card_t* card,
    felica_card_option_t* card_option,
    UINT32 timeout);
UINT32 felica_cc_polling_multiple(
    const felica_cc_devf_t* devf,
    const UINT8 polling_param[4],
    UINT32 max_num_of_cards,
    UINT32* num_of_cards,
    felica_card_t* cards,
    felica_card_option_t* card_options,
    UINT32 timeout);

UINT32 felica_cc_request_service(
    const felica_cc_devf_t* devf,
    const felica_card_t* card,
    UINT8 num_of_nodes,
    const UINT16* node_code_list,
    UINT16* node_key_version_list,
    UINT32 timeout);
UINT32 felica_cc_request_response(
    const felica_cc_devf_t* devf,
    const felica_card_t* card,
    UINT8* mode,
    UINT32 timeout);
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
    UINT32 timeout);
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
    UINT32 timeout);
UINT32 felica_cc_request_system_code(
    const felica_cc_devf_t* devf,
    const felica_card_t* card,
    UINT8 max_system_codes,
    UINT8* num_of_system_codes,
    UINT8* system_code_list,
    UINT32 timeout);

/*
 * Macros to calculate timeouts from PMm
 */
#define FELICA_CC_PMM_E(x) (((x) >> 6) & 0x3)
#define FELICA_CC_PMM_B(x) (((x) >> 3) & 0x7)
#define FELICA_CC_PMM_A(x) (((x) >> 0) & 0x7)
#define FELICA_CC_CALC_TIMEOUT_0_1MS(x, nblocks) \
    (((302 * (((FELICA_CC_PMM_B(x) + 1) * (nblocks)) + \
              (FELICA_CC_PMM_A(x) + 1))) << (2 * FELICA_CC_PMM_E(x))) / 100)
#define FELICA_CC_CALC_TIMEOUT(x, nblocks) \
    ((FELICA_CC_CALC_TIMEOUT_0_1MS(x, nblocks) + 9) / 10)

#ifdef __cplusplus
}
#endif

#endif /* !FELICA_CC_H_ */
