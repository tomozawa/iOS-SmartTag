//
//  Port110.h
//  SmartTagApp
//

#import <UIKit/UIKit.h>


// Port110 common


//RFIDリーダーのコマンド
const unsigned char R_CMD_RESPONSE_DATA     =  0x0; // レスポンスコマンド 正常時
const unsigned char R_CMD_RESPONSE_ERROR    =  0x1; // レスポンスコマンド エラー時

//RFIDリーダーのステータス／エラーコード
const unsigned char R_STS_OK                =  0x00; // オーケー
const unsigned char R_STS_TIME_OVR          =  0x02; // タイムオーバー 規定時間内にタグが反応しない、あるいはタグ側の 処理が正常に終了しなかった
const unsigned char R_STS_ERR               =  0x07; // コマンド実行エラー
const unsigned char R_STS_CMD_ERR           =  0x44; // コマンドまたはパラメータが不正

#define PORT110_SUCCESS 0
#define PORT110_FAILURE -1

#define PORT110_EVENT_CONNECTED                 @"Port110EventConnected"
#define PORT110_EVENT_DISCONNECTED              @"Port110EventDisconnected"
#define PORT110_EVENT_PERIPHERAL_NOT_FOUND      @"Port110EventPeripheralNotFound"
#define PORT110_EVENT_POLLING_COMPLETE          @"Port110EventPollingComplete"
#define PORT110_EVENT_RECEIVE_WWER_COMPLETE     @"Port110EventReceiveWwerComplete"
#define PORT110_EVENT_SEND_RWE_COMPLETE         @"Port110EventSendRweComplete"

#define PORT110_FIND_TIMEOUT 2

// Port110 interface
@interface Port110 : NSObject
{
    // status
    BOOL isCallFind;
    NSString *findName;
    BOOL isReady;
    BOOL isConnected;
}

// Singleton
+ (Port110 *) shared;

// Port110 control methods
+ (int) initialize;
+ (int) find;
+ (int) findWithName:(NSString*)name;
+ (int) disconnect;
+ (int) polling;
+ (int) write:(NSMutableData *)command;
+ (int) read:(int)num_block;
+ (NSMutableData *) getRecievedData;
+ (unsigned char) getResponsStatus;
+ (unsigned char) getErrorCode;
+ (BOOL) isConnected;
+ (BOOL) isReady;
+ (NSString *)peripheralName;

// Port110 event methods
+ (void) addObserver:(id)notificationObserver selector:(SEL)notificationSelector name:(NSString*)notificationName;
+ (void) removeObserver:(id)notificationObserver;

@end
