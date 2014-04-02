
//
//  Adapter.m
//  SmartTagApp
//

#import "Adapter.h"
#import "Port110.h"
#import "CardCommand.h"
#import "SmarttagData.h"

@implementation Adapter


const unsigned char ZERO = 0x00; //

//スマートタグのタッチを検出してから次のポーリングを行うまでの間隔（秒）
const float S_POLLING_INTERVAL = 0.3f;

//レスポンスがエラーだった場合にスマートタグへコマンドを再送するまでの時間(秒)
const float S_RETRY_WAIT = 0.05f;

//コマンドを送信してレスポンスがない場合にリトライを行うまでの間隔（秒）
const float S_RETRY_INTERVAL = 5.0f;

//スマートタグに保存するURLの文字数
const int S_URL_LENGTH = 32;
//const int S_URL_LENGTH = 128;

//リトライの最大回数
const int S_MAX_RETRY = 9;

//ポーリングタイマ
NSTimer *pollingTimer;
//ポーリングコマンド
NSMutableData *pollingCommand;

//リトライ用タイマ
NSTimer *retryTimer;

//最終バイトの欠落対策用　強制終了タイマ
NSTimer *terminateTimer;


//ポーリング中かどうか
bool isPolling;

//キャンセル中かどうか
bool isCanceling;

//受信済みレスポンスデータ
NSMutableData *recievedRowData;

//受信済みレスポンスデータから取り出したメインのデータ
NSMutableData *recievedData;

//受信済みレスポンスのコマンドステータス
unsigned char responsStatus;

//受信済みレスポンスのエラーコード
unsigned char errorCode;

//カードからのレスポンスデータから取り出したFunctionData
NSMutableData *cardFunctionData;

//選択中のリーダー
int readerType;

//スマートタグWWEコマンドのキューリスト
NSMutableArray *wweCommandQueue;

//スマートタグRWEコマンドのキューリスト
NSMutableArray *rweCommandQueue;

//スマートタグコマンドのシーケンスNo. (0x01~0xff, 0x00はステータス確認に使用)
int smartTagCommandSequence;

//スマートタグからのレスポンスに含まれるブロック数
int numSmartTagCommandResponseBlock;

//処理中のカードコマンド
CardCommand *processingCommand;

//直近のカードコマンドのレスポンス
CardResponse *recentCardResponse;

//リトライ回数
int numRetry;

//直前のスマートタグIDm
NSString *tmpIDm;

//スマートタグのステータスチェック用コマンド
CardCommand *checkStatusCommand;

//最初に0x00を送るかどうか
bool zeroPaddingEnable;


#pragma mark -
#pragma mark - Singleton


+ (Adapter *) shared
{
    static Adapter *_adapter = nil;
    
    @synchronized (self){
        static dispatch_once_t pred;
        dispatch_once(&pred, ^{
            _adapter = [[Adapter alloc] init];
        });
    }
    
    return _adapter;
}



#pragma mark -
#pragma mark - Adapter control public methods


+ (void) initializeAdapter
{
    [[Adapter shared] _initializeAdapter];
}

+ (void) finalizeAdapter
{
    [[Adapter shared] _finalizeAdapter];
}

+(void) findPort110
{
    [[Adapter shared] _findPort110];
}

+ (void) setReaderDevice:(int)type
{
    [[Adapter shared] _setReaderDevice:type];
}




#pragma mark -
#pragma mark - Adapter RFIDReader public methods


+ (void) startPolling
{
    [[Adapter shared] _startPolling];
}

+ (void) stopPolling
{
    [[Adapter shared] _stopPolling];
}

+ (void) showDemo:(int)layout
{
    [[Adapter shared] _showDemo:(int)layout];
}

+ (void) clearDisplay
{
    [[Adapter shared] _clearDisplay];
}

+ (void) showLayout:(int)layout
{
    [[Adapter shared] _showLayout:layout];
}

+ (void) saveScreen:(int)page
{
    [[Adapter shared] _saveScreen:page];
}

+ (void) showImage:(UIImage *)image
{
    [[Adapter shared] _showImage:image];
}

+ (void) saveURL:(NSString *)url
{
    [[Adapter shared] _saveURL:url];
}

+ (void) loadURL
{
    [[Adapter shared] _loadURL];
}

+ (unsigned char) getResponsStatus
{
    return [[Adapter shared] _getResponsStatus];
}



#pragma mark -
#pragma mark - Adapter UART public methods


+ (NSMutableData *) getRecievedData
{
    return [[Adapter shared] _getRecievedData];
}


#pragma mark -
#pragma mark - Adapter public event methods


+ (void) addObserver:(id)notificationObserver selector:(SEL)notificationSelector name:(NSString*)notificationName
{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:notificationObserver selector:notificationSelector name:notificationName object:nil];
}

+ (void) removeObserver:(id)notificationObserver name:(NSString*)notificationName
{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:notificationObserver name:notificationName object:nil];
}



#pragma mark -
#pragma mark - Adapter private event methods


- (void) postNotification:(NSString*)notificationName
{
    NSNotification *n = [NSNotification notificationWithName:notificationName object:self];
    [[NSNotificationCenter defaultCenter] postNotification:n];
}

- (void) postNotification:(NSString*)notificationName userInfo:(NSDictionary *)dic
{
    NSNotification *n = [NSNotification notificationWithName:notificationName object:self userInfo:dic];
    [[NSNotificationCenter defaultCenter] postNotification:n];
}



