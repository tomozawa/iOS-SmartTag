//
//  CardResponse.m
//  SmartTagApp
//
//  Created by Naomi Shimada on 2013/09/13.
//  Copyright (c) 2013年 arts. All rights reserved.
//

#import "CardResponse.h"

@implementation CardResponse

@synthesize numBlocks = _numBlocks;
@synthesize blockData = _blockData;
@synthesize headerBlock = _headerBlock;

NSMutableData *_blockData;
NSMutableData *_headerBlock;
NSMutableData *_response;
int _numBlocks;


-(id)initWithResponseData:(NSMutableData *)response
{
    if (self)
    {
        _response = response;
        _blockData = [NSMutableData data];
        _headerBlock = [NSMutableData data];
        _numBlocks = [response length] / 16;
        unsigned char *data = (unsigned char *)[response bytes];
        
        for (int i = 0; i < [response length]; i++)
        {
            unsigned char byte = data[i];
            if(i >= 0 && i < 16)
            {
                [_headerBlock appendBytes:&byte length:1];
            }
            else if(i >= 16)
            {
                [_blockData appendBytes:&byte length:1];
            }
        }
    }
    return self;
}



@end
