/**
 * \brief    The stub functions binding felica_cc to nfc110_ble.
 * \date     2013/05/14
 * \author   Copyright 2011,2013 Sony Corporation
 */

#include "ics_types.h"
#include "felica_cc.h"
#include "ics_hwdev.h"

#ifndef FELICA_CC_STUB_NFC110_H_
#define FELICA_CC_STUB_NFC110_H_

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Constant
 */

#define FELICA_CC_STUB_NFC110_MAX_COMMAND_LEN             254
#define FELICA_CC_STUB_NFC110_MAX_RESPONSE_LEN            254

/*
 * Prototype declaration
 */

UINT32 felica_cc_stub_nfc110_initialize(
    felica_cc_devf_t* devf,
    ICS_HW_DEVICE* nfc110_dev);

#ifdef __cplusplus
}
#endif

#endif /* !FELICA_CC_STUB_NFC110_H_ */
