/**
 * \brief    Substitutes for snprintf and vsnprintf
 * \date     2008/10/14
 * \author   Copyright 2005,2008 Sony Corporation
 */

#include "utl.h"

#include <stdarg.h>

#ifndef CONFIG_HAVE_ANSI_C_LIBRARY

typedef enum {
    LEN_none,
    LEN_hh,
    LEN_h,
    LEN_l,
    LEN_ll,
    LEN_j,
    LEN_z,
    LEN_t,
    LEN_L
} length_modifier_t;

static unsigned int utl_snprintf_strlen(const char* s)
{
    unsigned int len;

    len = 0;
    while (*s != 0) {
        len++;
        s++;
    }

    return len;
}

static void* utl_snprintf_memset(
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

static void* utl_snprintf_memcpy(
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

static int utl_snprintf_signed(
    char* s,
    unsigned int max_write,
    long d,
    int base,
    int left_adjust,
    int need_sign,
    int need_blank,
    int zero_padding,
    unsigned int field_width,
    int enable_precision,
    unsigned int precision)
{
    unsigned int nwrite;
    unsigned int ndigits;
    unsigned int width;
    unsigned int pad_width;
    long tmp_d;
    unsigned int n;
    unsigned int i;
    unsigned int offset;
    char mark;
    int no_more_digit;

    nwrite = 0;

    if ((base < 2) || (base > 16)) {
        base = 10;
    }

    /* calculate width */
    width = 0;
    ndigits = 1;
    if (d < 0) {
        tmp_d = -d;
    } else {
        tmp_d = d;
    }
    while (tmp_d >= base) {
        ndigits++;
        tmp_d /= base;
    }
    if (enable_precision && (ndigits < precision)) {
        ndigits = precision;
    }
    width += ndigits;

    /* calculate sign or blank mark */
    mark = 0;
    if (d < 0) {
        mark = '-';
    } else if (need_sign) {
        mark = '+';
    } else if (need_blank) {
        mark = ' ';
    }
    if (mark != 0) {
        width++;
    }

    /* left padding */
    if (!left_adjust && (width < field_width)) {
        pad_width = (field_width - width);
        if (zero_padding) {
            if (mark != 0) {
                if (nwrite < max_write) {
                    *s = mark;
                }
                s++;
                nwrite++;
                mark = 0;
            }
        }
        if (nwrite < max_write) {
            n = (max_write - nwrite);
            if (pad_width < n) {
                n = pad_width;
            }
            if (zero_padding) {
                utl_snprintf_memset(s, '0', n);
            } else {
                utl_snprintf_memset(s, ' ', n);
            }
        }
        s += pad_width;
        nwrite += pad_width;
    }

    /* sign or blank mark if necessary */
    if (mark != 0) {
        if (nwrite < max_write) {
            *s = mark;
        }
        s++;
        nwrite++;
    }

    /* digits */
    if (d < 0) {
        tmp_d = -d;
    } else {
        tmp_d = d;
    }
    no_more_digit = 0;
    for (i = 0; i < ndigits; i++) {
        offset = (ndigits - i - 1);
        if ((nwrite + offset) < max_write) {
            if (!no_more_digit) {
                if ((tmp_d % base) >= 10) {
                    *(s + offset) = (char)('a' + (int)((tmp_d % base) - 10));
                } else {
                    *(s + offset) = (char)('0' + (int)(tmp_d % base));
                }
            } else {
                *(s + offset) = ' ';
            }
        }
        tmp_d /= base;
        if ((tmp_d == 0) && !enable_precision) {
            no_more_digit = 1;
        }
    }
    s += ndigits;
    nwrite += ndigits;

    /* right padding */
    if (left_adjust && (width < field_width)) {
        pad_width = (field_width - width);
        if (nwrite < max_write) {
            n = (max_write - nwrite);
            if (pad_width < n) {
                n = pad_width;
            }
            utl_snprintf_memset(s, ' ', n);
        }
        s += pad_width;
        nwrite += pad_width;
    }

    return nwrite;
}

static int utl_snprintf_unsigned(
    char* s,
    unsigned int max_write,
    unsigned long d,
    int base,
    int left_adjust,
    int zero_padding,
    unsigned int field_width,
    int enable_precision,
    unsigned int precision,
    int upper_case)
{
    unsigned int nwrite;
    unsigned int ndigits;
    unsigned int width;
    unsigned int pad_width;
    unsigned long tmp_d;
    unsigned int n;
    unsigned int i;
    unsigned int offset;
    int no_more_digit;

    nwrite = 0;

    if ((base < 2) || (base > 16)) {
        base = 10;
    }

    /* calculate width */
    width = 0;
    ndigits = 1;
    tmp_d = d;
    while (tmp_d >= (unsigned int)base) {
        ndigits++;
        tmp_d /= base;
    }
    if (enable_precision && (ndigits < precision)) {
        ndigits = precision;
    }
    width += ndigits;

    /* left padding */
    if (!left_adjust && (width < field_width)) {
        pad_width = (field_width - width);
        if (nwrite < max_write) {
            n = (max_write - nwrite);
            if (pad_width < n) {
                n = pad_width;
            }
            if (zero_padding) {
                utl_snprintf_memset(s, '0', n);
            } else {
                utl_snprintf_memset(s, ' ', n);
            }
        }
        s += pad_width;
        nwrite += pad_width;
    }

    /* digits */
    tmp_d = d;
    no_more_digit = 0;
    for (i = 0; i < ndigits; i++) {
        offset = (ndigits - i - 1);
        if ((nwrite + offset) < max_write) {
            if (!no_more_digit) {
                if ((tmp_d % base) >= 10) {
                    if (upper_case) {
                        *(s + offset) = (char)('A' +
                                               (int)((tmp_d % base) - 10));
                    } else {
                        *(s + offset) = (char)('a' +
                                               (int)((tmp_d % base) - 10));
                    }
                } else {
                    *(s + offset) = (char)('0' + (int)(tmp_d % base));
                }
            } else {
                *(s + offset) = ' ';
            }
        }
        tmp_d /= base;
        if ((tmp_d == 0) && !enable_precision) {
            no_more_digit = 1;
        }
    }
    s += ndigits;
    nwrite += ndigits;

    /* right padding */
    if (left_adjust && (width < field_width)) {
        pad_width = (field_width - width);
        if (nwrite < max_write) {
            n = (max_write - nwrite);
            if (pad_width < n) {
                n = pad_width;
            }
            utl_snprintf_memset(s, ' ', n);
        }
        s += pad_width;
        nwrite += pad_width;
    }

    return nwrite;
}

static int utl_snprintf_c(
    char* s,
    unsigned int max_write,
    int c,
    int left_adjust,
    unsigned int field_width)
{
    unsigned int nwrite;
    unsigned int pad_width;
    unsigned int n;

    nwrite = 0;

    /* left padding */
    if (!left_adjust && (field_width > 1)) {
        pad_width = (field_width - 1);
        if (nwrite < max_write) {
            n = (max_write - nwrite);
            if (pad_width < n) {
                n = pad_width;
            }
            utl_snprintf_memset(s, ' ', n);
        }
        s += pad_width;
        nwrite += pad_width;
    }

    /* char */
    if (nwrite < max_write) {
        *s = (unsigned char)c;
    }
    s++;
    nwrite++;

    /* right padding */
    if (left_adjust && (field_width > 1)) {
        pad_width = (field_width - 1);
        if (nwrite < max_write) {
            n = (max_write - nwrite);
            if (pad_width < n) {
                n = pad_width;
            }
            utl_snprintf_memset(s, ' ', n);
        }
        s += pad_width;
        nwrite += pad_width;
    }

    return nwrite;
}

static int utl_snprintf_s(
    char* s,
    unsigned int max_write,
    char* str,
    int left_adjust,
    unsigned int field_width,
    int enable_precision,
    unsigned int precision)
{
    unsigned int nwrite;
    unsigned int len;
    unsigned int pad_width;
    unsigned int n;

    nwrite = 0;

    len = utl_snprintf_strlen(str);
    if (enable_precision && (len > precision)) {
        len = precision;
    }

    /* left_padding */
    if (!left_adjust && (field_width > len)) {
        pad_width = (field_width - len);
        if (nwrite < max_write) {
            n = (max_write - nwrite);
            if (pad_width < n) {
                n = pad_width;
            }
            utl_snprintf_memset(s, ' ', n);
        }
        s += pad_width;
        nwrite += pad_width;
    }

    /* string */
    if (nwrite < max_write) {
        n = (max_write - nwrite);
        if (len < n) {
            n = len;
        }
        utl_snprintf_memcpy(s, str, n);
    }
    s += len;
    nwrite += len;

    /* left_padding */
    if (left_adjust && (field_width > len)) {
        pad_width = (field_width - len);
        if (nwrite < max_write) {
            n = (max_write - nwrite);
            if (pad_width < n) {
                n = pad_width;
            }
            utl_snprintf_memset(s, ' ', n);
        }
        s += pad_width;
        nwrite += pad_width;
    }

    return nwrite;
}

/**
 * terminate the output by null character
 * \param s      [OUT] destination buffer
 * \param n      [IN]  buffer size
 * \param nwrite [IN]  number of characters to be written
 */
static void utl_snprintf_null_terminate(
    char* s,
    unsigned int n,
    unsigned int nwrite)
{
    if (n > 0) {
        if (nwrite < n) {
            *(s + nwrite) = 0;
        } else {
            *(s + (n - 1)) = 0;
        }
    }

    return;
}

/**
 * write output to s according to a format
 * \param s      [OUT] destination buffer
 * \param n      [IN]  buffer size
 * \param format [IN]  format
 * \param ...    [IN]  arguments
 * \return the number of characters written to s (not including the
 *         terminating null(0) character)
 */
int utl_snprintf(
    char* s,
    unsigned int n,
    const char* format,
    ...)
{
    int ret;
    va_list arg;

    va_start(arg, format);
    ret = utl_vsnprintf(s, n, format, arg);
    va_end(arg);

    return ret;
}

/**
 * write output to s according to a format
 * \param s      [OUT] destination buffer
 * \param n      [IN]  buffer size
 * \param format [IN]  format
 * \param arg    [IN]  arguments
 * \return the number of characters written to s (not including the
 *         terminating null(0) character)
 */
int utl_vsnprintf(
    char* s,
    unsigned int n,
    const char* format,
    va_list arg)
{
    char* orig_s;
    unsigned int nwrite;
    int left_adjust;
    int need_sign;
    int need_blank;
    int zero_padding;
    unsigned int field_width;
    int enable_precision;
    unsigned int precision;
    length_modifier_t length;
    int tmp_n;
    unsigned int max_write;

    orig_s = s;
    nwrite = 0;

    while (*format != 0) {
        if ((nwrite + 1) < n) {
            max_write = (n - (nwrite + 1));
        } else {
            max_write = 0;
        }

        if (*format == '%') {
            format++;

            /* parse flags */
            left_adjust = 0;
            need_sign = 0;
            need_blank = 0;
            zero_padding = 0;
            while (*format != 0) {
                if (*format == '#') {
                    utl_snprintf_null_terminate(orig_s, n, nwrite);
                    return -1;
                } else if (*format == '-') {
                    left_adjust = 1;
                } else if (*format == '+') {
                    need_sign = 1;
                } else if (*format == ' ') {
                    need_blank = 1;
                } else if (*format == '0') {
                    zero_padding = 1;
                } else {
                    break;
                }
                format++;
            }

            /* parse field width */
            field_width = 0;
            while (*format != 0) {
                if (*format == '*') {
                    utl_snprintf_null_terminate(orig_s, n, nwrite);
                    return -1;
                } else if ((*format >= '0') && (*format <= '9')) {
                    field_width = ((field_width * 10) + (*format - '0'));
                } else {
                    break;
                }
                format++;
            }

            /* parse precision */
            enable_precision = 0;
            precision = 0;
            if (*format == '.') {
                format++;
                enable_precision = 1;
                while (*format != 0) {
                    if (*format == '*') {
                        utl_snprintf_null_terminate(orig_s, n, nwrite);
                        return -1;
                    } else if (*format >= '0' && *format <= '9') {
                        precision = ((precision * 10) + (*format - '0'));
                    } else {
                        break;
                    }
                    format++;
                }
            }

            /* parse length modifier */
            length = LEN_none;
            while (*format != 0) {
                if (*format == 'h') {
                    if (*(format + 1) == 'h') {
                        length = LEN_hh;
                        format++;
                    } else {
                        length = LEN_h;
                    }
                } else if (*format == 'l') {
                    if (*(format + 1) == 'l') {
                        length = LEN_ll;
                        format++;
                    } else {
                        length = LEN_l;
                    }
                } else if (*format == 'j') {
                    length = LEN_j;
                } else if (*format == 'z') {
                    length = LEN_z;
                } else if (*format == 't') {
                    length = LEN_t;
                } else if (*format == 'L') {
                    length = LEN_L;
                } else {
                    break;
                }
                format++;
            }
            if ((length != LEN_none) && (length != LEN_l)) {
                utl_snprintf_null_terminate(orig_s, n, nwrite);
                return -1; /* XXX: TODO */
            }

            /* parse conversion specifier */
            switch (*format) {
            case 'd':
            case 'i':
                if (length == LEN_l) {
                    tmp_n = utl_snprintf_signed(s, max_write,
                                                va_arg(arg, long), 10,
                                                left_adjust, need_sign,
                                                need_blank,
                                                zero_padding, field_width,
                                                enable_precision, precision);
                } else {
                    tmp_n = utl_snprintf_signed(s, max_write,
                                                va_arg(arg, int), 10,
                                                left_adjust, need_sign,
                                                need_blank,
                                                zero_padding, field_width,
                                                enable_precision, precision);
                }
                s += tmp_n;
                nwrite += tmp_n;
                break;
            case 'u':
                if (length == LEN_l) {
                    tmp_n = utl_snprintf_unsigned(s, max_write,
                                                  va_arg(arg, unsigned long),
                                                  10,
                                                  left_adjust,
                                                  zero_padding, field_width,
                                                  enable_precision, precision,
                                                  0);
                } else {
                    tmp_n = utl_snprintf_unsigned(s, max_write,
                                                  va_arg(arg, unsigned int),
                                                  10,
                                                  left_adjust,
                                                  zero_padding, field_width,
                                                  enable_precision, precision,
                                                  0);
                }
                s += tmp_n;
                nwrite += tmp_n;
                break;
            case 'x':
                if (length == LEN_l) {
                    tmp_n = utl_snprintf_unsigned(s, max_write,
                                                  va_arg(arg, unsigned long),
                                                  16,
                                                  left_adjust,
                                                  zero_padding, field_width,
                                                  enable_precision, precision,
                                                  0);
                } else {
                    tmp_n = utl_snprintf_unsigned(s, max_write,
                                                  va_arg(arg, unsigned int),
                                                  16,
                                                  left_adjust,
                                                  zero_padding, field_width,
                                                  enable_precision, precision,
                                                  0);
                }
                s += tmp_n;
                nwrite += tmp_n;
                break;
            case 'X':
                if (length == LEN_l) {
                    tmp_n = utl_snprintf_unsigned(s, max_write,
                                                  va_arg(arg, unsigned long),
                                                  16,
                                                  left_adjust,
                                                  zero_padding, field_width,
                                                  enable_precision, precision,
                                                  1);
                } else {
                    tmp_n = utl_snprintf_unsigned(s, max_write,
                                                  va_arg(arg, unsigned int),
                                                  16,
                                                  left_adjust,
                                                  zero_padding, field_width,
                                                  enable_precision, precision,
                                                  1);
                }
                s += tmp_n;
                nwrite += tmp_n;
                break;
            case 'c':
                if (length == LEN_l) {
                    utl_snprintf_null_terminate(orig_s, n, nwrite);
                    return -1; /* XXX: TODO */
                } else {
                    tmp_n = utl_snprintf_c(s, max_write,
                                           va_arg(arg, int),
                                           left_adjust, field_width);
                }
                s += tmp_n;
                nwrite += tmp_n;
                break;
            case 's':
                if (length == LEN_l) {
                    utl_snprintf_null_terminate(orig_s, n, nwrite);
                    return -1; /* XXX: TODO */
                } else {
                    tmp_n = utl_snprintf_s(s, max_write,
                                           va_arg(arg, char*),
                                           left_adjust, field_width,
                                           enable_precision, precision);
                }
                s += tmp_n;
                nwrite += tmp_n;
                break;
            case 'p':
                tmp_n = utl_snprintf_unsigned(s, max_write,
                                              (unsigned long)
                                              va_arg(arg, void*),
                                              16,
                                              left_adjust,
                                              zero_padding, field_width,
                                              enable_precision, precision, 0);
                s += tmp_n;
                nwrite += tmp_n;
                break;
            case '%':
                if (max_write > 0) {
                    *s = '%';
                }
                s++;
                nwrite++;
                break;
            default:
                utl_snprintf_null_terminate(orig_s, n, nwrite);
                return -1; /* XXX: TODO */
            }
            format++;
        } else {
            if (max_write > 0) {
                *s = *format;
            }
            s++;
            nwrite++;
            format++;
        }
    }

    utl_snprintf_null_terminate(orig_s, n, nwrite);

    return nwrite;
}

#endif /* !CONFIG_HAVE_ANSI_C_LIBRARY */
