#import "NSNotificationAdditions.h"

@implementation NSNotificationCenter (NSNotificationCenterAdditions)

- (void)vna_postNotificationOnMainThread:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self postNotification:notification];
    });
}

- (void)vna_postNotificationOnMainThreadWithName:(NSString *)name
                                          object:(id)object {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self postNotificationName:name object:object];
    });
}

- (void)vna_postNotificationOnMainThreadWithName:(NSString *)name
                                          object:(id)object
                                        userInfo:(NSDictionary *)userInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self postNotificationName:name object:object userInfo:userInfo];
    });
}

@end
