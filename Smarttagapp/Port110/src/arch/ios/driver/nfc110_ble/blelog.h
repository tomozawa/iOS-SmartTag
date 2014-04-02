/**
 * \brief    the header file for BLE log facilities
 * \date     2013/4/25
 * \author   Copyright 2013 Sony Corporation
 */

#include "icslog.h"

#ifndef BLELOG_H_
#define BLELOG_H_

#ifdef ICSLOG_LEVEL

#define BLELOG_ERR_PRINT(rc, fmt, args...) \
    do { \
        const char* _errormsg = [ \
            [NSString stringWithFormat:fmt, ##args] UTF8String]; \
        ICSLOG_ERR_STR(rc, _errormsg); \
    } while(0)

#define BLELOG_DBG_PRINT(fmt, args...) \
    do { \
        ICSLOG_DBG_PRINT(\
            ("%s\n", \
             [[NSString stringWithFormat:fmt, ##args] UTF8String])); \
    } while(0)

#else

#define BLELOG_ERR_PRINT(rc, v, ...)
#define BLELOG_DBG_PRINT(v, ...)

#endif

#endif /* !BLELOG_H_ */
