@import Foundation;

@interface NSNotificationCenter (NSNotificationCenterAdditions)

- (void)vna_postNotificationOnMainThreadWithName:(NSString *)name
                                          object:(id)object;

@end
