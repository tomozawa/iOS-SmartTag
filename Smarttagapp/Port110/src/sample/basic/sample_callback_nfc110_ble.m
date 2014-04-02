/*
 * Copyright 2013 Sony Corporation
 */

#import "sample_callback_nfc110_ble.h"

#import "nfc110_ble.h"

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

/* This functions are defined in another file. */
extern const icsdrv_basic_func_t* g_drv_func;

static const char* s_uuid = DEFAULT_UUID;
static UINT32 s_timeout = DEFAULT_TIMEOUT;
static ICS_HW_DEVICE s_dev;

@implementation SampleCallback

static void on_change_conn_status2_callback(
                                            void *obj,
                                            UINT16 result,
                                            ICS_HANDLE handle,
                                            void *arg)
{
    printf("  called on_change_conn_status2_callback() ...\n");
    printf("    cause: %02x\n", result);
    
    return;
}

static int initialize(
                      ICS_HW_DEVICE* dev)
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

+ (void)registerCallback
{
    UINT32 rc;
    nfc110_on_change_conn_status2_func_t callback;

    printf("  calling nfc110_ble_raw_register_change_conn_status_callback2() ...\n");
    callback = on_change_conn_status2_callback;
    rc = nfc110_ble_raw_register_change_conn_status_callback2(callback, NULL);
    if (rc != ICS_ERROR_SUCCESS) {
        fprintf(stderr, "    failure in nfc110_ble_raw_register_change_conn_status_callback2():%u\n", rc);
    }
    
    return;
}

+ (void)unregisterCallback
{
    UINT32 rc;
    
    printf("  calling nfc110_ble_raw_register_change_conn_status_callback2() ...\n");
    rc = nfc110_ble_raw_register_change_conn_status_callback2(NULL, NULL);
    if (rc != ICS_ERROR_SUCCESS) {
        fprintf(stderr, "    failure in nfc110_ble_raw_register_change_conn_status_callback2():%u\n", rc);
    }
    
    return;
}

+ (void)start
{
    initialize(&s_dev);
    
    return;
}

+ (void)stop
{
    finalize(&s_dev);
    
    return;
}

@end