#pragma mark -
#pragma mark - Adapter control private methods


- (void) _initializeAdapter
{
    {
        NSLog(@"Initialize Adapter");
        
        //初期化
        [Port110 initialize];
        [SmarttagData initializeData];
        wweCommandQueue = [NSMutableArray arrayWithCapacity:0];
        rweCommandQueue = [NSMutableArray arrayWithCapacity:0];
        zeroPaddingEnable = YES;
        isPolling = NO;
        isCanceling = NO;
        smartTagCommandSequence = 1;
        tmpIDm = @"";
        checkStatusCommand = [[CardCommand alloc] initWithFunction:S_CMD_CHECK_STATUS
                                                                           fSum:1
                                                                           fNum:1
                                                                           data:nil
                                                                     dataLength:0
                                                                      parameter:nil];
        
    }
}

- (void) _finalizeAdapter
{
    
    [Port110 removeObserver:self];
}



#pragma mark -
#pragma mark - Adapter Poer110 private methods


//前回使用したPort110に自動接続。見つからない場合は新規接続を探す
-(void)_findPort110
{
    [Port110 addObserver:self selector:@selector(_port110IsReady) name:PORT110_EVENT_CONNECTED];
    [Port110 addObserver:self selector:@selector(_port110IsNotFound) name:PORT110_EVENT_PERIPHERAL_NOT_FOUND];
    
    [self _initDeviceName];
    NSString *recentDeviceName = [self _loadDeviceName];
    
    if([recentDeviceName isEqual: @"undefined"])
    {
        [SVProgressHUD showWithStatus:@"Searching for scanner" maskType:SVProgressHUDMaskTypeClear];
        NSLog(@"Try to Find New Konashi");
        [Port110 find];
    }
    else
    {
        [SVProgressHUD showWithStatus:@"Pairing with scanner" maskType:SVProgressHUDMaskTypeClear];
        NSLog(@"Try to Find Konashi with Name : %@", recentDeviceName);
        [Port110 findWithName:recentDeviceName];
    }
}

//最近接続したKonashiの名前データを初期化（既存のデータがある場合は上書きされない）
- (void)_initDeviceName
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *md = [NSMutableDictionary dictionary];
    [md setObject:@"undefined" forKey:@"device"];
    [ud registerDefaults:md];
}

//最近接続したKonashiの名前データを保存
- (NSString *)_loadDeviceName
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    return [ud stringForKey:@"device"];
}

//最近接続したKonashiの名前データを取得
- (void)_saveDeviceName:(NSString*)deviceName
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setObject:deviceName forKey:@"device"];
    [ud synchronize];
}

//名前指定でPort110Konashiが見つからなかった場合
- (void)_port110IsNotFound
{
    [SVProgressHUD showWithStatus:@"Searching for scanner" maskType:SVProgressHUDMaskTypeClear];
    NSLog(@"Try to Find New Port110");
    [Port110 findWithName:@""];
}

//Port110への接続完了
-(void)_port110IsReady
{
    //接続したPort110の名前を保存
    [self _saveDeviceName:[Port110 peripheralName]];

   	[SVProgressHUD dismiss];

    [Port110 removeObserver:self];
    
    NSLog(@"Port110 is Ready");
    
    [self postNotification:ADAPTER_EVENT_READY];
}




- (unsigned char) _getResponsStatus
{
    return responsStatus;
}



//RFIDリーダーとバーコードリーダーの切り替え
- (void)_setReaderDevice:(int)type
{

}








#pragma mark -
#pragma mark - Adapter RFIDReader private methods
#pragma mark -


#pragma mark Adapter RFIDReader control


//コマンドキューへのコマンド追加
-(void)_addCommandToQueue:(CardCommand *)command code:(unsigned char)code
{
    switch (code)
    {
        case S_HEADER_WWE:
            [wweCommandQueue addObject:command];
            break;
        case S_HEADER_RWE:
            [rweCommandQueue addObject:command];
            break;
    }

}

//コマンドキューからの先頭のコマンドを取得
-(CardCommand *)_getCommandFromQueueOfCode:(unsigned char)code
{
    switch (code)
    {
        case S_HEADER_WWE:
            if ([wweCommandQueue count] == 0)
            {
                return nil;
            }
            else
            {
                CardCommand *command = (CardCommand *)[wweCommandQueue objectAtIndex:0];
                [wweCommandQueue removeObjectAtIndex:0];
                return command;
            }
            break;
            
        case S_HEADER_RWE:
            if ([rweCommandQueue count] == 0)
            {
                return nil;
            }
            else
            {
                CardCommand *command = (CardCommand *)[rweCommandQueue objectAtIndex:0];
                [rweCommandQueue removeObjectAtIndex:0];
                return command;
            }
            break;
    }
    return nil;
}

//コマンドキューのリセット
-(void)_resetCommandQue
{
    [wweCommandQueue removeAllObjects];
    [rweCommandQueue removeAllObjects];
}

//次のコマンドを送信
- (void) _sendNextQueueCommandsOfCode:(unsigned char)code
{
    CardCommand *command = [self _getCommandFromQueueOfCode:code];
    
    switch (code)
    {
        case S_HEADER_WWE:
            [SVProgressHUD setStatus:[NSString stringWithFormat:@"%@\n(%d/%d)\n%@", PROGRESS_TEXT_SEND_DATA, [command fNum], [command fSum], PROGRESS_TEXT_TAP_TO_CANCEL ]];
            [self _sendWWE:command];
            break;
            
        case S_HEADER_RWE:
            [SVProgressHUD setStatus:[NSString stringWithFormat:@"%@\n(%d/%d)\n%@", PROGRESS_TEXT_READ_DATA, [command fNum], [command fSum], PROGRESS_TEXT_TAP_TO_CANCEL ]];
            [self _sendRWE:command];
            break;
    }
}

