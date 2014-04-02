//
//  Port110.m
//  SmartTagApp
//

#undef ICSLOG_MODULE
#define ICSLOG_MODULE "110"

#import "Port110.h"
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
#define DEFAULT_SYSTEM_CODE 0xfee1
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
#ifndef DEFAULT_COMMAND_MAX_RETRY_TIMES
#define DEFAULT_COMMAND_MAX_RETRY_TIMES 2
#endif

/* These functions are defined in another file. */
extern const icsdrv_basic_func_t* g_drv_func;
extern UINT32 (*g_felica_cc_stub_initialize_func)(felica_cc_devf_t* devf,
                                                  ICS_HW_DEVICE* dev);

static const char* s_uuid = DEFAULT_UUID;
static UINT32 s_timeout = DEFAULT_TIMEOUT;
static UINT16 s_system_code = DEFAULT_SYSTEM_CODE;
static UINT8 s_polling_option = DEFAULT_POLLING_OPTION;
static UINT8 s_polling_timeslot = DEFAULT_POLLING_TIMESLOT;
static UINT32 s_command_max_retry_times = DEFAULT_COMMAND_MAX_RETRY_TIMES;

ICS_HW_DEVICE dev;
felica_cc_devf_t devf;
felica_card_t card;


// サービスリスト
const UINT16 service_code_list[1] = {
    0x0009
};

//ブロックリスト
const UINT8 block_list[2 * 4] = {
    0x80, 0x00, /* service code list #0, block #0 */
    0x80, 0x01, /* service code list #0, block #1 */
    0x80, 0x02, /* service code list #0, block #2 */
    0x80, 0x03, /* service code list #0, block #3 */
};

//受信済みレスポンスデータから取り出したメインのデータ
NSMutableData *recievedData;

//受信済みレスポンスのコマンドステータス
unsigned char responsStatus;

//受信済みレスポンスのエラーコード
unsigned char errorCode;

//ペリフェラル名
NSString* _peripheralName;

@implementation Port110

#pragma mark -
#pragma mark - Singleton

+ (Port110 *) shared
{
    static Port110 *_port110 = nil;
    
    @synchronized (self){
        static dispatch_once_t pred;
        dispatch_once(&pred, ^{
            _port110 = [[Port110 alloc] init];
        });
    }
    
    return _port110;
}

#pragma mark -
#pragma mark - Port110 control public methods

+ (int) initialize
{
    return [[Port110 shared] _initialize];
}

+ (int) find
{
    return [[Port110 shared] _findModule:PORT110_FIND_TIMEOUT];
}

+ (int) findWithName:(NSString*)name
{
    return [[Port110 shared] _findModuleWithName:name timeout:PORT110_FIND_TIMEOUT];
}

+ (int) disconnect
{
    return [[Port110 shared] _disconnectModule];
}

+ (int) polling
{
    return [[Port110 shared] _polling];
}

+ (int) write:(NSMutableData *)command
{
    return [[Port110 shared] _write:command];
}

+ (int) read:(int)block_number
{
    return [[Port110 shared] _read:block_number];
}

+ (BOOL) isConnected
{
    return [[Port110 shared] _isConnected];
}

+ (BOOL) isReady
{
    return [[Port110 shared] _isReady];
}

+ (NSString *) peripheralName
{
    return _peripheralName;
}

+ (NSMutableData *) getRecievedData
{
    return [[Port110 shared] _getRecievedData];
}

+ (unsigned char) getResponsStatus
{
    return [[Port110 shared] _getResponsStatus];
}

+ (unsigned char) getErrorCode
{
    return [[Port110 shared] _getErrorCode];
}

#pragma mark -
#pragma mark - Port110 public event methods

+ (void) addObserver:(id)notificationObserver selector:(SEL)notificationSelector name:(NSString*)notificationName
{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:notificationObserver selector:notificationSelector name:notificationName object:nil];
}

+ (void) removeObserver:(id)notificationObserver
{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:notificationObserver];
}

#pragma mark -
#pragma mark - Port110 private event methods

