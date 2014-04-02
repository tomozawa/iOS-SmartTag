/**
 * \brief    utilities
 * \date     2008/10/14
 * \author   Copyright 2005,2007,2008 Sony Corporation
 */

#include "ics_types.h"

#include "arch_utl.h"

#ifndef UTL_H_
#define UTL_H_

#ifdef __cplusplus
extern "C" {
#endif

void utl_srand(UINT32 seed);
UINT32 utl_rand(void);

UINT32 utl_get_time_msec(void);

UINT32 utl_get_rest_timeout(
    UINT32 time0,
    UINT32 timeout,
    UINT32* current_time);

UINT32 utl_msleep(UINT32 msec);

/* ANSI C library */
#ifdef CONFIG_HAVE_ANSI_C_LIBRARY

#include <stdio.h>
#include <string.h>
#include <assert.h>

#define utl_strlen strlen
#define utl_strcmp strcmp
#define utl_strncmp strncmp
#define utl_memset memset
#define utl_memcpy memcpy
#define utl_memcmp memcmp

#define utl_snprintf snprintf
#define utl_vsnprintf vsnprintf

#define UTL_ASSERT assert

#else /* CONFIG_HAVE_ANSI_C_LIBRARY */

#include <stdarg.h>

unsigned int utl_strlen(const char* s);
int utl_strcmp(
    const char* s1,
    const char* s2);
int utl_strncmp(
    const char* s1,
    const char* s2,
    unsigned int len);
void* utl_memset(
    void* b,
    int c,
    unsigned int len);
void* utl_memcpy(
    void* dst,
    const void* src,
    unsigned int len);
int utl_memcmp(
    const void* b1,
    const void* b2,
    unsigned int len);

int utl_snprintf(
    char* s,
    unsigned int n,
    const char* format,
    ...);
int utl_vsnprintf(
    char* s,
    unsigned int n,
    const char* format,
    va_list arg);

#endif  /* CONFIG_HAVE_ANSI_C_LIBRARY */

#ifdef __cplusplus
}
#endif

#endif /* !UTL_H_ */
