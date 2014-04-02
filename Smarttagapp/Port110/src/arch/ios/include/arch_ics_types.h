/**
 * \brief    Definition of types used in ICS Library (iOS)
 * \date     2013/10/3
 * \author   Copyright 2005,2006,2007,2008,2013 Sony Corporation
 */

#include <objc/objc.h>

#ifndef ARCH_ICS_TYPES_H_
#define ARCH_ICS_TYPES_H_

#ifdef __cplusplus
extern "C" {
#endif

/*
 * [Porting Note]
 *   Modify these definitions according to your system.
 */

/* file handle */

typedef void* ICS_HANDLE;
#define ICS_INVALID_HANDLE ((void*)-1)

/* integer types */

typedef int            INT;
typedef unsigned int   UINT;

/* boolean */

/* BOOL is defined in objc.h */
#ifdef TRUE
#undef TRUE
#endif
#define TRUE   YES
#ifdef FALSE
#undef FALSE
#endif
#define FALSE  NO

/* bit-width-specific integer types */

typedef signed char    INT8;
typedef unsigned char  UINT8;
typedef signed short   INT16;
typedef unsigned short UINT16;
typedef signed int     INT32;
typedef unsigned int   UINT32;

#ifdef __cplusplus
}
#endif

#endif /* !ARCH_ICS_TYPES_H_ */
