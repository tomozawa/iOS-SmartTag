/**
 * \brief    a header file for ICS_HW_DEVICE
 * \date     2008/10/14
 * \author   Copyright 2005,2006,2007,2008 Sony Corporation
 */

#include "ics_types.h"

#ifndef ICS_HWDEV_H_
#define ICS_HWDEV_H_

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ICS_HW_DEVICE {
    ICS_HANDLE handle;
    UINT32 status;
    UINT32 priv_value;
    void* priv_data;
} ICS_HW_DEVICE;

#ifdef __cplusplus
}
#endif

#endif /* !ICS_HWDEV_H_ */