- (void) postNotification:(NSString*)notificationName
{
    NSNotification *n = [NSNotification notificationWithName:notificationName object:self];
    [[NSNotificationCenter defaultCenter] postNotification:n];
}

- (void) postNotificationAsync:(NSString*)notificationName
{
    NSNotification *n = [NSNotification notificationWithName:notificationName object:self];
    NSNotificationQueue *q = [NSNotificationQueue defaultQueue];
    [q enqueueNotification:n postingStyle:NSPostASAP];
}

#pragma mark -
#pragma mark - Port110 control private methods

- (int) _initialize
{
    isReady = NO;
    isConnected = NO;
    isCallFind = NO;
    findName = @"";

    return PORT110_SUCCESS;
}

- (int) _findModule:(int) timeout
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int res;
        res = _open(&dev, &devf);
        if (res != 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[Port110 shared] postNotification:PORT110_EVENT_PERIPHERAL_NOT_FOUND];
            });
        }
        else{
            dispatch_async(dispatch_get_main_queue(), ^{
                isReady = YES;
                isConnected = YES;
                [[Port110 shared] postNotification:PORT110_EVENT_CONNECTED];
            });
        }
    });
    
    return PORT110_SUCCESS;
}

- (int) _findModuleWithName:(NSString*)name timeout:(int)timeout{
    s_uuid = name.UTF8String;
    return [self _findModule:timeout];
}

- (NSMutableData *) _getRecievedData
{
    return recievedData;
}

- (unsigned char) _getResponsStatus
{
    return responsStatus;
}

- (unsigned char) _getErrorCode
{
    return errorCode;
}

-(int) _polling
{
    p110_polling(&dev, &devf, &card);

    [[Port110 shared] postNotification:PORT110_EVENT_POLLING_COMPLETE];

    return PORT110_SUCCESS;
}

-(int) _write:(NSMutableData *)command
{
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        p110_write(command);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self postNotification:PORT110_EVENT_RECEIVE_WWER_COMPLETE];
        });
    });
    
    return PORT110_SUCCESS;
 }

-(int) _read:(int)block_number
{
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        NSMutableData* response;
        p110_read(block_number,response);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self postNotification:PORT110_EVENT_SEND_RWE_COMPLETE];
        });
    });
    
    return PORT110_SUCCESS;
}

- (int) _disconnectModule
{
    return PORT110_SUCCESS;
}

- (BOOL) _isConnected
{
    return isConnected;
}

- (BOOL) _isReady
{
    return isReady;
}

#pragma mark -
#pragma mark - Port110 control private C functions

static int _open(ICS_HW_DEVICE* dev,
                           felica_cc_devf_t* devf)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "_open"
    UINT32 rc;
    
    ICSLOG_FUNC_BEGIN;
    ICSLOG_DBG_PTR(dev);
    ICSLOG_DBG_PTR(devf);

    ICSLOG_DBG_PRINT_ARG("calling open(%s) ...\n", s_uuid);
    rc = g_drv_func->open(dev, s_uuid);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "failure in open()");
        errorCode = R_STS_ERR;
        return PORT110_FAILURE;
    }
    
    if (g_drv_func->initialize_device != NULL) {
        ICSLOG_DBG_PRINT_ARG("calling initialize_device() ...\n");
        rc = g_drv_func->initialize_device(dev, s_timeout);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc, "failure in initialize_device()");
            rc = g_drv_func->close(dev);
            if (rc != ICS_ERROR_SUCCESS) {
                ICSLOG_ERR_STR(rc, "failure in close()");
                /* Note: continue */
            }
            errorCode = R_STS_ERR;
            return PORT110_FAILURE;
        }
    }
    
    ICSLOG_DBG_PRINT_ARG("calling felica_cc_stub_initialize() ...\n");
    rc = (*g_felica_cc_stub_initialize_func)(devf, dev);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "failure in felica_cc_stub_initialize()");
        rc = g_drv_func->close(dev);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc, "failure in close()");
            /* Note: continue */
        }
        errorCode = R_STS_ERR;
        return PORT110_FAILURE;
    }
    
    ICSLOG_DBG_PRINT_ARG("calling ping() ...\n");
    if (g_drv_func->ping != NULL) {
        rc = g_drv_func->ping(dev, s_timeout);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc, "failure in ping()");
            rc = g_drv_func->close(dev);
            if (rc != ICS_ERROR_SUCCESS) {
                ICSLOG_ERR_STR(rc, "failure in close()");
                /* Note: continue */
            }
            errorCode = R_STS_ERR;
            return PORT110_FAILURE;
        }
    }
    unsigned char arg[ARG_MAX];
    rc = nfc110_get_attribute(dev, &arg);

    _peripheralName = [NSString stringWithCString: (const char*)arg encoding:NSUTF8StringEncoding];

    errorCode = R_STS_OK;
    ICSLOG_FUNC_END;
    return PORT110_SUCCESS;
}

