//
//  PolishedWindow.m
//  TunesWindow
//
//  Created by Matt Gemmell on 12/02/2006.
//  Copyright 2006 Magic Aubergine. All rights reserved.
//

#import "PolishedWindow.h"

@implementation PolishedWindow

-(id)initWithContentRect:(NSRect)contentRect 
                styleMask:(unsigned int)styleMask 
                  backing:(NSBackingStoreType)bufferingType 
                    defer:(BOOL)flag
{
   // Conditionally add textured window flag to stylemask
    unsigned int newStyle;
    if (styleMask & NSTexturedBackgroundWindowMask)
        newStyle = styleMask;
	else
        newStyle = (NSTexturedBackgroundWindowMask | styleMask);
    
    if ((self = [super initWithContentRect:contentRect styleMask:newStyle backing:bufferingType defer:flag]) != nil)
	{
        forceDisplay = NO;
		
		[self setShowsResizeIndicator:NO];
        
        [self setBackgroundColor:[self sizedPolishedBackground]];
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(windowDidResize:) 
                                                     name:NSWindowDidResizeNotification 
                                                   object:self];
        
        return self;
    }
    return nil;
}

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
-(void)setToolbar:(NSToolbar *)toolbar
{
    // Only actually call this if we respond to it on this machine
//    if ([toolbar respondsToSelector:@selector(setShowsBaselineSeparator:)])
//        [toolbar setShowsBaselineSeparator:NO];

    [super setToolbar:toolbar];
}
#endif

- (void)windowDidResize:(NSNotification *)aNotification
{
    [self setBackgroundColor:[self sizedPolishedBackground]];
    if (forceDisplay) {
        [self display];
    }
}

- (void)setMinSize:(NSSize)aSize
{
    [super setMinSize:NSMakeSize(MAX(aSize.width, 150.0), MAX(aSize.height, 150.0))];
}

- (void)setFrame:(NSRect)frameRect display:(BOOL)displayFlag animate:(BOOL)animationFlag
{
    forceDisplay = YES;
    [super setFrame:frameRect display:displayFlag animate:animationFlag];
    forceDisplay = NO;
}

- (NSColor *)sizedPolishedBackground
{
    NSImage *bg = [[NSImage alloc] initWithSize:[self frame].size];
    
    NSImage *bottomMiddle;
    NSColor *bottomMiddlePattern;
    NSImage *topLeft;
    NSImage *topMiddle;
    NSColor *topMiddlePattern;
    NSImage *topRight;
    NSImage *middleLeft;
    NSImage *middleRight;

	bottomMiddle = [NSImage imageNamed:@"bottom_middle"];
	bottomMiddlePattern = [NSColor colorWithPatternImage:bottomMiddle];
	topLeft = [NSImage imageNamed:@"top_left"];
	topMiddle = [NSImage imageNamed:@"top_middle"];
	topMiddlePattern = [NSColor colorWithPatternImage:topMiddle];
	topRight = [NSImage imageNamed:@"top_right"];
	
	middleLeft = nil;
	middleRight = nil;
    
    // Find background color to draw into window
    [topMiddle lockFocus];
    NSColor *bgColor = NSReadPixel(NSMakePoint(0, 0));
    [topMiddle unlockFocus];
    
    // Set min width of temporary pattern image to prevent flickering at small widths
    float minWidth = 300.0;
    
    // Create temporary image for top-middle pattern
    NSImage *topMiddleImg = [[NSImage alloc] initWithSize:NSMakeSize(MAX(minWidth, [self frame].size.width), [topMiddle size].height)];
    [topMiddleImg lockFocus];
    [topMiddlePattern set];
    NSRectFill(NSMakeRect(0, 0, [topMiddleImg size].width, [topMiddleImg size].height));
    [topMiddleImg unlockFocus];
    
    // Create temporary image for bottom-middle pattern
    NSImage *bottomMiddleImg = [[NSImage alloc] initWithSize:NSMakeSize(MAX(minWidth, [self frame].size.width), [bottomMiddle size].height)];
    [bottomMiddleImg lockFocus];
    [bottomMiddlePattern set];
    NSRectFill(NSMakeRect(0, 0, [bottomMiddleImg size].width, [bottomMiddleImg size].height));
    [bottomMiddleImg unlockFocus];
    
    // Begin drawing into our main image
    [bg lockFocus];
    
    // Composite current background color into bg
    [bgColor set];
    NSRectFill(NSMakeRect(0, 0, [bg size].width, [bg size].height));
    
    // Composite bottom-middle image
    [bottomMiddleImg drawInRect:NSMakeRect(0, 0, 
                                           [bg size].width, 
                                           [bottomMiddle size].height) 
                       fromRect:NSMakeRect(0, 0, 
                                           [bg size].width, 
                                           [bottomMiddle size].height) 
                      operation:NSCompositeSourceOver 
                       fraction:1.0];
    [bottomMiddleImg release];
    
    // Composite top-middle image
    [topMiddleImg drawInRect:NSMakeRect([topLeft size].width, [bg size].height - [topLeft size].height, 
                                        [bg size].width - [topLeft size].width - [topRight size].width, 
                                        [topLeft size].height) 
                    fromRect:NSMakeRect(0, 0, 
                                        [bg size].width - [topLeft size].width - [topRight size].width, 
                                        [topLeft size].height) 
                   operation:NSCompositeSourceOver 
                    fraction:1.0];
    [topMiddleImg release];
    
    // Composite top-left and top-right images
    [topLeft compositeToPoint:NSMakePoint(0, [bg size].height - [topLeft size].height) 
                    operation:NSCompositeSourceOver];
    [topRight compositeToPoint:NSMakePoint([bg size].width - [topRight size].width, 
                                           [bg size].height - [topRight size].height) 
                     operation:NSCompositeSourceOver];
    
    [bg unlockFocus];
    
    return [NSColor colorWithPatternImage:[bg autorelease]];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResizeNotification object:self];
    [super dealloc];
}
@end
