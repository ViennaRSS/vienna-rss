#import "NSNotificationAdditions.h"

@implementation NSNotificationCenter (NSNotificationCenterAdditions)
- (void) postNotificationOnMainThread:(NSNotification *) notification {
	[self performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:NO];
}

- (void) postNotificationOnMainThreadWithName:(NSString *) name object:(id) object {
	[self postNotificationOnMainThreadWithName:name object:object userInfo:nil];
}

- (void) postNotificationOnMainThreadWithName:(NSString *) name object:(id) object userInfo:(NSDictionary *) userInfo {
	dispatch_async(dispatch_get_main_queue(), ^{
		[self postNotificationName:name object:object userInfo:userInfo];
	});
}

@end