//WWE送信
- (void)_sendWWE:(CardCommand *)command
{
    //キャンセル
    if(isCanceling)
    {
        [self _commandCancelComplete];
        return;
    }
    
    if(command)
    {
        numRetry = 0;
        processingCommand = command;
    }
    
    NSLog(@"  [SEND WWE] Function:%02X(%d/%d)", processingCommand.function, processingCommand.fNum, processingCommand.fSum);
    
    int seq = (processingCommand.function == S_CMD_CHECK_STATUS)? 0 : [self _nextSmartTagCommandSequence];
    NSMutableData *cardCommand = [processingCommand commandDataWithCommandCode:S_HEADER_WWE seq:seq];
    
    //レスポンスがない場合のリトライ用タイマー
    retryTimer = [NSTimer scheduledTimerWithTimeInterval:S_RETRY_INTERVAL + [processingCommand estimatedWWETime] target:self selector:@selector(_timeoverSendWWE) userInfo:nil repeats:NO];
    
    [Port110 addObserver:self selector:@selector(_recieveWWERComplete) name:PORT110_EVENT_RECEIVE_WWER_COMPLETE];
    
    NSMutableString *log = [NSMutableString stringWithString:@""];
    unsigned char *commandCharsForLog = (unsigned char *)[cardCommand bytes];
    
    for (int i = 0; i < [cardCommand length]; i++)
    {
        unsigned char ch = commandCharsForLog[i];
        
        [log appendString:[NSString stringWithFormat:@"%02X ", (int)ch]];
    }
    NSLog(@"    Tx : %@", log);
    [Port110 write:cardCommand];
}

//WWE Resp.受信
- (void)_recieveWWERComplete
{
    [Adapter removeObserver:self name:PORT110_EVENT_RECEIVE_WWER_COMPLETE];
    if([retryTimer isValid]) [retryTimer invalidate];
    
    //キャンセル
    if(isCanceling)
    {
        [self _commandCancelComplete];
        return;
    }
    
    //エラーチェック
    if (errorCode == R_STS_TIME_OVR || errorCode == R_STS_CMD_ERR)
    {
        NSLog(@"  [ERROR WWER] Function:%02X(%d/%d)", processingCommand.function, processingCommand.fNum, processingCommand.fSum);
        [NSTimer scheduledTimerWithTimeInterval:S_RETRY_WAIT target:self selector:@selector(_retrySendWWE) userInfo:nil repeats:NO];
        return;
    }
    //受信成功
    NSLog(@"  [SUCCESS WWER] Function:%02X(%d/%d)", processingCommand.function, processingCommand.fNum, processingCommand.fSum);
    [self postNotification:ADAPTER_EVENT_RECIEVE_WWER_COMPLETE];
}

//WWE送信 タイムオーバー
-(void)_timeoverSendWWE
{
    [Adapter removeObserver:self name:PORT110_EVENT_RECEIVE_WWER_COMPLETE];
    if([retryTimer isValid]) [retryTimer invalidate];
    [self _retrySendWWE];
}

//WWE再送信
-(void)_retrySendWWE
{
    //キャンセル
    if(isCanceling)
    {
        [self _commandCancelComplete];
        return;
    }
    
    //受信データのリセット
    [self _resetResponseData];
    
    if(numRetry < S_MAX_RETRY)
    {
        //タイムオーバー時、コマンドエラー時はリトライ
        numRetry++;
        NSLog(@"  [RETRY WWE(%d/%d)] Function:%02X(%d/%d)", numRetry, S_MAX_RETRY, processingCommand.function, processingCommand.fNum, processingCommand.fSum);
        [self _sendWWE:nil];
    }
    //リトライ回数上限を超えた場合はエラー
    else
    {
        [self postNotification:ADAPTER_EVENT_RECIEVE_ERROR];
        [self _finishSendCardCommandFlow];
    }
}



//RWE送信
- (void)_sendRWE:(CardCommand *)command
{
    //キャンセル
    if(isCanceling)
    {
        [self _commandCancelComplete];
        return;
    }
    
    if(command)
    {
        processingCommand = command;
        numRetry = 0;
    }
    
    NSLog(@"  [SEND RWE] Function:%02X(%d/%d)", processingCommand.function, processingCommand.fNum, processingCommand.fSum);
    
    int block_number = (processingCommand.function == S_CMD_CHECK_STATUS)? 2 : 3;
    
    //レスポンスがない場合のリトライ用タイマー
    retryTimer = [NSTimer scheduledTimerWithTimeInterval:S_RETRY_INTERVAL + [processingCommand estimatedRWETime] target:self selector:@selector(_timeoverSendRWE) userInfo:nil repeats:NO];
    
    [Port110 addObserver:self selector:@selector(_recieveRWERComplete) name:PORT110_EVENT_SEND_RWE_COMPLETE];
    
    [Port110 read:block_number];
}

