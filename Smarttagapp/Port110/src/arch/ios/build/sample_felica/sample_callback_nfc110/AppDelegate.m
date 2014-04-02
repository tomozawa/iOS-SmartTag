/*
 * Copyright 2013 Sony Corporation
 */


#import "AppDelegate.h"

#import "sample_callback_nfc110_ble.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    printf("FeliCa Callback sample.\n");

    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [SampleCallback registerCallback];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            [SampleCallback start];
        }
    });
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    [SampleCallback unregisterCallback];
    [SampleCallback stop];
}

@end
