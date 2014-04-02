/**
 * \brief    Semaphore (iOS)
 * \date     2013/04/26
 * \author   Copyright 2013 Sony Corporation
 */

#undef ICSLOG_MODULE
#define ICSLOG_MODULE "DBb"

#include "ics_error.h"

#import "blelog.h"
#import "Semaphore.h"

/* --------------------------------
 * Private members
 * -------------------------------- */

@interface Semaphore ()

@property (nonatomic) long count;
@property (nonatomic) long defaultCount;
@property (nonatomic) dispatch_semaphore_t sem;

@end

/* --------------------------------
 * Class definition
 * -------------------------------- */

@implementation Semaphore
{
    /*
     * These member variables are defined in the category above,
     * because of the implementation of accessing from unit tests.
     */
#if 0
    long _count;
    long _defaultCount;
    dispatch_semaphore_t _sem;
#endif
}

#pragma mark - public methods

/**
 * This method intializes the Semaphore class instance.
 *
 * \param  defaultCount           [IN] Semaphore initial count.
 *
 * \retval not nil                     Pointer to the instance.
 * \retval nil                         Initialization failure.
 */
- (id)initWithCount:(long)defaultCount
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Semaphore:initWithCount"
    ICSLOG_FUNC_BEGIN;

    if (defaultCount < 0) {
        BLELOG_ERR_PRINT(ICS_ERROR_INVALID_PARAM, @"Invalid parameter.");
        return nil;
    }

    self = [super init];
    if (self == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_NO_RESOURCES,
                         @"super initialization failed.");
        return nil;
    }

    _count = defaultCount;
    _defaultCount = defaultCount;

    BLELOG_DBG_PRINT(@"Begin alloc: _sem");
    _sem = dispatch_semaphore_create(_defaultCount);
    BLELOG_DBG_PRINT(@"End alloc: _sem");
    if (_sem == nil) {
        BLELOG_ERR_PRINT(ICS_ERROR_NO_RESOURCES,
                         @"_sem initialization failed.");
        return nil;
    }

    ICSLOG_FUNC_END;
    return self;
}

/**
 * This method resets the signals of the semaphore.
 */
- (void)reset
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Semaphore:reset"
    long ret;
    ICSLOG_FUNC_BEGIN;

    ret = 0;
    while (ret == 0) {
        ret = dispatch_semaphore_wait(_sem, DISPATCH_TIME_NOW);
    }

    for (long i = 0; i < _defaultCount; i++) {
        dispatch_semaphore_signal(_sem);
    }

    @synchronized (self) {
        _count = _defaultCount;
    }

    ICSLOG_FUNC_END;
}

/**
 * This method waits a signal from the semaphore.
 *
 * \param  timeout                [IN] When to timeout.
 *
 * \retval ICS_ERROR_SUCCESS           No error.
 * \retval ICS_ERROR_TIMEOUT           Time-out.
 *
 */
- (UInt32)waitTimeout:(dispatch_time_t)timeout
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Semaphore:waitTimeout"
    long ret;
    ICSLOG_FUNC_BEGIN;

    ret = dispatch_semaphore_wait(_sem, timeout);
    if (ret != 0) {
        return ICS_ERROR_TIMEOUT;
    }

    @synchronized (self) {
        _count--;
    }

    ICSLOG_FUNC_END;
    return ICS_ERROR_SUCCESS;
}

/**
 * This method signals for the waiting semaphore.
 */
- (void)signal
{
#undef ICSLOG_FUNC
#define ICSLOG_FUNC "Semaphore:signal"
    ICSLOG_FUNC_BEGIN;

    @synchronized (self) {
        if (_count == LONG_MAX) {
            return;
        } else {
            _count++;
        }
    }

    dispatch_semaphore_signal(_sem);

    ICSLOG_FUNC_END;
}

@end
