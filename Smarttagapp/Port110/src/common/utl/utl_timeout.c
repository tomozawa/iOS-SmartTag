/**
 * \brief    Substitutes for timeout
 * \date     2008/10/14
 * \author   Copyright 2005,2006,2007,2008 Sony Corporation
 */

#undef ICSLOG_MODULE
#define ICSLOG_MODULE "uto"

#include "icslog.h"
#include "utl.h"

/**
 * This function returns the rest of time-out.
 *
 * \param  time0                  [IN] The base time for time-out. (ms)
 * \param  timeout                [IN] Time-out. (ms)
 * \param  current_time          [OUT] The current clock time. (ms)
 *
 * \return The rest of time-out.
 */
UINT32 utl_get_rest_timeout(
    UINT32 time0,
    UINT32 timeout,
    UINT32* current_time)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "utl_get_rest_timeout"
    UINT32 period;
    UINT32 rest_timeout;
    ICSLOG_FUNC_BEGIN;

    ICSLOG_DBG_UINT(time0);
    ICSLOG_DBG_UINT(timeout);

    *current_time = utl_get_time_msec();

    period = (*current_time - time0);
    if (period >= timeout) {
        rest_timeout = 0;
    } else {
        rest_timeout = (timeout - period);
    }

    ICSLOG_DBG_UINT(rest_timeout);
    ICSLOG_DBG_UINT(*current_time);

    ICSLOG_FUNC_END;
    return rest_timeout;
}
