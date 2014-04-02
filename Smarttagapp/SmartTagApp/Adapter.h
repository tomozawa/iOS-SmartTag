//
//  Adapter.h
//  SmartTagApp
//

#import <Foundation/Foundation.h>


/*** リーダーの種別定数 ***/
//TODO:ViewControlerマージ後削除
#define RFID_READER 1
#define BARCODE_READER 2


/*** イベント定数 ***/

//準備完了
#define ADAPTER_EVENT_READY               @"AdapterEventReady"

//通信中にエラー発生
#define ADAPTER_EVENT_ERROR               @"AdapterEventError"


//RFIDリーダーからのデータ読み込みが完了
#define ADAPTER_EVENT_RECIEVE_DATA_COMPLETE       @"AdapterEventRecieveDataComplete"
//コマンドキューに入っている全てのコマンドのレスポンスを受け取った
#define ADAPTER_EVENT_ALL_CARD_COMMAND_COMPLETE  @"AdapterEventAllCardCommandRecieved"
//RFIDリーダーからエラーレスポンス
#define ADAPTER_EVENT_RECIEVE_ERROR               @"AdapterEventRecieveError"
//RFIDリーダーからエラーレスポンス
#define ADAPTER_EVENT_RECIEVE_TIMEOVER_ERROR      @"AdapterEventRecieveTimeoverError"
//スマートタグ　カードコマンドのWWE Resp.の受信が完了
#define ADAPTER_EVENT_RECIEVE_WWER_COMPLETE       @"AdapterEventRecieveWWERComplete"
//スマートタグ　カードコマンドのRWE Resp.の受信が完了
#define ADAPTER_EVENT_RECIEVE_RWER_COMPLETE       @"AdapterEventRecieveRWERComplete"
//スマートタグ　カードコマンドのWWEの送信が完了
#define ADAPTER_EVENT_SEND_WWE_COMPLETE           @"AdapterEventSendWWEComplete"

#define ADAPTER_EVENT_RECIEVE_STX                 @"AdapterEventRecieveStx"



//RFIDリーダーにタッチされたFELICAがスマートタグではない
#define ADAPTER_EVENT_FELICA_IS_NOT_SMARTTAG      @"AdapterEventFelicaisNotSmarttag"
//RFIDリーダーにスマートタグがタッチ
#define ADAPTER_EVENT_SMARTTAG_IS_TOUCHED         @"AdapterEventSmarttagisTouched"
//RFIDリーダーからスマートタグが離れた
#define ADAPTER_EVENT_SMARTTAG_IS_RELEASED        @"AdapterEventSmarttagisReleased"
//スマートタグの書き込み準備が完了
#define ADAPTER_EVENT_SMARTTAG_IS_READY           @"AdapterEventSmarttagisReady"
//スマートタグのバッテリーの交換が必要
#define ADAPTER_EVENT_SMARTTAG_IS_LOW_BATTERY     @"AdapterEventSmartTagisLowBattery"
//スマートタグがなんらかの処理中
#define ADAPTER_EVENT_SMARTTAG_IS_IN_PROGRESS     @"AdapterEventSmartTagisInProgress"


//スマートタグ　ポーリング停止完了
#define ADAPTER_EVENT_STOP_POLLING_COMPLETE       @"AdapterEventStopPollingComplete"
//スマートタグ　ポーリング＆ステータスチェック完了
#define ADAPTER_EVENT_CHECK_STATUS_COMPLETE       @"AdapterEventCheckSmarttagComplete"
//スマートタグ　デモ画像表を表示完了
#define ADAPTER_EVENT_SHOW_DEMO_COMPLETE          @"AdapterEventShowDemoComplete"
//スマートタグ　ディスプレイクリア完了
#define ADAPTER_EVENT_CLEAR_DISPLAY_COMPLETE      @"AdapterEventClearDisplayComplete"
//スマートタグ　URL書き込み完了
#define ADAPTER_EVENT_SAVE_URL_COMPLETE           @"AdapterEventSaveURLComplete"
//スマートタグ　URL読み出し完了
#define ADAPTER_EVENT_LOAD_URL_COMPLETE           @"AdapterEventLoadURLComplete"
//スマートタグ　表示データの登録完了
#define ADAPTER_EVENT_SAVE_LAYOUT_COMPLETE        @"AdapterEventSaveLayoutComplete"
//スマートタグ　登録データの表示完了
#define ADAPTER_EVENT_SHOW_LAYOUT_COMPLETE        @"AdapterEventShowLayoutComplete"
//スマートタグ　画像の表示
#define ADAPTER_EVENT_SHOW_IMAGE_COMPLETE         @"AdapterEventShowImageComplete"

//バーコードリーダーからバーコードデータ受信
#define ADAPTER_EVENT_BARCODE_DATA_RECIEVED       @"AdapterEventBarcodeDataRecieved"



#define PROGRESS_TEXT_CHECK_STATUS    @"ステータス確認中\n(画面タップでキャンセル)"
#define PROGRESS_TEXT_SEND_DATA       @"データ送信中"
#define PROGRESS_TEXT_READ_DATA       @"データ読取中"
#define PROGRESS_TEXT_TAP_TO_CANCEL   @"(画面タップでキャンセル)"
#define PROGRESS_TEXT_CANCELING       @"キャンセル中"





@interface Adapter : NSObject

// Singleton
+ (Adapter *) shared;


//common
+ (void) initializeAdapter;
+ (void) finalizeAdapter;
+ (void) findPort110;
+ (void) setReaderDevice:(int)type;
+ (NSMutableData *) getRecievedData;
+ (unsigned char) getResponsStatus;

//RFID
+ (void) startPolling;
+ (void) stopPolling;
+ (void) showDemo:(int)layout;
+ (void) clearDisplay;
+ (void) showLayout:(int)layout;
+ (void) saveScreen:(int)layout;
+ (void) showImage:(UIImage *)image;
+ (void) saveURL:(NSString *)url;
+ (void) loadURL;

// Adapter event methods
+ (void) addObserver:(id)notificationObserver selector:(SEL)notificationSelector name:(NSString*)notificationName;
+ (void) removeObserver:(id)notificationObserver name:(NSString *)notificationName;


@end
