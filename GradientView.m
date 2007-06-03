//
//  GradientView.m
//  Vienna
//
//  Created by Michael Stroeck on 06.02.07.
//  Copyright 2007 Michael Stroeck. All rights reserved.
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

#import "GradientView.h"
#import "CTGradient.h"

@implementation GradientView

// drawRect
// Fill the specified rectangle with a white->grey gradient.
-(void)drawRect:(NSRect)rect 
{
	NSColor * topColor = [NSColor whiteColor];
	NSColor * bottomColor = [NSColor grayColor];
	CTGradient * gradient = [CTGradient gradientWithBeginningColor:topColor endingColor:bottomColor];
	[gradient fillRect:[self bounds] angle:270];
}
@end
