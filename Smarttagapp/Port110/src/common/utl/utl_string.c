/**
 * \brief    Substitutes for some ANSI C string functions
 * \date     2008/10/14
 * \author   Copyright 2005,2008 Sony Corporation
 */

#include "utl.h"

#ifndef CONFIG_HAVE_ANSI_C_LIBRARY

/**
 * comute the length of the string s
 * \param s      [IN]  string
 * \return the length of s
 */
unsigned int utl_strlen(const char* s)
{
    unsigned int len;

    len = 0;
    while (*s != 0) {
        len++;
        s++;
    }

    return len;
}

/**
 * lexicographically compare the strings s1 and s2
 * \param s1     [IN]  string to compare
 * \param s2     [IN]  string to compare
 * \return 1, 0, or -1 according as s1 > s2, s1 = s2, or s1 < s2
 */
int utl_strcmp(
    const char* s1,
    const char* s2)
{
    int ret;
    int loop_end;
    const unsigned char* us1;
    const unsigned char* us2;

    ret = 0;
    loop_end = 0;
    us1 = (const unsigned char*)s1;
    us2 = (const unsigned char*)s2;

    while (!loop_end) {
        if (*us1 > *us2) {
            ret = 1;
            loop_end = 1;
        } else if (*us1 < *us2) {
            ret = -1;
            loop_end = 1;
        } else if (*us1 == 0) {
            ret = 0;
            loop_end = 1;
        }
        us1++;
        us2++;
    }

    return ret;
}

/**
 * lexicographically compare at most first len characters of
 * the strings s1 and s2
 * \param s1     [IN]  string to compare
 * \param s2     [IN]  string to compare
 * \param len    [IN]  length to compare
 * \return 1, 0, or -1 according as s1 > s2, s1 = s2, or s1 < s2
 */
int utl_strncmp(
    const char* s1,
    const char* s2,
    unsigned int len)
{
    int ret;
    const unsigned char* us1;
    const unsigned char* us2;

    ret = 0;
    us1 = (const unsigned char*)s1;
    us2 = (const unsigned char*)s2;

    while (len > 0) {
        if (*us1 > *us2) {
            ret = 1;
            break;
        } else if (*us1 < *us2) {
            ret = -1;
            break;
        } else if (*us1 == 0) {
            ret = 0;
            break;
        }
        us1++;
        us2++;
        len--;
    }

    return ret;
}

/**
 * write len bytes of c to the buffer b
 * \param b      [OUT] buffer to be written
 * \param c      [IN]  character to write
 * \param len    [IN]  length
 * \return b
 */
void* utl_memset(
    void* b,
    int c,
    unsigned int len)
{
    char* p;

    p = (char*)b;

    while (len > 0) {
        *p = (char)c;
        p++;
        len--;
    }

    return b;
}

/**
 * copy len bytes from src to the buffer dst
 * \param dst    [OUT] destination buffer
 * \param src    [IN]  source data
 * \param len    [IN]  data length
 * \return dst
 */
void* utl_memcpy(
    void* dst,
    const void* src,
    unsigned int len)
{
    char* dp;
    const char* sp;

    dp = dst;
    sp = src;

    while (len > 0) {
        *dp = *sp;
        dp++;
        sp++;
        len--;
    }

    return dst;
}

/**
 * compare the first len bytes of the data b1 and b2
 * \param b1     [IN]  data to compare
 * \param b2     [IN]  data to compare
 * \param len    [IN]  data length
 * \return 1, 0, or -1 according as s1 > s2, s1 = s2, or s1 < s2
 */
int utl_memcmp(
    const void* b1,
    const void* b2,
    unsigned int len)
{
    int ret;
    const unsigned char* pb1;
    const unsigned char* pb2;

    ret = 0;
    pb1 = b1;
    pb2 = b2;

    while (len > 0) {
        if (*pb1 > *pb2) {
            ret = 1;
        } else if (*pb1 < *pb2) {
            ret = -1;
        }
        pb1++;
        pb2++;
        len--;
    }

    return ret;
}

#endif /* !CONFIG_HAVE_ANSI_C_LIBRARY */
