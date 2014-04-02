/*
 * Copyright 2013 Sony Corporation
 */

#import "sample_polling.h"

#import "felica_card.h"
#import "felica_cc.h"
#import "felica_cc_stub.h"

#import "ics_types.h"
#import "ics_error.h"
#import "ics_hwdev.h"
#import "icsdrv.h"
#import "icslib_chk.h"
#import "icslog.h"

#ifndef DEFAULT_UUID
#define DEFAULT_UUID ""
#endif
#ifndef DEFAULT_TIMEOUT
#define DEFAULT_TIMEOUT 400 /* ms */
#endif
#ifndef DEFAULT_SYSTEM_CODE
#define DEFAULT_SYSTEM_CODE 0xffff
#endif
#ifndef DEFAULT_POLLING_MAX_RETRY_TIMES
#define DEFAULT_POLLING_MAX_RETRY_TIMES 9
#endif
#ifndef DEFAULT_POLLING_INTERVAL
#define DEFAULT_POLLING_INTERVAL 500 /* ms */
#endif
#ifndef DEFAULT_POLLING_OPTION
#define DEFAULT_POLLING_OPTION 0
#endif
#ifndef DEFAULT_POLLING_TIMESLOT
#define DEFAULT_POLLING_TIMESLOT 0
#endif

//#############################################
#ifndef DEFAULT_COMMAND_MAX_RETRY_TIMES
#define DEFAULT_COMMAND_MAX_RETRY_TIMES 2
#endif
#ifndef FELICA_COMMAND_TIMEOUT_ADD
#define FELICA_COMMAND_TIMEOUT_ADD 16 /* ms */
#endif
static UINT32 s_command_max_retry_times = DEFAULT_COMMAND_MAX_RETRY_TIMES;
//#############################################

/* These functions are defined in another file. */
extern const icsdrv_basic_func_t* g_drv_func;
extern UINT32 (*g_felica_cc_stub_initialize_func)(
                                                  felica_cc_devf_t* devf,
                                                  ICS_HW_DEVICE* dev);

static const char* s_uuid = DEFAULT_UUID;
static UINT32 s_timeout = DEFAULT_TIMEOUT;
static UINT16 s_system_code = DEFAULT_SYSTEM_CODE;
static UINT32 s_polling_max_retry_times = DEFAULT_POLLING_MAX_RETRY_TIMES;
static UINT32 s_polling_interval = DEFAULT_POLLING_INTERVAL;
static UINT8 s_polling_option = DEFAULT_POLLING_OPTION;
static UINT8 s_polling_timeslot = DEFAULT_POLLING_TIMESLOT;

@implementation SamplePolling

static int initialize(
                      ICS_HW_DEVICE* dev,
                      felica_cc_devf_t* devf)
{
    UINT32 rc;
    
    printf("start initialization ...\n");
    
    printf("  calling open(%s) ...\n", s_uuid);
    rc = g_drv_func->open(dev, s_uuid);
    if (rc != ICS_ERROR_SUCCESS) {
        fprintf(stderr, "    failure in open():%u\n", rc);
        return -1;
    }
    
    if (g_drv_func->initialize_device != NULL) {
        printf("  calling initialize_device() ...\n");
        rc = g_drv_func->initialize_device(dev, s_timeout);
        if (rc != ICS_ERROR_SUCCESS) {
            fprintf(stderr, "    failure in initialize_device():%u\n", rc);
            rc = g_drv_func->close(dev);
            if (rc != ICS_ERROR_SUCCESS) {
                fprintf(stderr, "    failure in close():%u\n", rc);
                /* Note: continue */
            }
            return -1;
        }
    }
    
    printf("  calling felica_cc_stub_initialize() ...\n");
    rc = (*g_felica_cc_stub_initialize_func)(devf, dev);
    if (rc != ICS_ERROR_SUCCESS) {
        fprintf(stderr, "    failure in felica_cc_stub_initialize():%u\n", rc);
        rc = g_drv_func->close(dev);
        if (rc != ICS_ERROR_SUCCESS) {
            fprintf(stderr, "    failure in close():%u\n", rc);
            /* Note: continue */
        }
        return -1;
    }
    
    printf("  calling ping() ...\n");
    if (g_drv_func->ping != NULL) {
        rc = g_drv_func->ping(dev, s_timeout);
        if (rc != ICS_ERROR_SUCCESS) {
            fprintf(stderr, "    failure in ping():%u\n", rc);
            rc = g_drv_func->close(dev);
            if (rc != ICS_ERROR_SUCCESS) {
                fprintf(stderr, "    failure in close():%u\n", rc);
                /* Note: continue */
            }
            return -1;
        }
    }
    
    return 0;
}

