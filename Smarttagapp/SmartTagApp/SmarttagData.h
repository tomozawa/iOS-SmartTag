//
//  SmarttagData.h
//  SmartTagApp
//
//  Created by arts on 2013/09/12.
//  Copyright (c) 2013年 arts. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CardResponse.h"

/*** スマートタグのIDmのプレフィックス ***/

#define SMARTTAG_IDM_PREFIX       @"03FE001D"   // スマートタグ共通
#define SMARTTAG_20_IDM_PREFIX    @"03FE001D00" // 2インチ
#define SMARTTAG_27_1_IDM_PREFIX  @"03FE001D10" // 2.7インチ電池なし
#define SMARTTAG_27_2_IDM_PREFIX  @"03FE001D12" // 2.7インチ電池あり


typedef NS_ENUM(NSInteger, BatteryStatus) {
    BATTERY_HIGH   = 0, // 通常
    BATTERY_NORMAL = 1, // 通常
    BATTERY_LOW    = 2, // バッテリー交換時期
    BATTERY_EMPTY  = 3  // バッテリー交換必須
};

typedef NS_ENUM(NSInteger, SmartTagType) {
    TAGTYPE_20_INCH,
    TAGTYPE_27_INCH,
    TAGTYPE_OTHER
};

//スマートタグのステータス
typedef NS_ENUM(unsigned char, SmartTagStatus)
{
    STS_RESET                     =  0x00, // 初期状態 (RESET)
    STS_COMPLETE                  =  0xF0, // 処理完了
    STS_WAIT_COMMAND              =  0xF1, // コマンド受信待ち(Fnum≠Fsum)
    STS_IN_PROGRESS               =  0xF2, // 処理中
    STS_COMMAND_ADDRESS_ERROR     =  0xF3, // 受信コマンドエラー(Address 異常)
    STS_COMMAND_LENGTH_ERROR      =  0xF4, // 受信コマンドエラー(Length 異常)
    STS_SYSTEM_RESERVED           =  0xF5, // (システム予約)
    STS_COMMAND_SIZE_ERROR        =  0xF6, // 受信コマンドエラー(Size 異常)
    STS_UNDEFINED_FUNCTION_ERROR  =  0xF7, // 受信コマンドエラー(未定義 Func.No.)
    STS_PARAMETER_ERROR           =  0xF8, // パラメータエラー
    STS_FLASH_ROM_ERROR           =  0xFD, // Flash Rom 異常
    STS_DISPLAY_ERROR             =  0xFE, // 電子ペーパーディスプレイ異常
    STS_DATA_ERROR                =  0xFF, // FeliCa 受信データエラー
};




@interface SmarttagData : NSObject

+(SmarttagData *) shared;

+(void)initializeData;
+(void)setStatusWithResponse:(CardResponse *)response;
+(void)setFelicaIDm:(unsigned char *)idm;
+(NSMutableData *)felicaIDmData;
+(NSMutableString *)felicaIDm;
+(BatteryStatus)battery;
+(unsigned char)version;
+(BOOL)isSmarttag;
+(SmartTagType)type;
+(SmartTagStatus)status;
@end
