//
//  AsyncHelper.swift
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

import Foundation

/// Gives an asynchronous call the ability to run like synchronously called. Calling the finishHandler signals that the execution has finished.
/// - Parameters:
///   - waitingQueue: The queue that waits for the execution to finish
///   - executingQueue: the queue where the execution shall happen. Must not be the same as queue!
///   - deadline: when to stop waiting for the task to finish execution
///   - task: the code that shall be executed. ATTENTION: must call the finishHandler at some point!
func waitForAsyncExecution(on waitingQueue: DispatchQueue = DispatchQueue.global(qos: .userInitiated), executingQueue: DispatchQueue = DispatchQueue.main, until deadline: DispatchTime? = nil, _ task: @escaping (_ finishHandler: @escaping () -> ()) -> () ) {

    guard waitingQueue != executingQueue else {
        NSException(name: .invalidArgumentException, reason: "Queue to wait and queue to execute block must never be the same!", userInfo: ["wait queue" : waitingQueue, "run queue": executingQueue]).raise()
        return
    }

    let dg = DispatchGroup()
    var didFinish = false
    let runLoop = CFRunLoopGetCurrent()
    let asyncBlock = {
        dg.enter()
        executingQueue.async {
            task { dg.leave() }
        }
        dg.wait()
        didFinish = true
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes?.rawValue) {
            CFRunLoopStop(runLoop)
        }
        CFRunLoopWakeUp(runLoop)
    }
    if let deadline = deadline {
        waitingQueue.asyncAfter(deadline: deadline, execute: asyncBlock)
    } else {
        waitingQueue.async(execute: asyncBlock)
    }
    while !didFinish {
        CFRunLoopRun()
    }
}
