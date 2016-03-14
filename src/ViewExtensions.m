//
//  ViewExtensions.m
//  Vienna
//
//  Created by Steve Palmer on 27/05/2007.
//  Copyright (c) 2004-2007 Steve Palmer. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "ViewExtensions.h"

@interface NSAnimation (ViennaAnimationWithTags)
-(void)MA_setTag:(NSInteger)newTag;
@property (nonatomic, readonly) NSInteger MA_tag;
@end

@implementation NSAnimation (ViennaAnimationWithTags)

/* MA_tagDict
 * A dictionary used to simulate instance variables for our category
 */
- (NSMutableDictionary *)MA_tagDict
{
	static NSMutableDictionary *MATagDict = nil;
	if (MATagDict == nil)
	{
		MATagDict = [[NSMutableDictionary alloc] init];
	}
	return MATagDict;
}

/* MA_setTag
 * Assigns the specified tag value to the animation object.
 */
-(void)MA_setTag:(NSInteger)newTag
{
	[self MA_tagDict][[NSValue valueWithPointer:(__bridge const void *)(self)]] = @(newTag);
}

/* MA_tag
 * Returns the associated tag.
 */
-(NSInteger)MA_tag
{
	NSMutableDictionary *tagDict = [self MA_tagDict];
	NSValue *key = [NSValue valueWithPointer:(__bridge const void *)(self)];
	NSInteger tag = [tagDict[key] integerValue];
	[tagDict removeObjectForKey:key];
	return tag;
}
@end

@implementation NSView (ViewExtensions)

/* resizeViewWithAnimation
 * Resizes the specified view with animation.
 */
-(void)resizeViewWithAnimation:(NSRect)newFrame withTag:(NSInteger)viewTag
{
	NSDictionary * dict = @{
							NSViewAnimationEndFrameKey: [NSValue valueWithRect:newFrame],
							NSViewAnimationTargetKey: self,
							};
	
	NSViewAnimation * animation = [[NSViewAnimation alloc] initWithViewAnimations:@[dict]];
	animation.animationBlockingMode = NSAnimationNonblocking;
	animation.duration = 0.1;
	animation.animationCurve = NSAnimationEaseInOut;
	animation.delegate = (id<NSAnimationDelegate>)self;
	[animation MA_setTag:viewTag];
	[animation startAnimation];
}

/* animationDidEnd
 * Delegate function called when animation completes.
 */
-(void)animationDidEnd:(NSAnimation *)animation
{
	NSWindow * viewWindow = self.window;
	NSInteger viewTag = [animation MA_tag];

	if ([viewWindow.delegate respondsToSelector:@selector(viewAnimationCompleted:withTag:)])
		[(id)viewWindow.delegate viewAnimationCompleted:self withTag:viewTag];
}

@end
