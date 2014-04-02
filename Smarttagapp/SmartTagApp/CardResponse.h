//
//  CardResponse.h
//  SmartTagApp
//

#import <Foundation/Foundation.h>

@interface CardResponse : NSObject

@property (nonatomic, readonly) int numBlocks;
@property (nonatomic, readonly) NSMutableData *blockData;
@property (nonatomic, readonly) NSMutableData *headerBlock;

-(id)initWithResponseData:(NSMutableData *)response;

@end