//-------------------------------------------------------------------//
//RWE Resp.受信
- (void)_recieveRWERComplete
//-------------------------------------------------------------------//
{
    [Adapter removeObserver:self name:PORT110_EVENT_SEND_RWE_COMPLETE];
    
    //強制終了タイマーが動いている場合はタイマー停止
    if([terminateTimer isValid]) [terminateTimer invalidate];

    //キャンセル
    if(isCanceling)
    {
        [self _commandCancelComplete];
        return;
    }
    
    recievedRowData = [Port110 getRecievedData];

    [Adapter removeObserver:self name:ADAPTER_EVENT_RECIEVE_DATA_COMPLETE];
    [retryTimer invalidate];
    
    //--ログの出力
    NSMutableString *log = [NSMutableString stringWithString:@""];
    const unsigned char *logdata = [recievedRowData bytes];
    for (int i=0; i<[recievedRowData length]; i++) {
        [log appendString:[NSString stringWithFormat:@"%02X ", logdata[i]]];
    }
    NSLog(@"    Rx : %@", log);
    //--

    recievedData = recievedRowData;

    //レスポンスデータの取得
    recentCardResponse = [[CardResponse alloc] initWithResponseData:[Adapter getRecievedData]];
    
    //エラーチェック
    if (errorCode == R_STS_TIME_OVR || errorCode == R_STS_CMD_ERR)
    {
        NSLog(@"  [ERROR RWER] Function:%02X(%d/%d)", processingCommand.function, processingCommand.fNum, processingCommand.fSum);
        [NSTimer scheduledTimerWithTimeInterval:S_RETRY_WAIT target:self selector:@selector(_retrySendRWE) userInfo:nil repeats:NO];
        return;
    }
    
    //受信成功
    NSLog(@"  [SUCCESS RWER] Function:%02X(%d/%d)", processingCommand.function, processingCommand.fNum, processingCommand.fSum);
    [self postNotification:ADAPTER_EVENT_RECIEVE_RWER_COMPLETE];
}

//-------------------------------------------------------------------//
//RWE送信 タイムオーバー
//-------------------------------------------------------------------//
-(void)_timeoverSendRWE
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_RECIEVE_DATA_COMPLETE];
    if([retryTimer isValid]) [retryTimer invalidate];
    [self _retrySendRWE];
}

//-------------------------------------------------------------------//
//RWE再送信
-(void)_retrySendRWE
//-------------------------------------------------------------------//
{
    //キャンセル
    if(isCanceling)
    {
        [self _commandCancelComplete];
        return;
    }
    
    //受信データのリセット
    [self _resetResponseData];
    
    if(numRetry < S_MAX_RETRY)
    {
        //タイムオーバー時、コマンドエラー時はリトライ
        numRetry++;
        NSLog(@"  [RETRY RWE(%d/%d)] Function:%02X(%d/%d)", numRetry, S_MAX_RETRY, processingCommand.function, processingCommand.fNum, processingCommand.fSum);
        [self _sendRWE:nil];
    }
    //リトライ回数上限を超えた場合はエラー
    else
    {
        [self postNotification:ADAPTER_EVENT_RECIEVE_ERROR];
        [self _finishSendCardCommandFlow];
    }
}



//スマートタグコマンドのシーケンスNo.
- (int) _nextSmartTagCommandSequence
{
    int seq = smartTagCommandSequence;
    smartTagCommandSequence = (smartTagCommandSequence % 255) + 1; //1-255
    return seq;
}


#pragma mark Adapter RFIDReader Send Command


//カードコマンドの送信フローを開始(コマンドキューが空の場合はポーリング＆ステータスチェックまで)
- (void) _startSendCardCommandFlow
{
    
    //エラーの監視
    [Adapter addObserver:self selector:@selector(recieveSmartTagError:) name:ADAPTER_EVENT_RECIEVE_ERROR];
    [Adapter addObserver:self selector:@selector(recieveSmartTagError:) name:ADAPTER_EVENT_SMARTTAG_IS_RELEASED];
    [Adapter addObserver:self selector:@selector(recieveSmartTagError:) name:ADAPTER_EVENT_SMARTTAG_IS_LOW_BATTERY];
    [Adapter addObserver:self selector:@selector(recieveSmartTagError:) name:ADAPTER_EVENT_FELICA_IS_NOT_SMARTTAG];
    
    //画面タップでキャンセル
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_commandCancel:) name:SVProgressHUDDidReceiveTouchEventNotification object:nil];
    
    //ステータスチェック
    [SVProgressHUD setStatus:PROGRESS_TEXT_CHECK_STATUS];
    [Adapter addObserver:self selector:@selector(_statusIsCompleteAtStatusCheck) name:ADAPTER_EVENT_CHECK_STATUS_COMPLETE];
    [self _checkStatus];
}

-(void)_statusIsCompleteAtStatusCheck
{
    //キャンセル
    if(isCanceling)
    {
        [self _commandCancelComplete];
        return;
    }
    
    [Adapter removeObserver:self name:ADAPTER_EVENT_CHECK_STATUS_COMPLETE];
    
    if([wweCommandQueue count] > 0)
    {
        [SVProgressHUD setStatus:[NSString stringWithFormat:@"%@\n%@", PROGRESS_TEXT_SEND_DATA, PROGRESS_TEXT_TAP_TO_CANCEL ]];
        [Adapter addObserver:self selector:@selector(_statusCheckWWEComplete) name:ADAPTER_EVENT_RECIEVE_WWER_COMPLETE];
        [self _sendNextQueueCommandsOfCode:S_HEADER_WWE];
    }
    else
    {
        [self _statusCheckWWEComplete];
    }
    
}