static int finalize(
                    ICS_HW_DEVICE* dev)
{
    UINT32 rc;
    
    printf("start finalization ...\n");
    
    if (g_drv_func->rf_off != NULL) {
        printf("  calling rf_off() ...\n");
        rc = g_drv_func->rf_off(dev, s_timeout);
        if (rc != ICS_ERROR_SUCCESS) {
            fprintf(stderr, "    failure in rf_off():%u\n", rc);
            /* Note: continue */
        }
    }
    
    printf("  calling close() ...\n");
    rc = g_drv_func->close(dev);
    if (rc != ICS_ERROR_SUCCESS) {
        fprintf(stderr, "    failure in close():%u\n", rc);
        return -1;
    }
    
    return 0;
}

+ (void)start
{
    int res;
    UINT32 rc;
    int i;
    UINT32 nretries;
    ICS_HW_DEVICE dev;
    felica_cc_devf_t devf;
    felica_card_t card;
    felica_card_option_t card_option;
    
    printf("FeliCa Polling sample.\n");
    
    res = initialize(&dev, &devf);
    if (res != 0) {
        return;
    }
    
    for(int k=0; k<100;k++){
    /*
     * Polling
     */
    {
        UINT8 polling_param[4];
        
        polling_param[0] = (UINT8)((s_system_code >> 8) & 0xff);
        polling_param[1] = (UINT8)((s_system_code >> 0) & 0xff);
        polling_param[2] = s_polling_option;
        polling_param[3] = s_polling_timeslot;
        
        printf("start Polling ...\n");
        
        for (nretries = 0; nretries <= s_polling_max_retry_times; nretries++) {
            printf("  calling felica_cc_polling() ...\n");
            rc = felica_cc_polling(&devf,
                                   polling_param,
                                   &card,
                                   &card_option,
                                   s_timeout);
            if (rc != ICS_ERROR_TIMEOUT) {
                break;
            }
            fprintf(stderr, "    felica_cc_polling(): polling timeout.\n");
            utl_msleep(2000);
        }
        if (rc != ICS_ERROR_SUCCESS) {
            fprintf(stderr, "    failure in felica_cc_polling():%u\n", rc);
            finalize(&dev);
            return;
        }
        
        printf("    IDm: %02x%02x%02x%02x%02x%02x%02x%02x\n",
               card.idm[0], card.idm[1], card.idm[2], card.idm[3],
               card.idm[4], card.idm[5], card.idm[6], card.idm[7]);
        printf("    PMm: %02x%02x%02x%02x%02x%02x%02x%02x\n",
               card.pmm[0], card.pmm[1], card.pmm[2], card.pmm[3],
               card.pmm[4], card.pmm[5], card.pmm[6], card.pmm[7]);
        printf("    Option: ");
        for (i = 0; i < (int)card_option.option_len; i++) {
            printf("%02x", card_option.option[i]);
        }
        printf("\n");
    }
        utl_msleep(2000);
    }
    finalize(&dev);
    
    return;
}

