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

#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_4
typedef enum {
    NSAnimationEaseInOut,       // default
    NSAnimationEaseIn,
    NSAnimationEaseOut,
    NSAnimationLinear
} NSAnimationCurve;

typedef enum {
    NSAnimationBlocking,
    NSAnimationNonblocking,
    NSAnimationNonblockingThreaded
} NSAnimationBlockingMode;

#ifndef NSViewAnimationEndFrameKey
	//#define NSViewAnimationEndFrameKey @"NSViewAnimationEndFrameKey"
#endif
#ifndef NSViewAnimationTargetKey
	//#define NSViewAnimationTargetKey @"NSViewAnimationTargetKey"
#endif

@interface NSObject (AnimationInterfaceForCompiler)
- (void)setAnimationBlockingMode:(NSAnimationBlockingMode)animationBlockingMode;
- (void)setAnimationCurve:(NSAnimationCurve)curve;
- (void)setDelegate:(id)delegate;
- (void)setTag:(int)tag;
- (void)setDuration:(float)duration;
- (void)startAnimation;

- (id)initWithViewAnimations:(NSArray *)animations;
@end
#endif

@interface NSObject (ObjectWithTags)
-(void)setTag:(int)newTag;
-(int)tag;
@end

@implementation NSObject (ObjectWithTags)

/* tagDict
 * A dictionary used to simulate instance variables for our category
 */
- (NSMutableDictionary *)tagDict
{
	static NSMutableDictionary *tagDict = nil;
	if (!tagDict) tagDict = [[NSMutableDictionary alloc] init];

	return tagDict;
}

/* setTag
 * Assigns the specified tag value to the animation object.
 */
-(void)setTag:(int)newTag
{
	[[self tagDict] setObject:[NSNumber numberWithInt:newTag]
					   forKey:[NSValue valueWithPointer:self]];
}

/* tag
 * Returns the associated tag.
 */
-(int)tag
{
	return [[[self tagDict] objectForKey:[NSValue valueWithPointer:self]] intValue];
}
@end

@implementation NSView (ViewExtensions)

/* resizeViewWithAnimation
 * On Mac OSX 10.4 or later, resizes the specified view with animation. On earlier versions, just resizes the view.
 */
-(void)resizeViewWithAnimation:(NSRect)newFrame withTag:(int)viewTag
{
	Class viewAnimationClass = NSClassFromString(@"NSViewAnimation");
	if (viewAnimationClass) {
		NSDictionary * dict = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSValue valueWithRect:newFrame], NSViewAnimationEndFrameKey,
			self, NSViewAnimationTargetKey,
			nil, nil];

		id animation = [[viewAnimationClass alloc] initWithViewAnimations:[NSArray arrayWithObject:dict]];
		[animation setAnimationBlockingMode:NSAnimationNonblocking];
		[animation setDuration:0.1];
		[animation setAnimationCurve:NSAnimationEaseInOut];
		[animation setDelegate:self];
		[animation setTag:viewTag];
		[animation startAnimation];

	} else {
		[self setFrame:newFrame];

		//Inform the delegate immediately since we're not animating
		if ([[[self window] delegate] respondsToSelector:@selector(viewAnimationCompleted:withTag:)])
			[[[self window] delegate] viewAnimationCompleted:self withTag:viewTag];
	}
}

/* animationDidEnd
 * Delegate function called when animation completes. (Mac OSX 10.4 or later only).
 */
-(void)animationDidEnd:(id)animation
{
	NSWindow * viewWindow = [self window];
	int viewTag = [animation tag];

	[animation release];
	if ([[viewWindow delegate] respondsToSelector:@selector(viewAnimationCompleted:withTag:)])
		[[viewWindow delegate] viewAnimationCompleted:self withTag:viewTag];
}

@end
