/**
 * \brief    The header file for stub of the FeliCa Card Command Library
 * \date     2008/10/14
 * \author   Copyright 2005,2006,2007,2008 Sony Corporation
 */

#include "ics_types.h"
#include "felica_card.h"

#ifndef FELICA_CC_STUB_H_
#define FELICA_CC_STUB_H_

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Constant
 */

#define FELICA_CC_MAX_COMMAND_LEN               254
#define FELICA_CC_MAX_RESPONSE_LEN              254

#define FELICA_CC_MAX_CARD_OPTION_LEN           2

/*
 * Type and structure
 */

struct felica_card_option_t;

typedef UINT32 (*felica_cc_polling_func_t)(
    void* dev,
    const UINT8 polling_param[4],
    UINT32 max_num_of_cards,
    UINT32* num_of_cards,
    felica_card_t* cards,
    struct felica_card_option_t* card_options,
    UINT32 timeout);
typedef UINT32 (*felica_cc_thru_func_t)(
    void* dev,
    const UINT8* command,
    UINT32 command_len,
    UINT32 max_response_len,
    UINT8* response,
    UINT32* response_len,
    UINT32 timeout);

typedef struct felica_cc_devf_t {
    void* dev;
    felica_cc_polling_func_t polling_func;
    felica_cc_thru_func_t thru_func;
} felica_cc_devf_t;

typedef struct felica_card_option_t {
    UINT32 option_len;
    UINT8 option[FELICA_CC_MAX_CARD_OPTION_LEN];
} felica_card_option_t;

#ifdef __cplusplus
}
#endif

#endif /* !FELICA_CC_STUB_H_ */
