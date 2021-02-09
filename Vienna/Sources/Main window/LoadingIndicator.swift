//
//  LoadingIndicator.swift
//  Vienna
//
//  Copyright 2020 Tassilo Karge
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

@IBDesignable
class LoadingIndicator: NSView {

    // MARK: Initialization

    private var observer: AnyObject?
    private let animationLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        self.wantsLayer = true
        self.layer?.addSublayer(animationLayer)
        self.layerContentsRedrawPolicy = .duringViewResize
        if #available(macOS 10.14, *) {
            animationLayer.strokeColor = NSColor.controlAccentColor.cgColor
        } else {
            animationLayer.strokeColor = NSColor(for: NSColor.currentControlTint).cgColor
        }
        animationLayer.lineWidth = 2.0
        animationLayer.strokeEnd = 0.0
        animationLayer.actions = ["strokeEnd": NSNull()]

        if #available(macOS 10.14, *) {
            observer = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
                self?.animationLayer.strokeColor = NSColor.controlAccentColor.cgColor
            }
        } else {
            let center = NotificationCenter.default
            let name = NSColor.currentControlTintDidChangeNotification
            observer = center.addObserver(forName: name, object: NSApp, queue: .main) { [weak self] _ in
                self?.animationLayer.strokeColor = NSColor(for: NSColor.currentControlTint).cgColor
            }
        }
    }

    deinit {
        if #available(macOS 10.14, *) {
            // Do nothing
        } else {
            if let observer = observer {
                let center = NotificationCenter.default
                let name = NSColor.currentControlTintDidChangeNotification
                center.removeObserver(observer, name: name, object: NSApp)
            }
        }
    }

    // MARK: Drawing

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 4.0)
    }

    override func draw(_ dirtyRect: NSRect) {
        let loadingProgress = currentLoadingProgress
        animationLayer.frame = self.frame
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0.0, y: 1.0))
        path.addLine(to: CGPoint(x: self.frame.size.width, y: 1.0))
        animationLayer.path = path
        setLoadingProgress(currentLoadingProgress)
    }

    // MARK: Animating

    var currentLoadingProgress: CGFloat {
        animationLayer.presentation()?.strokeEnd ?? animationLayer.strokeEnd
    }

    func setLoadingProgress(_ newProgress: CGFloat, animationDuration: Double = 0.0) {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = animationLayer.presentation()?.strokeEnd ?? animationLayer.strokeEnd
        animation.toValue = newProgress
        animation.duration = animationDuration
        animation.delegate = self
        animationLayer.add(animation, forKey: "strokeEndAnimation")
        animationLayer.strokeEnd = newProgress
    }

}

// MARK: - Animation delegate

extension LoadingIndicator: CAAnimationDelegate {

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        // When the animation is complete, the stroke end should return to zero.
        // This avoids a noticeable jump when the user reloads the webpage.
        if flag && animationLayer.strokeEnd == 1.0 {
            animationLayer.strokeEnd = 0.0
        }
    }

}
