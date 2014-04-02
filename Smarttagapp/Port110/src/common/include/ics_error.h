/**
 * \brief    a header file for the ICS Library (defines error codes)
 * \date     2008/10/14
 * \author   Copyright 2005,2006,2007,2008 Sony Corporation
 */

#ifndef ICS_ERROR_H_
#define ICS_ERROR_H_

#ifdef __cplusplus
extern "C" {
#endif

#define ICS_ERROR_SUCCESS           0U
#define ICS_ERROR_NOT_SUPPORTED     1U
#define ICS_ERROR_NOT_IMPLEMENTED   2U
#define ICS_ERROR_NOT_INITIALIZED   3U
#define ICS_ERROR_NOT_OPENED        4U
#define ICS_ERROR_ALREADY_OPENED    5U
#define ICS_ERROR_INVALID_PARAM     6U
#define ICS_ERROR_ILLEGAL_MODE      7U
#define ICS_ERROR_FATAL             8U
#define ICS_ERROR_IO                9U
#define ICS_ERROR_NO_RESOURCES      10U
#define ICS_ERROR_BUSY              11U
#define ICS_ERROR_PERMISSION        12U
#define ICS_ERROR_TIMEOUT           13U
#define ICS_ERROR_FRAME_CRC         14U
#define ICS_ERROR_INVALID_RESPONSE  15U
#define ICS_ERROR_INVALID_FRAME     15U /* obsolete */
#define ICS_ERROR_SYNTAX            16U
#define ICS_ERROR_BUF_OVERFLOW      17U
#define ICS_ERROR_DATA_TRANS_START  18U
#define ICS_ERROR_DATA_TRANS_END    19U
#define ICS_ERROR_NOT_STARTED       20U
#define ICS_ERROR_ALREADY_STARTED   21U
#define ICS_ERROR_SEQUENCE          22U
#define ICS_ERROR_DESELECTED        23U
#define ICS_ERROR_RELEASED          24U
#define ICS_ERROR_RF_OFF            25U

#define ICS_ERROR_NOT_EXIST         26U
#define ICS_ERROR_ALREADY_EXIST     27U
#define ICS_ERROR_IGNORE            28U
#define ICS_ERROR_STATUS_FLAG1      29U
#define ICS_ERROR_STATUS_FLAG       30U
#define ICS_ERROR_SN_OVERFLOW       31U
#define ICS_ERROR_INVALID_DATA      32U

#define ICS_ERROR_DISCONNECTED      33U
#define ICS_ERROR_SHUTDOWN          34U
#define ICS_ERROR_MANY_ERRORS       35U
#define ICS_ERROR_NOT_CONNECTED     36U

#define ICS_ERROR_DEV_BUSY          37U
#define ICS_ERROR_DEVICE            38U
#define ICS_ERROR_INTTEMP_RF_OFF    39U

#ifdef __cplusplus
}
#endif

#endif /* !ICS_ERROR_H_ */
