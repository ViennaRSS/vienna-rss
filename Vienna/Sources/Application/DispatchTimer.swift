//
//  DispatchTimer.swift
//  Vienna
//
//  Copyright 2023 Eitot
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

import Dispatch
import Foundation
import os.log

@objc(VNADispatchTimer)
class DispatchTimer: NSObject {

    private var dispatchSource: DispatchSourceTimer

    private(set) var interval: TimeInterval

    /// The interval by which the system may delay firing the timer.
    private(set) var leeway: DispatchTimeInterval

    @objc
    init(interval: TimeInterval, fireImmediately: Bool, dispatchQueue: DispatchQueue, eventHandler: @escaping () -> Void) {
        dispatchSource = DispatchSource.makeTimerSource(queue: dispatchQueue)
        self.interval = interval
        leeway = DispatchTimeInterval.seconds(rounding: interval)
        super.init()

        dispatchSource.scheduleUsingWallClockTime(interval: interval, fireImmediately: fireImmediately, leeway: leeway)
        dispatchSource.setEventHandler {
            os_log("Event handler submitted to dispatch timer", log: .dispatchTimer, type: .debug)
            eventHandler()
        }
        dispatchSource.setRegistrationHandler {
            os_log("Dispatch timer registered with interval of %llds, firing immediately: %{public}@", log: .dispatchTimer, type: .debug, Int(interval), fireImmediately.description)
        }
        dispatchSource.activate()
    }

    deinit {
        // The documentation does not explain what happens if the pointer to the
        // dispatch source is set to nil, i.e. whether the system keeps a strong
        // reference elsewhere, before cancel() was called.
        dispatchSource.setCancelHandler {
            os_log("Dispatch timer cancelled", log: .dispatchTimer, type: .debug)
        }
        dispatchSource.cancel()
    }

    /// Reschedules the timer with the given time interval, optionally firing
    /// the timer immediately.
    @objc
    func reschedule(interval: TimeInterval, fireImmediately: Bool) {
        // The documentation of dispatch_source_set_timer(), which is ultimately
        // the source of schedule(wallDeadline:repeating:leeway:), sets out that
        // it can be called again to reset the timer, as long as it has not been
        // cancelled.
        dispatchSource.suspend()
        self.interval = interval
        leeway = .seconds(rounding: interval)
        dispatchSource.scheduleUsingWallClockTime(interval: interval, fireImmediately: fireImmediately, leeway: leeway)
        dispatchSource.setRegistrationHandler {
            os_log("Dispatch timer re-registered with interval of %llds, firing immediately: %{public}@", log: .dispatchTimer, type: .debug, Int(interval), fireImmediately.description)
        }
        dispatchSource.resume()
    }

    /// Fires the timer immediately and reschedules it, based on the current
    /// value of `interval`.
    @objc
    func fire() {
        reschedule(interval: interval, fireImmediately: true)
    }

}

// MARK: - Private extensions

private extension DispatchSourceTimer {

    // Use "wall clock" time instead of Mach absolute time. The system might go
    // to sleep or suspend apps before the timer fires. Although the timer will
    // be paused as well, wall clock time ensures that the lapsed time is taken
    // into account when resuming the timer.
    func scheduleUsingWallClockTime(interval: TimeInterval, fireImmediately: Bool, leeway: DispatchTimeInterval) {
        let deadline: DispatchWallTime = fireImmediately ? .now() : .now() + interval
        self.schedule(wallDeadline: deadline, repeating: interval, leeway: leeway)
    }

}

private extension DispatchTimeInterval {

    // Apple recommends a leeway of 10% of the interval. See: "Energy Efficiency
    // Guide for Mac Apps", section "Minimize Timer Usage".
    // https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/Timers.html
    static func seconds(rounding timeInterval: TimeInterval, fraction: Double = 0.1) -> Self {
        let leeway = Int(timeInterval * fraction)
        return .seconds(leeway)
    }

}

private extension OSLog {

    static let dispatchTimer = OSLog(subsystem: "--", category: "DispatchTimer")

}