+ (void)start1
{
    int res;
    UINT32 rc;
    int i;
    UINT32 nretries;
    ICS_HW_DEVICE dev;
    felica_cc_devf_t devf;
    felica_card_t card;
    felica_card_option_t card_option;
    UINT32 command_timeout;
    
    printf("FeliCa read/write access sample.\n");
    
    res = initialize(&dev, &devf);
    if (res != 0) {
        return;
    }
    
    /*
     * Polling
     */
    {
        UINT8 polling_param[4];
        
        polling_param[0] = (UINT8)((s_system_code >> 8) & 0xff);
        polling_param[1] = (UINT8)((s_system_code >> 0) & 0xff);
        polling_param[2] = s_polling_option;
        polling_param[3] = s_polling_timeslot;
        
        printf("start Polling ...\n");
        
        for (nretries = 0; nretries <= s_polling_max_retry_times; nretries++) {
            printf("  calling felica_cc_polling() ...\n");
            rc = felica_cc_polling(&devf,
                                   polling_param,
                                   &card,
                                   &card_option,
                                   s_timeout);
            if (rc != ICS_ERROR_TIMEOUT) {
                break;
            }
            fprintf(stderr, "    felica_cc_polling(): polling timeout.\n");
            utl_msleep(s_polling_interval);
        }
        if (rc != ICS_ERROR_SUCCESS) {
            fprintf(stderr, "    failure in felica_cc_polling():%u\n", rc);
            finalize(&dev);
            return;
        }
        
        printf("    IDm: %02x%02x%02x%02x%02x%02x%02x%02x\n",
               card.idm[0], card.idm[1], card.idm[2], card.idm[3],
               card.idm[4], card.idm[5], card.idm[6], card.idm[7]);
        printf("    PMm: %02x%02x%02x%02x%02x%02x%02x%02x\n",
               card.pmm[0], card.pmm[1], card.pmm[2], card.pmm[3],
               card.pmm[4], card.pmm[5], card.pmm[6], card.pmm[7]);
        printf("    Option: ");
        for (i = 0; i < (int)card_option.option_len; i++) {
            printf("%02x", card_option.option[i]);
        }
        printf("\n");
    }
    
    /*
     * Write Without Encryption(ステータス確認)
     */
    {
        const UINT16 service_code_list[1] = {
            0x0009
        };
        const UINT8 block_list[2 * 1] = {
            0x80, 0x00, /* service code list #0, block #0 */
        };
        UINT8 block_data[1 * 16] = {
            0xD0,   // Func. No.
            0x01,   // Fsum
            0x01,   // Fnum
            0x00,   // Size
            0x00,   // Seq
            0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        };
        UINT8 status_flag1;
        UINT8 status_flag2;
        
        command_timeout =
        FELICA_CC_CALC_TIMEOUT(
                               card.pmm[FELICA_CC_PMM_WRITE_WITHOUT_ENCRYPTION],
                               4);
        command_timeout += FELICA_COMMAND_TIMEOUT_ADD;
        
        printf("start Write Without Encryption ...\n");
        
        for (nretries = 0; nretries <= s_command_max_retry_times; nretries++) {
            printf("  calling felica_cc_write_without_encryptioin() ...\n");
            rc = felica_cc_write_without_encryption(&devf,
                                                    &card,
                                                    1,
                                                    service_code_list,
                                                    1,
                                                    block_list,
                                                    block_data,
                                                    &status_flag1,
                                                    &status_flag2,
                                                    command_timeout);
            if ((rc != ICS_ERROR_TIMEOUT) &&
                (rc != ICS_ERROR_FRAME_CRC)) {
                break;
            }
        }
        if (rc != ICS_ERROR_SUCCESS) {
            fprintf(stderr,
                    "    failure in felica_cc_read_without_encryption():%u\n",
                    rc);
            if (rc == ICS_ERROR_STATUS_FLAG1) {
                fprintf(stderr, "    status_flag1 = %02x\n", status_flag1);
                fprintf(stderr, "    status_flag2 = %02x\n", status_flag2);
            }
            finalize(&dev);
            return;
        }
        
        printf("    status_flag1 = %02x\n", status_flag1);
        printf("    status_flag2 = %02x\n", status_flag2);
    }
    
    /*
     * Read Without Encryption
     */
    {
        const UINT16 service_code_list[1] = {
            0x0009
        };
        const UINT8 block_list[2 * 2] = {
            0x80, 0x00, /* service code list #0, block #0 */
            0x80, 0x00, /* service code list #0, block #1 */
        };
        UINT8 block_data[2 * 16];
        UINT8 status_flag1;
        UINT8 status_flag2;
        
        command_timeout =
        FELICA_CC_CALC_TIMEOUT(
                               card.pmm[FELICA_CC_PMM_READ_WITHOUT_ENCRYPTION],
                               4);
        command_timeout += FELICA_COMMAND_TIMEOUT_ADD;
        
        printf("start Read Without Encryption ...\n");
        
        for (nretries = 0; nretries <= s_command_max_retry_times; nretries++) {
            printf("  calling felica_cc_read_without_encryptioin() ...\n");
            rc = felica_cc_read_without_encryption(&devf,
                                                   &card,
                                                   1,
                                                   service_code_list,
                                                   2,
                                                   block_list,
                                                   block_data,
                                                   &status_flag1,
                                                   &status_flag2,
                                                   command_timeout);
            if ((rc != ICS_ERROR_TIMEOUT) &&
                (rc != ICS_ERROR_FRAME_CRC)) {
                break;
            }
        }
        if (rc != ICS_ERROR_SUCCESS) {
            fprintf(stderr,
                    "    failure in felica_cc_read_without_encryption():%u\n",
                    rc);
            if (rc == ICS_ERROR_STATUS_FLAG1) {
                fprintf(stderr, "    status_flag1 = %02x\n", status_flag1);
                fprintf(stderr, "    status_flag2 = %02x\n", status_flag2);
            }
            finalize(&dev);
            return;
        }
        
        printf("    status_flag1 = %02x\n", status_flag1);
        printf("    status_flag2 = %02x\n", status_flag2);
        printf("    Read data:\n");
        for (i = 0; i < sizeof(block_data); i++ ) {
            if ((i % 16) == 0) {
                printf("      ");
            }
            printf("%02x", block_data[i]);
            if ((i % 16) == 15) {
                printf("\n");
            }
        }
    }
    
    finalize(&dev);
    
    return;
}
@end
