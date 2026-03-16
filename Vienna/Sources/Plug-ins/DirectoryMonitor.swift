//
//  DirectoryMonitor.swift
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

import CoreServices
import Foundation
import os.log

final class DirectoryMonitor: NSObject {

    // MARK: Initialization

    /// The directories to monitor.
    let directories: [URL]

    /// Creates a directory monitor for the directories.
    ///
    /// - Parameter directories: The directories to monitor.
    @objc
    init(directories: [URL]) {
        self.directories = directories.filter { $0.isFileURL }
    }

    // When the instance is ready to be deinitialized, the stream should be
    // invalidated properly. This is necessary, because the stream must be
    // released manually.
    deinit {
        stop()
    }

    // MARK: Monitoring

    typealias EventHandler = () -> Void

    // The stream will be kept in memory until stop() is called.
    private var stream: FSEventStreamRef?

    // The eventHandler will be kept in memory until stop() is called.
    private var eventHandler: EventHandler?

    // The callback will pass along the raw pointer to the direcory monitor
    // instance. Recasting this will make the event handler accessible.
    private var callback: FSEventStreamCallback = { _, info, eventCount, paths, flags, _ -> Void in
        guard let info = info else {
            os_log("No pointer to the event handler", log: .discoverer, type: .fault)
            return
        }

        if let paths = Unmanaged<NSArray>.fromOpaque(paths).takeUnretainedValue() as? [String] {
            for index in 0..<eventCount {
                let path = paths[index]
                let flag = flags[index]

                if flag & UInt32(kFSEventStreamEventFlagRootChanged) != 0 {
                    os_log("Root path %@ changed", log: .discoverer, type: .debug, path)
                }

                if flag & UInt32(kFSEventStreamEventFlagItemCreated) != 0 {
                    os_log("%@ added", log: .discoverer, type: .debug, path)
                }

                if flag & UInt32(kFSEventStreamEventFlagItemRenamed) != 0 {
                    os_log("%@ renamed or moved", log: .discoverer, type: .debug, path)
                }

                if flag & UInt32(kFSEventStreamEventFlagItemRemoved) != 0 {
                    os_log("%@ removed", log: .discoverer, type: .debug, path)
                }

                if flag & UInt32(kFSEventStreamEventFlagRootChanged) == 0,
                   flag & UInt32(kFSEventStreamEventFlagItemCreated) == 0,
                   flag & UInt32(kFSEventStreamEventFlagItemRenamed) == 0,
                   flag & UInt32(kFSEventStreamEventFlagItemRemoved) == 0 {
                    os_log("Unhandled file-system event: %d", log: .discoverer, type: .debug, flag)
                }
            }
        }

        os_log("Calling the event handler", log: .discoverer, type: .debug)

        let monitor = Unmanaged<DirectoryMonitor>.fromOpaque(info).takeUnretainedValue()
        monitor.eventHandler?()
    }

    /// Starts or resumes the monitor, invoking the event-handler block if the
    /// directory contents change.
    ///
    /// - Parameter eventHandler: The handler to call when an event occurs.
    /// - Throws: An error of type `DirectoryMonitorError`.
    @objc
    func start(eventHandler: @escaping EventHandler) throws {
        if stream != nil {
            stop()
        }

        if directories.isEmpty {
            return
        }

        // The callback does not allow capturing external properties. Instead,
        // the event handler is passed as a stream context, allowing the handler
        // to be called from within the closure.
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        var context = FSEventStreamContext(version: 0,
                                           info: pointer,
                                           retain: nil,
                                           release: nil,
                                           copyDescription: nil)

        // The directory monitor will listen to events that happen in both
        // directions of each directory's hierarchy and will coalesce events
        // that happen within 2 seconds of each other.
        let paths = directories.map { $0.path as CFString } as CFArray
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagWatchRoot | kFSEventStreamCreateFlagUseCFTypes)
        guard let stream = FSEventStreamCreate(kCFAllocatorDefault,
                                               callback,
                                               &context,
                                               paths,
                                               FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                                               2,
                                               flags) else {
            throw DirectoryMonitorError.streamCouldNotBeCreated
        }
        self.stream = stream
        self.eventHandler = eventHandler

        // FSEvents has a two-pronged approach: schedule a stream (and
        // record the changes) and start sending events. This granualarity
        // is not desirable for the directory monitor, so they are combined.
        FSEventStreamScheduleWithRunLoop(stream,
                                         RunLoop.current.getCFRunLoop(),
                                         CFRunLoopMode.defaultMode.rawValue)
        if !FSEventStreamStart(stream) {
            // This closure is executed if start() fails. Accordingly, the
            // stream must be unscheduled.
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            throw DirectoryMonitorError.streamCouldNotBeStarted
        }
    }

    /// Stops the monitor, preventing any further invocation of the event-
    /// handler block.
    func stop() {
        // Unschedule the stream from its run loop and remove the (only)
        // reference count before unsetting the pointer.
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)

            self.stream = nil
        }

        eventHandler = nil
    }

}

// MARK: - Error handling

enum DirectoryMonitorError: LocalizedError {
    case streamCouldNotBeCreated
    case streamCouldNotBeStarted

    var errorDescription: String? {
        switch self {
        case .streamCouldNotBeCreated:
            return "The file-system event stream could not be created"
        case .streamCouldNotBeStarted:
            return "The file-system event stream could not be started"
        }
    }
}

// MARK: - Public extensions

extension OSLog {

    static let monitor = OSLog(subsystem: "--", category: "DirectoryMonitor")

}
