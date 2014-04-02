/**
 * \brief    the header file for Semaphore (iOS)
 * \date     2013/04/26
 * \author   Copyright 2013 Sony Corporation
 */

#import <Foundation/Foundation.h>

#ifndef SEMAPHORE_H_
#define SEMAPHORE_H_

@interface Semaphore : NSObject

/*
 * Initialize methods
 */

- (id)initWithCount:(long)defaultCount;

/*
 * Semaphore control methods
 */

- (void)reset;
- (UInt32)waitTimeout:(dispatch_time_t)timeout;
- (void)signal;

@end

#endif /* !SEMAPHORE_H_ */
