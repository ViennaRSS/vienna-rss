//
//  OverlayStatusBar.swift
//  Vienna
//
//  Copyright 2017-2018
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

/// An overlay status bar can show context-specific information above a view.
/// It is supposed to be a subview of another view. Once added, it will set its
/// own frame and constraints. Removing the status bar from its superview will
/// unwind the constraints.
///
/// Setting or unsetting the `label` property will show or hide the status bar
/// accordingly. It will not hide by itself.
final class OverlayStatusBar: NSView {

    // MARK: Subviews

    private var backgroundView: NSVisualEffectView = {
        let backgroundView = NSVisualEffectView(frame: NSRect.zero)
        backgroundView.wantsLayer = true
        backgroundView.blendingMode = .withinWindow
        backgroundView.alphaValue = 0
        backgroundView.layer?.cornerRadius = 3

        return backgroundView
    }()

    private var addressField: NSTextField = {
        let addressField: NSTextField
        if #available(macOS 10.12, *) {
            addressField = NSTextField(labelWithString: "")
        } else {
            addressField = NSTextField(frame: NSRect.zero)
            addressField.isBezeled = false
            addressField.isSelectable = false
            addressField.drawsBackground = false
            addressField.textColor = .labelColor
        }

        addressField.font = .systemFont(ofSize: 12, weight: .medium)
        addressField.lineBreakMode = .byTruncatingMiddle
        addressField.allowsDefaultTighteningForTruncation = true

