//
//  CardCommand.m
//  SmartTagApp
//

#import "CardCommand.h"
#import "SmarttagData.h"

@implementation CardCommand

@synthesize function = _function;
@synthesize fSum = _fSum;
@synthesize fNum = _fNum;


const unsigned char SERVICE_NUMBER   =  0x01; // サービスナンバー
const unsigned char SERVICE_CODE[2]  = { 0x09, 0x00 }; // サービスコード
const unsigned char BLOCK_LIST[2]    = { 0x80, 0x00 }; // ブロックリスト
const unsigned char SECURITY_CODE[3] = { 0x30, 0x30, 0x30 }; // セキュリテリコード
const unsigned char ZERO_FILLER[3]   = { 0x00, 0x00, 0x00 }; // ゼロパディング


//空のパラメータデータ
unsigned char nilParameter[8] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };

//スマートタグの最大通信BLOCK数
const int maxBlocks = 12;





-(id)init
{
    return [self initWithFunction:0x00 fSum:0 fNum:0 data:nil dataLength:0 parameter:nil];
}


-(id)initWithFunction:(unsigned char)function
                 fSum:(int)fSum
                 fNum:(int)fNum
                 data:(unsigned char *)dat
           dataLength:(int)length
            parameter:(unsigned char *)parameter
{
    self = [super init];
    if (self)
    {
        _function = function;
        _fSum = fSum;
        _fNum = fNum;
        _data = [NSMutableData data];
        [_data appendBytes:dat length:length];
        _dataLength = length;
        if (parameter == nil)
        {
            parameter = nilParameter;
        }
        _parameterData = [NSMutableData data];
        [_parameterData appendBytes:parameter length:8];
    }
    return self;
}

- (float)estimatedWWETime
{
    int commandLength = [[self commandDataWithCommandCode:S_HEADER_WWE seq:0] length] + 10;
    return (commandLength + 10) * 0.03;
}

- (float)estimatedRWETime
{
    /*
    int commandLength = [[self commandDataWithCommandCode:S_HEADER_RWE seq:0] length] + 10;
    return (commandLength + 10) * 0.03;
     */
    return 3.0f;
}

- (NSMutableData *)commandDataWithCommandCode:(unsigned char)commandCode seq:(int)seq
{
    //最大送信BLOCK数を超えている場合は後ろをカット
    if(_dataLength > 16 * (maxBlocks - 1))
    {
        _dataLength = 16 * (maxBlocks - 1);
        NSLog(@"データの長さが最大送信ブロック数を超えているため、%dバイト目以降はカットされます。", _dataLength);
    }
    
    NSMutableData *bytes = [NSMutableData data];
    int numBlocks = ceil(_dataLength/16.0) + 1;
    
    if(commandCode == S_HEADER_WWE)
    {
        //WWE Block Data 0
        [bytes appendBytes:&_function length:1];
        [bytes appendBytes:&_fSum length:1];
        [bytes appendBytes:&_fNum length:1];
        [bytes appendBytes:&_dataLength length:1];
        [bytes appendBytes:&seq length:1];
        
        if ([SmarttagData type] == TAGTYPE_27_INCH && _function != S_CMD_CHECK_STATUS)
        //if ([SmarttagData type] == TAGTYPE_27_INCH)
        {
            [bytes appendBytes:SECURITY_CODE length:3];
        }
        else
        {
            [bytes appendBytes:ZERO_FILLER length:3];
        }
        
        const unsigned char *parameter = [_parameterData bytes];
        [bytes appendBytes:parameter length:8];
        
        //WWE Block Data 1~11
        const unsigned char *dat = [_data bytes];
        [bytes appendBytes:dat length:_dataLength];
        
        //データが書き込み終わったら、そのBLOCKが終わるまで0x00で埋める
        int numEmpty = (numBlocks - 1) * 16 - _dataLength;
        for (int j = 0; j < numEmpty; j++)
        {
            [bytes appendBytes:0x00 length:1];
        }
    }
    
    return bytes;
}


@end
