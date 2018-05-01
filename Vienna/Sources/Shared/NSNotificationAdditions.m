#import "NSNotificationAdditions.h"

@implementation NSNotificationCenter (NSNotificationCenterAdditions)
- (void) postNotificationOnMainThread:(NSNotification *) notification {
	dispatch_async(dispatch_get_main_queue(), ^{
		[self postNotification:notification];
	});
}

- (void) postNotificationOnMainThreadWithName:(NSString *) name object:(id) object {
	dispatch_async(dispatch_get_main_queue(), ^{
		[self postNotificationName:name object:object];
	});
}

- (void) postNotificationOnMainThreadWithName:(NSString *) name object:(id) object userInfo:(NSDictionary *) userInfo {
	dispatch_async(dispatch_get_main_queue(), ^{
		[self postNotificationName:name object:object userInfo:userInfo];
	});
}

@end
