/**
 * \brief    a header file for the NFC Port-110 (internal)
 * \date     2013/4/23
 * \author   Copyright 2013 Sony Corporation
 */

#ifndef NFC110_INTERNAL_H_
#define NFC110_INTERNAL_H_

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Constant
 */

/* Supported command type */
#define NFC110_SUPPORTED_COMMAND_TYPE           3    /* 0-63 */

/* RBT setting numbers */
#if (NFC110_SUPPORTED_COMMAND_TYPE == 3)
#define NFC110_RBT_INITIATOR_ISO18092_212K      0x01
#define NFC110_RBT_INITIATOR_ISO18092_424K      0x01
#endif

#ifdef __cplusplus
}
#endif

#endif /* !NFC110_INTERNAL_H_ */
