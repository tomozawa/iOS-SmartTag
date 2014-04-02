/**
 * \brief    Pseudo-random numbers generator (iOS)
 * \date     2013/03/20
 * \author   Copyright 2005,2006,2007,2008,2013 Sony Corporation
 */

#include "utl.h"

static UINT32 s_prev = 6758;

/**
 * This function sets seed of a new sequence of pseudo-random numbers.
 *
 * \param seed [IN] seed
 */
void utl_srand(UINT32 seed)
{
    s_prev = seed;
}

/**
 * This function generates a 32bit pseudo-random number.
 *
 * \return a pseudo-random number
 */
UINT32 utl_rand(void)
{
    s_prev = ((s_prev * 1183164753) + 7203);

    return s_prev;
}
