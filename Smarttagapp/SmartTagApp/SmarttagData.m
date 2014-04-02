//
//  SmarttagData.m
//  SmartTagApp
//
//  Created by arts on 2013/09/12.
//  Copyright (c) 2013年 arts. All rights reserved.
//

#import "SmarttagData.h"
#import "CardResponse.h"

@implementation SmarttagData

NSMutableData *__felicaIDmData;
NSMutableString *__felicaIDm;
BatteryStatus __battery;
unsigned char __version;
unsigned char __status;
SmartTagType __type;
BOOL __isSmarttag;

+(SmarttagData *) shared
{
    static SmarttagData *_data = nil;
    
    @synchronized (self){
        static dispatch_once_t pred;
        dispatch_once(&pred, ^{
            _data = [[SmarttagData alloc] init];
        });
    }
    
    return _data;
}


+(void) initializeData
{
    [[SmarttagData shared] _initializeData];
}

-(void) _initializeData
{
    __felicaIDm = [NSMutableString stringWithString:@""];
    __felicaIDmData = [NSMutableData data];
    __isSmarttag = NO;
    __type = TAGTYPE_OTHER;
}


+(void) setFelicaIDm:(unsigned char *)idm
{
    [[SmarttagData shared] _setFelicaIDm:idm];
}

-(void) _setFelicaIDm:(unsigned char *)idm
{
    __felicaIDmData = [NSMutableData data];
    [__felicaIDmData appendBytes:idm length:8];
    
    __felicaIDm = [NSMutableString stringWithString:@""];
    for (int i = 0; i < 8; i++)
    {
        [__felicaIDm appendString:[NSString stringWithFormat:@"%02X",idm[i]]];
    }

    
    //スマートタグのIDMパターンと照合
    __isSmarttag = (BOOL)[[[SmarttagData felicaIDm] substringToIndex:8] isEqualToString:SMARTTAG_IDM_PREFIX];
    
    //スマートタグの種類を判定
    if(__isSmarttag)
    {
        if([[[SmarttagData felicaIDm] substringToIndex:10] isEqualToString:SMARTTAG_20_IDM_PREFIX])
        {
            __type = TAGTYPE_20_INCH;
        }
        else if([[[SmarttagData felicaIDm] substringToIndex:10] isEqualToString:SMARTTAG_27_1_IDM_PREFIX] ||
                [[[SmarttagData felicaIDm] substringToIndex:10] isEqualToString:SMARTTAG_27_2_IDM_PREFIX])
        {
            __type = TAGTYPE_27_INCH;
        }
        else
        {
            __type = TAGTYPE_OTHER;
        }
    }
    else
    {
        __type = TAGTYPE_OTHER;
    }
}



+(NSMutableData *)felicaIDmData
{
    return [[SmarttagData shared] _felicaIDmData];
}

-(NSMutableData *)_felicaIDmData
{
    return __felicaIDmData;
}



+(NSMutableString *)felicaIDm
{
    return [[SmarttagData shared] _felicaIDm];
}

-(NSMutableString *)_felicaIDm
{
    return __felicaIDm;
}


+(BatteryStatus)battery
{
    return [[SmarttagData shared] _battery];
}

-(BatteryStatus)_battery
{
    return __battery;
}


+(unsigned char)version
{
    return [[SmarttagData shared] _version];
}

-(unsigned char)_version
{
    return __version;
}


+(SmartTagStatus)status
{
    return [[SmarttagData shared] _status];
}

-(SmartTagStatus)_status
{
    return __status;
}


+(void)setStatusWithResponse:(CardResponse *)response
{
    [[SmarttagData shared] setStatusWithResponse:response];
}

-(void)setStatusWithResponse:(CardResponse *)response
{
    const unsigned char *headerBlock = [response.headerBlock bytes];
    
    __status = headerBlock[3];
    __battery = (int)headerBlock[5];
    __version = headerBlock[15];
}


//IDmがスマートタグの物かをチェック
+(BOOL)isSmarttag
{
    return [[SmarttagData shared] _isSmarttag];
}

-(BOOL)_isSmarttag
{
    return __isSmarttag;
}


//スマートタグの種類
+(SmartTagType)type
{
    return [[SmarttagData shared] _type];
}

-(SmartTagType)_type
{
    return __type;
}



@end

