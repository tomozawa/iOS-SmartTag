/**
 * \brief    Time routines (iOS)
 * \date     2013/03/20
 * \author   Copyright 2005,2006,2008,2013 Sony Corporation
 */

#include "utl.h"

#include <sys/time.h>

/**
 * This function returns the current time in millisecond.
 *
 * \return the current time (millisecond)
 */
UINT32 utl_get_time_msec(void)
{
    struct timeval tv;

    gettimeofday(&tv, NULL);

    return (((UINT32)tv.tv_sec * 1000) + (tv.tv_usec / 1000));
}
