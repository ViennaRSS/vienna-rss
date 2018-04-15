//
//  BJRVerticallyCenteredTextFieldCell.h
//  Vertically centered NSTextFieldCell
//
//  Idea by Jacob Egger and Matt Bell http://stackoverflow.com/questions/1235219/is-there-a-right-way-to-have-nstextfieldcell-draw-vertically-centered-text
//  Modified by Barijaona Ramaholimihaso
//

#import "BJRVerticallyCenteredTextFieldCell.h"

@implementation BJRVerticallyCenteredTextFieldCell

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

    // Do the actual drawing
    [self.attributedStringValue drawWithRect: [self titleRectForBounds:cellFrame]
                     options: NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingDisableScreenFontSubstitution];
}

- (NSRect)titleRectForBounds:(NSRect)theRect {
    /* get the standard text content rectangle */
    NSRect titleFrame = [super titleRectForBounds:theRect];

    /* find out how big the rendered text will be */
    NSRect textRect = [self.attributedStringValue boundingRectWithSize: titleFrame.size
                                               options: NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingDisableScreenFontSubstitution];

    CGFloat tHeight = textRect.size.height;
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
