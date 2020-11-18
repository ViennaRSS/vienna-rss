//
//  VNAVerticallyCenteredTextFieldCell.h
//  Vertically centered NSTextFieldCell
//
//  Idea by Jacob Egger and Matt Bell http://stackoverflow.com/questions/1235219/is-there-a-right-way-to-have-nstextfieldcell-draw-vertically-centered-text
//  Modified by Barijaona Ramaholimihaso
//

#import "VNAVerticallyCenteredTextFieldCell.h"

@implementation VNAVerticallyCenteredTextFieldCell

// Deal ourselves with drawing the text inside the cell
-(void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    /* if your values can be attributed strings, make them white when selected */
    if (self.isHighlighted && self.backgroundStyle==NSBackgroundStyleDark) {
        NSMutableAttributedString *whiteString = self.attributedStringValue.mutableCopy;
        [whiteString addAttribute: NSForegroundColorAttributeName
                            value: [NSColor whiteColor]
                            range: NSMakeRange(0, whiteString.length) ];
        self.attributedStringValue = whiteString;
    }

    // Initialize a graphics context
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    CGRect rect = NSRectToCGRect([self titleRectForBounds:cellFrame]);
    // hack context to avoid flipped text
    CGFloat shiftY = rect.origin.y + rect.origin.y + rect.size.height;
    CGContextTranslateCTM(context, 0, shiftY);
    CGContextScaleCTM(context, 1.0, -1.0);
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)self.attributedStringValue);
    CGPathRef path = CGPathCreateWithRect(rect,  NULL);
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
    // Do the actual drawing
    CTFrameDraw(frame, context);
    // Reset context previously hacked
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextTranslateCTM(context, 0, -shiftY);
    // Release the objects we used.
    CFRelease(frame);
    CFRelease(path);
    CFRelease(framesetter);
}

- (NSRect)titleRectForBounds:(NSRect)theRect {
    /* get the standard text content rectangle */
    NSRect titleFrame = [super titleRectForBounds:theRect];

    /* find out how big the rendered text will be */
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)self.attributedStringValue);
    CGSize frameSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, [self.attributedStringValue length]), NULL, CGSizeMake(titleFrame.size.width, CGFLOAT_MAX), nil);
    CFRelease(framesetter);

    CGFloat tHeight = frameSize.height;
    CGFloat fHeight = titleFrame.size.height;
    /* If the height of the rendered text is less then the available height,
     * we modify the titleFrame to center the text vertically */
    if (tHeight < fHeight) {
        titleFrame.origin.y = theRect.origin.y + (theRect.size.height - tHeight )/2.0;
        titleFrame.size.height = tHeight;
    } else {
    	if (tHeight < 1.5 * fHeight)
    	{
    		titleFrame.origin.y = theRect.origin.y + (fHeight - tHeight);
    		titleFrame.size.height = tHeight;
    	}
    }
    return titleFrame;
}

@end
