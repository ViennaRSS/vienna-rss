@import Foundation;

@interface NSNotificationCenter (NSNotificationCenterAdditions)

- (void)vna_postNotificationOnMainThread:(NSNotification *)notification;
- (void)vna_postNotificationOnMainThreadWithName:(NSString *)name
                                          object:(id)object;
- (void)vna_postNotificationOnMainThreadWithName:(NSString *)name
                                          object:(id)object
                                        userInfo:(NSDictionary *)userInfo;

@end
