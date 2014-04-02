/**
 * \brief    Sleep routines (iOS)
 * \date     2013/03/20
 * \author   Copyright 2005,2006,2007,2008,2012,2013 Sony Corporation
 */

#undef ICSLOG_MODULE
#define ICSLOG_MODULE "usl"

#include "icslog.h"
#include "ics_error.h"
#include "utl.h"

#include <unistd.h>
#include <sys/types.h>
#include <sys/select.h>
#include <errno.h>

/**
 * This function sleeps for the specified time.
 *
 * \param  msec                   [IN] Sleep time. (millisecond)
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_IO                Any device error.
 */
UINT32 utl_msleep(UINT32 msec)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "utl_msleep"
    int res;
    struct timeval tm;
    UINT32 time0;
    UINT32 current_time;
    UINT32 rest_time_msec;
    ICSLOG_FUNC_BEGIN;

    ICSLOG_DBG_UINT(msec);

    time0 = utl_get_time_msec();
    rest_time_msec = msec;
    do {
        tm.tv_sec = (rest_time_msec / 1000);
        tm.tv_usec = ((rest_time_msec % 1000) * 1000);
        res = select(0, NULL, NULL, NULL, &tm);
        if ((res == -1) && (errno != EINTR)) {
            ICSLOG_ERR_STR(errno, "select()");
            return ICS_ERROR_IO;
        } else if (errno == EINTR) {
            ICSLOG_ERR_STR(errno, "retry select() again");
            rest_time_msec =
                utl_get_rest_timeout(time0, msec, &current_time);
            ICSLOG_DBG_UINT(rest_time_msec);
        } else {
            rest_time_msec = 0;
        }
    } while (rest_time_msec > 0);

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}
