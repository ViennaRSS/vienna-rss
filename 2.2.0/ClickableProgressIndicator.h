//
//  ClickableProgressIndicator.h
//  Vienna
//
//  Created by Evan Schoenberg on 6/2/07.
//

#import <Cocoa/Cocoa.h>


@interface ClickableProgressIndicator : NSProgressIndicator {
	id target;
	SEL action;
}

- (void)setTarget:(id)inTarget;
- (void)setAction:(SEL)action;

@end
