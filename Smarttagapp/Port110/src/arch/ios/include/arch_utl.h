/**
 * \brief    utilities (iOS)
 * \date     2013/05/14
 * \author   Copyright 2005,2006,2008,2013 Sony Corporation
 */


#ifndef ARCH_UTL_H_
#define ARCH_UTL_H_

#ifdef __cplusplus
extern "C" {
#endif

#ifndef CONFIG_HAVE_ANSI_C_LIBRARY

/*
 * [Porting Note]
 *   Implement UTL_ASSERT(expr) which stops execution when expr is false.
 */
#include <assert.h>
#define UTL_ASSERT assert

#endif /* CONFIG_HAVE_ANSI_C_LIBRARY */

#ifdef __cplusplus
}
#endif

#endif /* !ARCH_UTL_H_ */