        return addressField
    }()

    // MARK: Initialization

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 4800, height: 26))

        // Make sure that no other constraints are created.
        translatesAutoresizingMaskIntoConstraints = false
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        addressField.translatesAutoresizingMaskIntoConstraints = false

        // The text field should always be among the first views to shrink.
        addressField.setContentCompressionResistancePriority(.fittingSizeCompression, for: .horizontal)

        addSubview(backgroundView)
        backgroundView.addSubview(addressField)

        // Set the constraints.
        var backgroundViewConstraints: [NSLayoutConstraint] = []
        backgroundViewConstraints += NSLayoutConstraint.constraints(withVisualFormat: "V:|-3-[view]-3-|",
                                                                    metrics: nil, views: ["view": backgroundView])
        backgroundViewConstraints += NSLayoutConstraint.constraints(withVisualFormat: "H:|-3-[view]-3-|",
                                                                    metrics: nil, views: ["view": backgroundView])

        var addressFieldConstraints: [NSLayoutConstraint] = []
        addressFieldConstraints += NSLayoutConstraint.constraints(withVisualFormat: "V:|-2-[label]-2-|",
                                                                  metrics: nil, views: ["label": addressField])
        addressFieldConstraints += NSLayoutConstraint.constraints(withVisualFormat: "H:|-6-[label]-6-|",
                                                                  metrics: nil, views: ["label": addressField])

        NSLayoutConstraint.activate(backgroundViewConstraints)
        NSLayoutConstraint.activate(addressFieldConstraints)
    }

    // Make this initialiser unavailable.
    override private convenience init(frame frameRect: NSRect) {
        self.init()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("\(#function) has not been implemented")
    }

    // MARK: Setting the view hierarchy

    // When the status bar is added to the view hierarchy of another view,
    // perform additional setup, such as setting the constraints and creating
    // a tracking area for mouse movements.
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()

        guard let superview = superview else {
            return
        }

        // Layer-backing will make sure that the visual-effect view redraws.
        superview.wantsLayer = true

        var baseContraints: [NSLayoutConstraint] = []
        baseContraints += NSLayoutConstraint.constraints(withVisualFormat: "V:|->=0-[view]-0-|",
                                                         options: [], metrics: nil, views: ["view": self])
        baseContraints += NSLayoutConstraint.constraints(withVisualFormat: "H:|->=0-[view]->=0-|",
                                                         options: [], metrics: nil, views: ["view": self])

        NSLayoutConstraint.activate(baseContraints)

        // Pin the view to the left side.
        pin(to: .leadingEdge, of: superview)

        startTrackingMouse(on: superview)
    }

    // If the status bar is removed from the view hierarchy, then the tracking
    // area must be removed too.
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        if let superview = superview {
            stopTrackingMouse(on: superview)

            isShown = false
            position = nil
        }
    }

    // MARK: Pinning the status bar

    private enum Position {
        case leadingEdge, trailingEdge
    }

    private var position: Position?

    private lazy var leadingConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[view]", options: [], metrics: nil, views: ["view": self])
    private lazy var trailingConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:[view]-0-|", options: [], metrics: nil, views: ["view": self])

    // The status bar is pinned simply by setting and unsetting constraints.
    private func pin(to position: Position, of positioningView: NSView) {
        guard position != self.position else {
            return
        }

        let oldConstraints: [NSLayoutConstraint]
        let newConstraints: [NSLayoutConstraint]
        switch position {
        case .leadingEdge:
            oldConstraints = trailingConstraints
            newConstraints = leadingConstraints
        case .trailingEdge:
            oldConstraints = leadingConstraints
            newConstraints = trailingConstraints
        }

        // Remove existing constraints.
        NSLayoutConstraint.deactivate(oldConstraints)

        // Add new constraints.
        NSLayoutConstraint.activate(newConstraints)

        self.position = position
    }

    // MARK: Handling status updates

    /// The label to show. Setting this property will show or hide the status
    /// bar. It will remain visible until the label is set to `nil`.
    @objc var label: String? {
        didSet {
            // This closure is meant to be called very often. It should not
            // cause any expensive computations.
            if let label = label, !label.isEmpty {
                if label != addressField.stringValue {
                    addressField.stringValue = label
                }

                isShown = true
            } else {
                isShown = false
            }
        }
    }

    private var isShown = false {
        didSet {
            guard isShown != oldValue else {
                return
            }

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.4
                backgroundView.animator().alphaValue = isShown ? 1 : 0
            }, completionHandler: nil)
        }
    }

    // MARK: Setting up mouse tracking

    private var trackingArea: NSTrackingArea?

    private func startTrackingMouse(on trackingView: NSView) {
        if let trackingArea = self.trackingArea, trackingView.trackingAreas.contains(trackingArea) {
            return
        }

        let rect = trackingView.bounds
        let size = CGSize(width: rect.maxX, height: frame.height + 15)
        let origin = CGPoint(x: rect.minX, y: rect.minY)

        let trackingArea = NSTrackingArea(rect: NSRect(origin: origin, size: size),
                                          options: [.mouseEnteredAndExited, .mouseMoved,
                                                    .activeInKeyWindow],
                                          owner: self, userInfo: nil)
        self.trackingArea = trackingArea

        trackingView.addTrackingArea(trackingArea)
    }

    // Remove the tracking area and unset the reference.
    private func stopTrackingMouse(on trackingView: NSView) {
        if let trackingArea = trackingArea {
            trackingView.removeTrackingArea(trackingArea)
            self.trackingArea = nil
        }
    }

    // This method is called often, thus only change the tracking area when
    // the superview's bounds width and the tracking area's width do not match.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        guard let superview = superview, let trackingArea = trackingArea else {
            return
        }

        if superview.trackingAreas.contains(trackingArea), trackingArea.rect.width != superview.bounds.width {
            stopTrackingMouse(on: superview)
            startTrackingMouse(on: superview)
        }
    }

    // MARK: Responding to mouse movement

    private var widthConstraint: NSLayoutConstraint?

    // Once the mouse enters the tracking area, the width of the status bar
    // should shrink. This is done by adding a width constraint.
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)

        guard let superview = superview, event.trackingArea == trackingArea else {
            return
        }

        // Add the width constraint, if not already added.
        if widthConstraint == nil {
            let widthConstraint = NSLayoutConstraint(item: self, attribute: .width, relatedBy: .lessThanOrEqual,
                                                     toItem: nil, attribute: .notAnAttribute, multiplier: 1,
                                                     constant: superview.bounds.midX - 8)
            self.widthConstraint = widthConstraint
            widthConstraint.isActive = true
        }
    }

    // Pin the status bar to the side, opposite of the mouse's position.
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)

        guard let superview = superview else {
            return
        }

        // Map the mouse location to the superview's bounds.
        let point = superview.convert(event.locationInWindow, from: nil)

        if point.x <= superview.bounds.midX {
            pin(to: .trailingEdge, of: superview)
        } else {
            pin(to: .leadingEdge, of: superview)
        }
    }

    // Once the mouse exits the tracking area, the status bar's intrinsic width
    // should be restored, by removing the width constraint and pinning the view
    // back to the left side.
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)

        guard let superview = superview, event.trackingArea == trackingArea else {
            return
        }

        pin(to: .leadingEdge, of: superview)

        if let constraint = widthConstraint {
            removeConstraint(constraint)

            // Delete the constraint to make sure that a new one is created,
            // appropriate for the superview size (which may change).
            widthConstraint = nil
        }
    }

}
