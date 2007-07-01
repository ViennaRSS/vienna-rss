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

@interface TaggedViewAnimation : NSViewAnimation {
	int tagValue;
}

// Public functions
-(void)setTag:(int)newTag;
-(int)tag;
@end

@implementation TaggedViewAnimation

/* setTag
 * Assigns the specified tag value to the animation object.
 */
-(void)setTag:(int)newTag
{
	tagValue = newTag;
}

/* tag
 * Returns the associated tag.
 */
-(int)tag
{
	return tagValue;
}
@end

@implementation NSView (ViewExtensions)

/* resizeViewWithAnimation
 * On Mac OSX 10.4 or later, resizes the specified view with animation. On earlier versions, just resizes the view.
 */
-(void)resizeViewWithAnimation:(NSRect)newFrame withTag:(int)viewTag
{
	SInt32 MacVersion;
	
	if (Gestalt(gestaltSystemVersion, &MacVersion) == noErr && MacVersion >= 0x1040)
	{
		NSDictionary * dict = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSValue valueWithRect:newFrame], NSViewAnimationEndFrameKey,
			self, NSViewAnimationTargetKey,
			nil, nil];
		
		TaggedViewAnimation * animation = [[TaggedViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObject:dict]];
		[animation setAnimationBlockingMode:NSAnimationNonblocking];
		[animation setDuration:0.1];
		[animation setAnimationCurve:NSAnimationEaseInOut];
		[animation setDelegate:self];
		[animation setTag:viewTag];
		[animation startAnimation];
	}
	else
		[self setFrame:newFrame];
}

/* animationDidEnd
 * Delegate function called when animation completes. (Mac OSX 10.4 or later only).
 */
-(void)animationDidEnd:(TaggedViewAnimation *)animation
{
	NSWindow * viewWindow = [self window];
	int viewTag = [animation tag];

	[animation release];
	if ([[viewWindow delegate] respondsToSelector:@selector(viewAnimationCompleted:withTag:)])
		[[viewWindow delegate] viewAnimationCompleted:self withTag:viewTag];
}
@end
