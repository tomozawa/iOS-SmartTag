/*
 * Copyright 2013 Sony Corporation
 */

#import <Foundation/Foundation.h>

@interface SampleCallback : NSObject

+ (void)registerCallback;
+ (void)unregisterCallback;
+ (void)start;
+ (void)stop;

@end
