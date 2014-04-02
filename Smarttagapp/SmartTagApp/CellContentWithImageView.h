//
//  CellContentWithImageView.h
//  SmartTagApp
//
//  Created by Naomi Shimada on 2013/09/22.
//  Copyright (c) 2013年 arts. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CellContentWithImageView : UIView

@property (copy, nonatomic) UIImage *image;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;

+ (id)cellContentView;

@end
