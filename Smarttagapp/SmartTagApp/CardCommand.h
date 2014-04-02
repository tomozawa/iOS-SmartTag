//
//  CardCommand.h
//  SmartTagApp
//

#import <Foundation/Foundation.h>
#import "SmarttagData.h"

//スマートタグのコマンドのヘッダー
#define S_HEADER_WWE   0x08 // データ書き込み
#define S_HEADER_WWER  0x09 // データ書き込み応答
#define S_HEADER_RWE   0x06 // データ読み出し
#define S_HEADER_RWER  0x07 // データ読み出し応答

//スマートタグのコマンド
#define S_CMD_CHECK_STATUS    0xD0 // ステータス確認
#define S_CMD_SHOW_DISPLAY    0xA0 // 電子ペーパーディスプレイ表示
#define S_CMD_CLEAR_DISPLAY   0xA1 // 電子ペーパーディスプレイ表示クリア
#define S_CMD_SHOW_DISPLAY_2  0xA2 // 電子ペーパーディスプレイ表示
#define S_CMD_DATA_WRITE      0xB0 // データ書き込み
#define S_CMD_SAVE_LAYOUT     0xB2 // レイアウトデータ登録
#define S_CMD_DATA_READ       0xC0 // データ読み込み
#define S_CMD_SHOW_DEMO_START_POINT       0x30 // データ読み込み

@interface CardCommand : NSObject
{
    unsigned char _function;
    int _fSum;
    int _fNum;
    
    NSMutableData *_data;
    int _dataLength;
    NSMutableData *_parameterData;
    
}

@property (nonatomic, readonly) unsigned char function;
@property (nonatomic, readonly) int fSum;
@property (nonatomic, readonly) int fNum;
-(float) estimatedWWETime;
-(float) estimatedRWETime;

-(NSMutableData *) commandDataWithCommandCode:(unsigned char)commandCode
                                          seq:(int)seq;

-(id)initWithFunction:(unsigned char)function
                 fSum:(int)fSum
                 fNum:(int)fNum
                 data:(unsigned char *)data
           dataLength:(int)length
            parameter:(unsigned char *)parameter;

@end
