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
    NSAttributedString *attrString = self.attributedStringValue;

    /* if your values can be attributed strings, make them white when selected */
    if (self.isHighlighted && self.backgroundStyle==NSBackgroundStyleDark) {
        NSMutableAttributedString *whiteString = [attrString.mutableCopy autorelease];
        [whiteString addAttribute: NSForegroundColorAttributeName
                            value: [NSColor whiteColor]
                            range: NSMakeRange(0, whiteString.length) ];
        attrString = whiteString;
    }

    [attrString drawWithRect: [self titleRectForBounds:cellFrame] 
                     options: NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin];
}

- (NSRect)titleRectForBounds:(NSRect)theRect {
    /* get the standard text content rectangle */
    NSRect titleFrame = [super titleRectForBounds:theRect];

    /* find out how big the rendered text will be */
    NSAttributedString *attrString = self.attributedStringValue;
    NSRect textRect = [attrString boundingRectWithSize: titleFrame.size
                                               options: NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin ];

	titleFrame.origin.y = theRect.origin.y + (theRect.size.height - textRect.size.height )/2.0 - 1.0;
	titleFrame.size.height = textRect.size.height;

    return titleFrame;
}

@end
