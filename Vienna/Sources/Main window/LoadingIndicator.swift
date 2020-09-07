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
import Foundation

@IBDesignable
class LoadingIndicator: NSView {

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 4.0)
    }

    let animationLayer: CAShapeLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func commonInit() {
        self.wantsLayer = true
        self.layer?.addSublayer(animationLayer)
        self.layerContentsRedrawPolicy = .duringViewResize
        animationLayer.strokeColor = NSColor.blue.cgColor
        animationLayer.lineWidth = 4
        animationLayer.strokeEnd = 0
        animationLayer.actions = ["strokeEnd": NSNull()]
    }

    override func draw(_ dirtyRect: NSRect) {
        let loadingProgress = getCurrentLoadingProgress()
        animationLayer.frame = self.frame
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 2.0))
        path.addLine(to: CGPoint(x: self.frame.size.width, y: 2.0))
        animationLayer.path = path
        setLoadingProgress(loadingProgress)
    }

    func getCurrentLoadingProgress() -> CGFloat {
        animationLayer.presentation()?.strokeEnd ?? animationLayer.strokeEnd
    }

    func setLoadingProgress(_ newProgress: CGFloat, animationDuration: Double = 0.0) {

        if animationDuration > 0 {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = animationLayer.presentation()?.strokeEnd ?? animationLayer.strokeEnd
            animation.toValue = newProgress
            animation.duration = animationDuration
            animation.isRemovedOnCompletion = false
            animationLayer.add(animation, forKey: "strokeEndAnimation")
        } else {
            animationLayer.removeAllAnimations()
            animationLayer.strokeEnd = newProgress
        }
    }
}
