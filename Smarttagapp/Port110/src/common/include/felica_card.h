/**
 * \brief    Defining FeliCa Card type
 * \date     2008/10/14
 * \author   Copyright 2005,2006,2008 Sony Corporation
 */

#include "ics_types.h"

#ifndef FELICA_CARD_H_
#define FELICA_CARD_H_

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Type and structure
 */

typedef struct felica_card_t {
    UINT8 idm[8];
    UINT8 pmm[8];
} felica_card_t;

#ifdef __cplusplus
}
#endif

#endif /* !FELICA_CARD_H_ */