-(void) _statusCheckWWEComplete
{
    //キャンセル
    if(isCanceling)
    {
        [self _commandCancelComplete];
        return;
    }
    
    if([wweCommandQueue count] > 0)
    {
        [self _sendNextQueueCommandsOfCode:S_HEADER_WWE];
    }
    else
    {
        [Adapter removeObserver:self name:ADAPTER_EVENT_RECIEVE_WWER_COMPLETE];
        
        if([rweCommandQueue count] > 0)
        {
            [SVProgressHUD setStatus:[NSString stringWithFormat:@"%@\n%@", PROGRESS_TEXT_READ_DATA, PROGRESS_TEXT_TAP_TO_CANCEL ]];
            [Adapter addObserver:self selector:@selector(_sendRWEComplete) name:ADAPTER_EVENT_RECIEVE_RWER_COMPLETE];
            [self _sendNextQueueCommandsOfCode:S_HEADER_RWE];
        }
        else
        {
            [self _sendRWEComplete];
        }
        
    }
}

-(void)_sendRWEComplete
{
    //キャンセル
    if(isCanceling)
    {
        [self _commandCancelComplete];
        return;
    }
    
    if([rweCommandQueue count] > 0)
    {
        [self _sendNextQueueCommandsOfCode:S_HEADER_RWE];
    }
    else
    {
        [Adapter removeObserver:self name:ADAPTER_EVENT_RECIEVE_RWER_COMPLETE];
        
        [self _finishSendCardCommandFlow];
        [self postNotification:ADAPTER_EVENT_ALL_CARD_COMMAND_COMPLETE];
        /*
        //最終チェック
        [Adapter addObserver:self selector:@selector(_statusIsCompleteAtSendRWE) name:ADAPTER_EVENT_CHECK_STATUS_COMPLETE];
        [SVProgressHUD setStatus:PROGRESS_TEXT_CHECK_STATUS];
        [self _checkStatus];
        */
    }
}
//最終チェック完了
-(void)_statusIsCompleteAtSendRWE
{
    //キャンセル
    if(isCanceling)
    {
        [self _commandCancelComplete];
        return;
    }
    
    [Adapter removeObserver:self name:ADAPTER_EVENT_CHECK_STATUS_COMPLETE];
    [self _finishSendCardCommandFlow];
    [self postNotification:ADAPTER_EVENT_ALL_CARD_COMMAND_COMPLETE];
}

//カードコマンドの送信フローを終了
- (void) _finishSendCardCommandFlow
{
     [[NSNotificationCenter defaultCenter] removeObserver:self name:SVProgressHUDDidReceiveTouchEventNotification object:nil];
    
    [Adapter removeObserver:self name:ADAPTER_EVENT_RECIEVE_ERROR];
    [Adapter removeObserver:self name:ADAPTER_EVENT_SMARTTAG_IS_RELEASED];
    [Adapter removeObserver:self name:ADAPTER_EVENT_SMARTTAG_IS_LOW_BATTERY];
    [Adapter removeObserver:self name:ADAPTER_EVENT_FELICA_IS_NOT_SMARTTAG];
    
    [self _resetCommandQue];
}



//コマンドキャンセル
-(void)_commandCancel:(NSNotification *)notification
{
    [SVProgressHUD setStatus:PROGRESS_TEXT_CANCELING];
    isCanceling = YES;
}
-(void)_commandCancelComplete
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_RECIEVE_RWER_COMPLETE];
    [Adapter removeObserver:self name:ADAPTER_EVENT_CHECK_STATUS_COMPLETE];
    [Adapter removeObserver:self name:ADAPTER_EVENT_RECIEVE_WWER_COMPLETE];
    isCanceling = NO;
   
    [self _finishSendCardCommandFlow];
    
    NSDictionary *dic = [NSDictionary dictionaryWithObject:@"" forKey:@"ERROR"];
    [self postNotification:ADAPTER_EVENT_ERROR userInfo:dic];
}

//コマンド実行中にエラー発生
- (void)recieveSmartTagError:(NSNotification *)notification
{
    NSString *errorString;
    
    if([notification.name isEqual:ADAPTER_EVENT_RECIEVE_ERROR])
    {
        errorString = @"通信エラーが発生しました";
    }
    if([notification.name isEqual:ADAPTER_EVENT_SMARTTAG_IS_RELEASED])
    {
        errorString = @"スマートタグが見つかりません";
    }
    if([notification.name isEqual:ADAPTER_EVENT_SMARTTAG_IS_LOW_BATTERY])
    {
        errorString = @"スマートタグのバッテリー残量が少なくなっています";
    }
    if([notification.name isEqual:ADAPTER_EVENT_FELICA_IS_NOT_SMARTTAG])
    {
        errorString = @"スマートタグ以外のFelicaです";
    }
    
    NSDictionary *dic = [NSDictionary dictionaryWithObject:errorString forKey:@"ERROR"];
    [self postNotification:ADAPTER_EVENT_ERROR userInfo:dic];
}









#pragma mark Adapter RFIDReader Command Polling


