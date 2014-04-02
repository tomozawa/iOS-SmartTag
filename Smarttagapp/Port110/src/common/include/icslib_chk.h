/**
 * \brief    a header file for the ICS Library (check facilities)
 * \date     2008/10/14
 * \author   Copyright 2005,2007,2008 Sony Corporation
 */

#include "ics_types.h"
#include "icslog.h"

#ifndef ICSLIB_CHK_H_
#define ICSLIB_CHK_H_

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Macros
 */

#define ICSLIB_CHKARG_EQ(arg, invalid, error) \
    do { \
        if ((arg) != (invalid)) { \
            ICSLOG(ICSLOG_ERR, \
                   ("E:%s:%s:%d:%s: Error (%lu): " # arg "\n", \
                    ICSLOG_MODULE, __FILE__, __LINE__, ICSLOG_FUNC, \
                    (unsigned long)error)); \
            return (error); \
        } \
    } while (0)

#define ICSLIB_CHKARG_NE(arg, invalid, error) \
    do { \
        if ((arg) == (invalid)) { \
            ICSLOG(ICSLOG_ERR, \
                   ("E:%s:%s:%d:%s: Error (%lu): " # arg "\n", \
                    ICSLOG_MODULE, __FILE__, __LINE__, ICSLOG_FUNC, \
                    (unsigned long)error)); \
            return (error); \
        } \
    } while (0)

#define ICSLIB_CHKARG_BE(arg, min, error) \
    do { \
        if (!((arg) >= (min))) { \
            ICSLOG(ICSLOG_ERR, \
                   ("E:%s:%s:%d:%s: Range Error (%lu) " \
                    "(%s=%lu must be >= %lu)\n", \
                    ICSLOG_MODULE, __FILE__, __LINE__, ICSLOG_FUNC, \
                    (unsigned long)error, \
                    # arg, (unsigned long)(arg), (unsigned long)(min))); \
            return (error); \
        } \
    } while (0)

#define ICSLIB_CHKARG_LE(arg, max, error) \
    do { \
        if (!((arg) <= (max))) { \
            ICSLOG(ICSLOG_ERR, \
                   ("E:%s:%s:%d:%s: Range Error (%lu) " \
                    "(%s=%lu must be <= %lu)\n", \
                    ICSLOG_MODULE, __FILE__, __LINE__, ICSLOG_FUNC, \
                    (unsigned long)error, \
                    # arg, (unsigned long)(arg), (unsigned long)(max))); \
            return (error); \
        } \
    } while (0)

#define ICSLIB_CHKARG_IN_RANGE(arg, min, max, error) \
    do { \
        if (!(((arg) >= (min)) && ((arg) <= (max)))) { \
            ICSLOG(ICSLOG_ERR, \
                   ("E:%s:%s:%d:%s: Range Error (%lu) " \
                    "(%s=%lu must be in %lu to %lu)\n", \
                    ICSLOG_MODULE, __FILE__, __LINE__, ICSLOG_FUNC, \
                    (unsigned long)error, \
                    # arg, (unsigned long)(arg), \
                    (unsigned long)(min), (unsigned long)(max))); \
            return (error); \
        } \
    } while (0)

#ifdef __cplusplus
}
#endif

#endif /* !ICSLIB_CHK_H_ */