static int _close(ICS_HW_DEVICE* dev)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "p110_finalize"
    UINT32 rc;
    
    ICSLOG_FUNC_BEGIN;
    ICSLOG_DBG_PTR(dev);
    
    errorCode = R_STS_OK;

    if (g_drv_func->rf_off != NULL) {
        printf("  calling rf_off() ...\n");
        rc = g_drv_func->rf_off(dev, s_timeout);
        if (rc != ICS_ERROR_SUCCESS) {
            ICSLOG_ERR_STR(rc, "failure in rf_off()");
            /* Note: continue */
            errorCode = R_STS_ERR;
        }
    }
    
    printf("  calling close() ...\n");
    rc = g_drv_func->close(dev);
    if (rc != ICS_ERROR_SUCCESS) {
        ICSLOG_ERR_STR(rc, "failure in close()");
        errorCode = R_STS_ERR;
        return PORT110_FAILURE;
    }
    
    ICSLOG_FUNC_END;
    return PORT110_SUCCESS;
}

static int _reset(ICS_HW_DEVICE* dev)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "p110_reset"
    UINT32 rc;
    UINT32 timeout;
    
    ICSLOG_FUNC_BEGIN;
    ICSLOG_DBG_PTR(dev);

    timeout = DEFAULT_TIMEOUT;
    rc = g_drv_func->reset (
            dev,
            timeout);
    
    ICSLOG_FUNC_END;
    return PORT110_SUCCESS;
}

static int p110_polling(ICS_HW_DEVICE* dev,
                        felica_cc_devf_t* devf,
                        felica_card_t* card)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "p110_polling"
    UINT32 rc;
    
    int i;
    felica_card_option_t card_option;
    
    ICSLOG_FUNC_BEGIN;
    ICSLOG_DBG_PTR(&devf);

    ICSLOG_DBG_PRINT_ARG("FeliCa Polling\n");

    UINT8 polling_param[4];
    
    polling_param[0] = (UINT8)((s_system_code >> 8) & 0xff);
    polling_param[1] = (UINT8)((s_system_code >> 0) & 0xff);
    polling_param[2] = s_polling_option;
    polling_param[3] = s_polling_timeslot;
    
    ICSLOG_DUMP(polling_param, 4);
    ICSLOG_DBG_UINT(s_timeout);

    ICSLOG_DBG_PRINT_ARG("start Polling...\n");

    ICSLOG_DBG_PRINT_ARG("calling felica_cc_polling() ...\n");
    rc = felica_cc_polling(devf,
                           polling_param,
                           card,
                           &card_option,
                           s_timeout);

    if (rc == ICS_ERROR_TIMEOUT) {
        //タイムアウト
        ICSLOG_ERR_STR(rc, "polling timeout");
        
        responsStatus = R_CMD_RESPONSE_ERROR;
        errorCode = R_STS_TIME_OVR;

        return PORT110_SUCCESS;
    }
    if (rc != ICS_ERROR_SUCCESS) {
        //エラー
        ICSLOG_ERR_STR(rc, "failure");
        _close(dev);
        _reset(dev);
        _open(dev, devf);
        responsStatus = R_CMD_RESPONSE_ERROR;
        errorCode = R_STS_CMD_ERR;

        return PORT110_FAILURE;
    }
    nfc110_rf_off(dev,s_timeout);
    
    ICSLOG_DBG_PRINT_ARG("    IDm: %02x%02x%02x%02x%02x%02x%02x%02x\n",
           card->idm[0], card->idm[1], card->idm[2], card->idm[3],
           card->idm[4], card->idm[5], card->idm[6], card->idm[7]);
    ICSLOG_DBG_PRINT_ARG("    PMm: %02x%02x%02x%02x%02x%02x%02x%02x\n",
           card->pmm[0], card->pmm[1], card->pmm[2], card->pmm[3],
           card->pmm[4], card->pmm[5], card->pmm[6], card->pmm[7]);
    ICSLOG_DBG_PRINT_ARG("    Option: ");
    for (i = 0; i < (int)card_option.option_len; i++) {
        ICSLOG_DBG_PRINT_ARG("%02x", card_option.option[i]);
    }
    ICSLOG_DBG_PRINT_ARG("\n");
    
    recievedData = [NSData dataWithBytes:(const void *)card->idm length:(sizeof(unsigned char) * 8)];
    responsStatus = R_CMD_RESPONSE_DATA;
    errorCode = R_STS_OK;
    
    ICSLOG_FUNC_END;
    return PORT110_SUCCESS;
}