//ポーリングの開始
-(void)_startPolling
{
    if(isPolling) return;
    isPolling = YES;
    
    NSLog(@"[START] Polling.");

//## SDKのポーリングメソッド使用
//    unsigned char data[5] = { 0x00, 0xFE, 0xE1, 0x00, 0x00 };
//    pollingCommand = [NSMutableData data];
//    [pollingCommand appendBytes:data length:5];
    
    pollingTimer = [NSTimer scheduledTimerWithTimeInterval:S_POLLING_INTERVAL target:self selector:@selector(_polling) userInfo:nil repeats:YES];
    [self _polling];
}
//ポーリングの停止
-(void)_stopPolling
{
    if(!isPolling) return;
    isPolling = NO;
    
    NSLog(@"[STOP] Polling.");
    [Adapter removeObserver:self name:ADAPTER_EVENT_RECIEVE_DATA_COMPLETE];
    if([pollingTimer isValid]) [pollingTimer invalidate];
}
//ポーリングコマンドの送信
- (void) _polling
{
    NSLog(@"  [POLLING]");

    [Port110 addObserver:self selector:@selector(_pollingRecieved) name:PORT110_EVENT_POLLING_COMPLETE];

    [Port110 polling];
}
//ポーリングレスポンスの受信
- (void) _pollingRecieved
{
    [Port110 removeObserver:self];

    //スマートタグ検出
    responsStatus = [Port110 getResponsStatus];
    if(responsStatus == R_CMD_RESPONSE_DATA)
    {
        NSLog(@"  [RECV POLLING RESPONSE SUCCESS]");
        unsigned char *data = (unsigned char *)[[Port110 getRecievedData] bytes];
        unsigned char idm[8];
        //IDmの取得
        for (int i = 0; i < 8; i++) idm[i] = data[i+0];
        [SmarttagData setFelicaIDm:idm];
        
        
        if(![tmpIDm isEqualToString:[SmarttagData felicaIDm]])
        {
            NSLog(@"****************************");
            NSLog(@"Find New SmartTag");
            NSLog(@"IDm : %@", [SmarttagData felicaIDm]);
            NSLog(@"****************************");
            
            tmpIDm = [SmarttagData felicaIDm];
            //スマートタグがタッチされた
            [self postNotification:ADAPTER_EVENT_SMARTTAG_IS_TOUCHED];
        }
        //[self _checkStatus];
    }
    //エラーor未検出
    else if(responsStatus == R_CMD_RESPONSE_ERROR)
    {
        errorCode = [Port110 getErrorCode];
        
        //タイムオーバー時はタグが見つからないと見なす
        if(errorCode == R_STS_TIME_OVR)
        {
            NSLog(@"  [RECV POLLING TIMEOUT]");
            [SmarttagData initializeData];
            
            if(![tmpIDm isEqualToString:@""])
            {
                NSLog(@"****************************");
                NSLog(@"SmartTag is Released");
                NSLog(@"****************************");
                //スマートタグがリリースされた
                [self postNotification:ADAPTER_EVENT_SMARTTAG_IS_RELEASED];
                tmpIDm = @"";
            }
        }
        //コマンド送信エラー時以外の場合はエラーを出して終了
        else if(errorCode != R_STS_CMD_ERR)
        {
            NSLog(@"  [RECV POLLING RESPONSE ERROR]");
            [self postNotification:ADAPTER_EVENT_RECIEVE_ERROR];
            [self _finishSendCardCommandFlow];
        }
        //コマンド送信エラーのときはリトライ
    }
}



#pragma mark Adapter RFIDReader Command CheckStatus
//**********************
//スマートタグのステータスチェック
//**********************
- (void) _checkStatus
{
    NSLog(@"[START] Check Smarttag Status");
    
    [Adapter addObserver:self selector:@selector(_checkStatusRecieveWWER) name:ADAPTER_EVENT_RECIEVE_WWER_COMPLETE];
    [self _sendWWE:checkStatusCommand];
}
-(void)_checkStatusRecieveWWER
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_RECIEVE_WWER_COMPLETE];
    
    [Adapter addObserver:self selector:@selector(_checkStatusComplete) name:ADAPTER_EVENT_RECIEVE_RWER_COMPLETE];
    [self _sendRWE:checkStatusCommand];
}
//完了
- (void) _checkStatusComplete
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_RECIEVE_RWER_COMPLETE];
    
    [SmarttagData setStatusWithResponse:recentCardResponse];
    
    //バッテリーのチェック
    if ([SmarttagData battery] == BATTERY_EMPTY || [SmarttagData battery] == BATTERY_LOW)
    {
        //交換が必要な場合はエラー
        [self postNotification:ADAPTER_EVENT_SMARTTAG_IS_LOW_BATTERY];
        [self _finishSendCardCommandFlow];
    }
    //バッテリーに問題がない場合はスマートタグの状態チェック
    else
    {
        NSLog(@"    ****************************");
        NSLog(@"    * SmartTag Status");
        NSLog(@"    * IDm : %@", [SmarttagData felicaIDm]);
        NSLog(@"    * Battery : %02X", [SmarttagData battery]);
        NSLog(@"    * Version : %02X", [SmarttagData version]);
        switch ([SmarttagData status])
        {
            case STS_COMPLETE:
                //完了
                NSLog(@"    * Status : [ COMPLETE ]");
                NSLog(@"    ****************************");
                [self postNotification:ADAPTER_EVENT_CHECK_STATUS_COMPLETE];
                break;
                
            case STS_WAIT_COMMAND:
                //コマンド待ちの場合もそのまま処理を継続
                NSLog(@"    * Status : [ WAIT COMMAND ]");
                NSLog(@"    ****************************");
                [self postNotification:ADAPTER_EVENT_CHECK_STATUS_COMPLETE];
                break;
                
            case STS_IN_PROGRESS:
                //処理中の場合は再チェック
                NSLog(@"    * Status : [ IN PROGRESS ]");
                NSLog(@"    ****************************");
                [NSTimer scheduledTimerWithTimeInterval:S_RETRY_WAIT target:self selector:@selector(_checkStatus) userInfo:nil repeats:NO];
                break;
                
            default:
                //処理中以外で処理が完了しなかった場合はエラー
                NSLog(@"    * Status : %02X[ ERROR ]", [SmarttagData status]);
                NSLog(@"    ****************************");
                [self postNotification:ADAPTER_EVENT_RECIEVE_ERROR];
                [self _finishSendCardCommandFlow];
                break;
        }
    }
}

