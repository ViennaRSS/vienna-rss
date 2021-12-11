#import "NSNotificationAdditions.h"

@implementation NSNotificationCenter (NSNotificationCenterAdditions)

- (void)vna_postNotificationOnMainThreadWithName:(NSString *)name
                                          object:(id)object {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self postNotificationName:name object:object];
    });
}

@end
