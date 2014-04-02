//
//  CellContentWithImageView.m
//  SmartTagApp
//
//  Created by Naomi Shimada on 2013/09/22.
//  Copyright (c) 2013年 arts. All rights reserved.
//

#import "CellContentWithImageView.h"

@implementation CellContentWithImageView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

// nib(xib)ファイルがロードされたときに呼ばれる
- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.image = self.image;
}

+ (id)cellContentView
{
    // xib から初期化する
    UINib *nib = [UINib nibWithNibName:@"CellContentWithImageView" bundle:nil];
    return [[nib instantiateWithOwner:self options:nil] objectAtIndex:0];
}



- (void)setImage:(UIImage *)image
{
    _image = [image copy];
    _imageView.image = _image;
}
@end