#pragma mark Adapter RFIDReader Command SaveScreen
//**********************
//スマートタグに表示されているデモ画像を表示
//**********************
- (void) _showDemo:(int)layout
{
    [self _resetCommandQue];
    
    unsigned char demoImageNumber =S_CMD_SHOW_DEMO_START_POINT + 0x01*layout;
    
    CardCommand *cardCommand = [[CardCommand alloc] initWithFunction:demoImageNumber
                                                                fSum:1
                                                                fNum:1
                                                                data:nil
                                                          dataLength:0
                                                           parameter:nil];
    [self _addCommandToQueue:cardCommand code:S_HEADER_WWE];
    [Adapter addObserver:self selector:@selector(_showDemoComplete) name:ADAPTER_EVENT_ALL_CARD_COMMAND_COMPLETE];
    [self _startSendCardCommandFlow];
}

- (void)_showDemoComplete
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_ALL_CARD_COMMAND_COMPLETE];
    [self postNotification:ADAPTER_EVENT_SHOW_DEMO_COMPLETE ];
}

#pragma mark Adapter RFIDReader Command ClearDisplay
//**********************
//ディスプレイクリア
//**********************
- (void) _clearDisplay
{
    [self _resetCommandQue];
    CardCommand *cardCommand = [[CardCommand alloc] initWithFunction:S_CMD_CLEAR_DISPLAY
                                                               fSum:1
                                                               fNum:1
                                                               data:nil
                                                         dataLength:0
                                                          parameter:nil];
    [self _addCommandToQueue:cardCommand code:S_HEADER_WWE];
    [Adapter addObserver:self selector:@selector(_clearDisplayComplete) name:ADAPTER_EVENT_ALL_CARD_COMMAND_COMPLETE];
    [self _startSendCardCommandFlow];
}

- (void)_clearDisplayComplete
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_ALL_CARD_COMMAND_COMPLETE];
    [self postNotification:ADAPTER_EVENT_CLEAR_DISPLAY_COMPLETE];
}


#pragma mark Adapter RFIDReader Command LoadURL
//**********************
//タグに保存したURLを読み出し
//**********************
- (void) _loadURL
{
    [self _resetCommandQue];
    unsigned char parameter[8] = { 0x00, 0x00, 0x00, S_URL_LENGTH, 0x00, 0x00, 0x00, 0x00 };
    
    CardCommand *cardCommand = [[CardCommand alloc] initWithFunction:S_CMD_DATA_READ
                                                        fSum:1
                                                        fNum:1
                                                        data:nil
                                                  dataLength:0
                                                   parameter:parameter];
    [self _addCommandToQueue:cardCommand code:S_HEADER_WWE];
    [self _addCommandToQueue:cardCommand code:S_HEADER_RWE];
    [Adapter addObserver:self selector:@selector(_loadURLComplete) name:ADAPTER_EVENT_ALL_CARD_COMMAND_COMPLETE];
    [self _startSendCardCommandFlow];
}
//完了
- (void) _loadURLComplete
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_ALL_CARD_COMMAND_COMPLETE];
    
    unsigned char *data = (unsigned char *)[[Adapter getRecievedData] bytes];
    NSMutableString *url = [NSMutableString stringWithString:@""];
    for (int i = 0; i < S_URL_LENGTH; i++)
    {
        unsigned char c = data[i+16];
        //0x00が出てきたらURLの終端に到達したのでforから抜ける
        if(c == 0x00) break;
        [url appendString:[NSString stringWithFormat:@"%c", c]];
    }
    
    //url = [NSString stringWithFormat:@"%@%@", @"http://", url];
    NSDictionary *dic = [NSDictionary dictionaryWithObject:url forKey:@"URL"];
    [self postNotification:ADAPTER_EVENT_LOAD_URL_COMPLETE userInfo:dic];
}


#pragma mark Adapter RFIDReader Command SaveURL
//**********************
//URLをタグに保存
//**********************
- (void) _saveURL:(NSString *)url
{
    //url = [url stringByReplacingOccurrencesOfString:@"http://" withString:@""];
    [self _resetCommandQue];
    
    unsigned char parameter[8] = { 0x00, 0x00, 0x00, S_URL_LENGTH, 0x00, 0x00, 0x00, 0x00 };
    unsigned char data[S_URL_LENGTH];
    for (int i = 0; i < S_URL_LENGTH; i++)
    {
        if(i < url.length)
        {
            data[i] = [url characterAtIndex:i];
        }
        else
        {
            data[i] = 0x00;
        }
    }
    
    CardCommand *cardCommand = [[CardCommand alloc] initWithFunction:S_CMD_DATA_WRITE
                                                        fSum:1
                                                        fNum:1
                                                        data:data
                                                  dataLength:S_URL_LENGTH
                                                   parameter:parameter];
    [self _addCommandToQueue:cardCommand code:S_HEADER_WWE];
    [Adapter addObserver:self selector:@selector(_saveURLComplete) name:ADAPTER_EVENT_ALL_CARD_COMMAND_COMPLETE];
    [self _startSendCardCommandFlow];
}
//完了
- (void) _saveURLComplete
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_ALL_CARD_COMMAND_COMPLETE];
    [self postNotification:ADAPTER_EVENT_SAVE_URL_COMPLETE];
}


