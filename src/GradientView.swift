//
//  GradientView.swift
//  Vienna
//
//  Copyright 2017
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Cocoa

class GradientView: NSView {

    // MARK: Properties

    /// The starting color of the gradient.
    @IBInspectable var startingColor: NSColor? {
        didSet {
            // Make a copy to avoid sharing.
            startingColor = startingColor?.copy() as? NSColor

            needsDisplay = true
        }
    }

    /// The ending color of the gradient.
    @IBInspectable var endingColor: NSColor? {
        didSet {
            // Make a copy to avoid sharing.
            endingColor = endingColor?.copy() as? NSColor

            needsDisplay = true
        }
    }

    /// The angle of the linear gradient, specified in degrees. Positive values
    /// indicate rotation in the counter-clockwise direction relative to the
    /// horizontal axis.
    @IBInspectable var angle: CGFloat = 270 {
        didSet {
            needsDisplay = true
        }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        // Clear the background and return if the starting color is not set.
        guard let startingColor = startingColor else {
            NSColor.clear.setFill()
            NSRectFill(dirtyRect)
            return
        }

        // Draw the gradient only if the ending color is set and different from
        // the starting color. Otherwise, draw only the starting color.
        if let endingColor = endingColor, endingColor != startingColor {
            let gradient = NSGradient(starting: startingColor, ending: endingColor)
            gradient?.draw(in: dirtyRect, angle: angle)
        } else {
            startingColor.setFill()
            NSRectFill(dirtyRect)
        }
    }

}