static int p110_write(NSMutableData* command)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "p110_write"
    UINT32 rc;

    UINT8 status_flag1;
    UINT8 status_flag2;
    UINT32 command_timeout=DEFAULT_TIMEOUT;

    ICSLOG_FUNC_BEGIN;
    ICSLOG_DBG_PTR(&devf);

    int numBlocks = ceil(command.length/16.0) ;

    ICSLOG_DBG_PRINT_ARG("calling felica_cc_write_without_encryption() ...\n");
    rc = felica_cc_write_without_encryption(&devf,
                                            &card,
                                            1,
                                            service_code_list,
                                            numBlocks,
                                            block_list,
                                            command.bytes,
                                            
                                            &status_flag1,
                                            &status_flag2,
                                            command_timeout);
    if (rc != ICS_ERROR_SUCCESS) {
        errorCode = R_STS_ERR;
        return PORT110_FAILURE;
    }
    
    errorCode = R_STS_OK;

    ICSLOG_FUNC_END;
    return PORT110_SUCCESS;
}

static int p110_read(UINT32 block_number, NSMutableData* response)
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "p110_read"
    UINT32 rc;

    UINT32 nretries;

    UINT8 block_data[12 * 16];
    UINT8 status_flag1;
    UINT8 status_flag2;
    
    ICSLOG_FUNC_BEGIN;
    ICSLOG_DBG_PTR(&devf);
    
    UINT32 command_timeout=DEFAULT_TIMEOUT;
    
    
    for (nretries = 0; nretries <= s_command_max_retry_times; nretries++) {
        ICSLOG_DBG_PRINT_ARG("calling felica_cc_read_without_encryption() ...\n");
        rc = felica_cc_read_without_encryption(&devf,
                                               &card,
                                               1,
                                               service_code_list,
                                               block_number,
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
            ICSLOG_DBG_PRINT_ARG("    status_flag1 = %02x\n", status_flag1);
            ICSLOG_DBG_PRINT_ARG("    status_flag2 = %02x\n", status_flag2);
        }
        errorCode = R_STS_ERR;
        return PORT110_FAILURE;
    }
    
    ICSLOG_DBG_PRINT_ARG("    status_flag1 = %02x\n", status_flag1);
    ICSLOG_DBG_PRINT_ARG("    status_flag2 = %02x\n", status_flag2);

    response = [NSMutableData dataWithBytes:(const void *)block_data length:block_number*16];
    recievedData = [NSData dataWithBytes:(const void *)block_data length:block_number*16];
    
    errorCode = R_STS_OK;

    ICSLOG_FUNC_END;
    return PORT110_SUCCESS;
}

@end