#pragma mark Adapter RFIDReader Command ShowLayout
//**********************
//スマートタグに保存されている画像をディスプレイに表示
//**********************
- (void) _showLayout:(int)layout
{
    [self _resetCommandQue];
    
    NSLog(@"Show Layout %d", layout);
    
    unsigned char parameter[8] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x01 };
    
    parameter[6] = layout;
    
    CardCommand *cardCommand = [[CardCommand alloc] initWithFunction:S_CMD_SHOW_DISPLAY
                                                        fSum:1
                                                        fNum:1
                                                        data:nil
                                                  dataLength:0
                                                   parameter:parameter];
    [self _addCommandToQueue:cardCommand code:S_HEADER_WWE];
    [Adapter addObserver:self selector:@selector(_showLayoutComplete) name:ADAPTER_EVENT_ALL_CARD_COMMAND_COMPLETE];
    [self _startSendCardCommandFlow];
}
//完了
- (void) _showLayoutComplete
{
    NSLog(@"Show Layout Complete");
    [Adapter removeObserver:self name:ADAPTER_EVENT_ALL_CARD_COMMAND_COMPLETE];
    [self postNotification:ADAPTER_EVENT_SHOW_LAYOUT_COMPLETE];
}


#pragma mark Adapter RFIDReader Command SaveScreen
//**********************
//スマートタグに表示されているデータを保存
//**********************
- (void) _saveScreen:(int)layout
{
    [self _resetCommandQue];
    
    unsigned char parameter[8] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    
    parameter[0] = layout;
    
    CardCommand *cardCommand = [[CardCommand alloc] initWithFunction:S_CMD_SAVE_LAYOUT
                                                        fSum:1
                                                        fNum:1
                                                        data:nil
                                                  dataLength:0
                                                   parameter:parameter];
    [self _addCommandToQueue:cardCommand code:S_HEADER_WWE];
    [Adapter addObserver:self selector:@selector(_saveScreenComplete) name:ADAPTER_EVENT_ALL_CARD_COMMAND_COMPLETE];
    [self _startSendCardCommandFlow];
}
//完了
- (void) _saveScreenComplete
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_ALL_CARD_COMMAND_COMPLETE];
    [self postNotification:ADAPTER_EVENT_SAVE_LAYOUT_COMPLETE];
}


#pragma mark Adapter RFIDReader Command ShowImage
//**********************
//スマートタグに画像を表示
//**********************
- (void) _showImage:(UIImage *)image
{
    [self _resetCommandQue];
    
    CGImageRef inputImageRef = [image CGImage];
    CFDataRef inputData = CGDataProviderCopyData(CGImageGetDataProvider(inputImageRef));
    unsigned char *pixelData = (unsigned char *) CFDataGetBytePtr(inputData);
    int pixelDataLength = CFDataGetLength(inputData);
    
    unsigned char parameter[8] = { 0x01, 0x01, 0x00, 0x00, 0x19, 0x00, 0x00, 0x03 };
    int smartTagfSum =14;
    if([SmarttagData type]==TAGTYPE_27_INCH){
        parameter[4] = 0x21;
        smartTagfSum =33;
    }
    
    for(int i = 0; i < smartTagfSum; i++)
    {
        unsigned char data[176];
        for(int j = 0; j < 176; j++)
        {
            unsigned char dot = 0x00;
            
            for(int k = 0; k < 8; k++)
            {
                int pixelIndex = (i * 176 * 8 + j * 8 + k) * 4;
                
                if(pixelIndex < pixelDataLength)
                {
                    unsigned char col = *(pixelData + pixelIndex + 1);
                
                    if((int)col < 128)
                    {
                        dot |= 1 << (7 - k);
                    }
                }
            }
            data[j] = dot;
        }
        
        CardCommand *command = [[CardCommand alloc] initWithFunction:S_CMD_SHOW_DISPLAY
                                                        fSum:smartTagfSum
                                                        fNum:i+1
                                                        data:data
                                                  dataLength:176
                                                   parameter:parameter];
        [self _addCommandToQueue:command code:S_HEADER_WWE];
         
    }
    CFRelease(inputData);
    /*
    for (int m=0; m<96; m++) {
        NSMutableString *log = [NSMutableString stringWithString:@""];
        for (int n=0; n<25; n++) {
            [log appendString:[NSString stringWithFormat:@"%02x", d[n + m*25]]];
        }
        NSLog(@"%d : %@", m, log);
    }
    */
    [Adapter addObserver:self selector:@selector(_showImageComplete) name:ADAPTER_EVENT_ALL_CARD_COMMAND_COMPLETE];
    [self _startSendCardCommandFlow];
}
//完了
- (void) _showImageComplete
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_ALL_CARD_COMMAND_COMPLETE];
    [self postNotification:ADAPTER_EVENT_SHOW_IMAGE_COMPLETE];
}



#pragma mark -
#pragma mark - Adapter Port110 private methods



//受信済みデータを参照
- (NSMutableData *) _getRecievedData
{
    return recievedData;
}

//受信済みデータのリセット
-(void)_resetResponseData
{
    recievedRowData = [NSMutableData data];
    responsStatus = ZERO;
    errorCode = ZERO;
}





@end
