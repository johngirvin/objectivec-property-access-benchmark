#import "AppDelegate.h"
#import "Benchmark.h"

@implementation AppDelegate

- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[UIApplication sharedApplication] setIdleTimerDisabled: YES];
    [[[Benchmark alloc] init] test];
    return YES;
}

@end
