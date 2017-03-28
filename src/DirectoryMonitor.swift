//
//  DirectoryMonitor.swift
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
    init(directories: [URL]) {
        self.directories = directories
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

    /// Starts or resumes the monitor, invoking the event-handler block if the
    /// directory contents change.
    ///
    /// - Parameter eventHandler: The handler to call when an event occurs.
    /// - Throws: An error of type `DirectoryMonitorError`.
    func start(eventHandler: @escaping EventHandler) throws {
        // If the stream exists, then stop it and start over. This will be the
        // case when start(eventHandler:) is called multiple times. Rather than
        // throwing an error, logging this will suffice.
        if stream != nil {
            stop()

            if #available(macOS 10.12, *) {
                os_log("Restarting directory monitor", log: .default, type: .debug)
            } else {
                NSLog("Restarting directory monitor");
            }
        }

        // Check if proper URLs are provided.
        if directories.isEmpty {
            throw DirectoryMonitorError.noDirectoriesProvided
        }

        for directory in directories {
            guard (try? directory.checkResourceIsReachable()) == true else {
                throw DirectoryMonitorError.directoryCannotBeOpened(path: directory.path)
            }
        }

        // The callback does not allow capturing external properties. Instead,
        // the event handler is passed as a stream context, allowing the handler
        // to be called from within the closure.
        let pointer = UnsafeMutableRawPointer(mutating: Unmanaged.passUnretained(self).toOpaque())
        var context = FSEventStreamContext(info: pointer)

        // The callback will pass along the raw pointer to the direcory monitor
        // instance. Recasting this will make the event handler accessible.
        let callback: FSEventStreamCallback = { (_, context, _, _, _, _) -> Void in
            if let context = context {
                let monitor = Unmanaged<DirectoryMonitor>.fromOpaque(context).takeUnretainedValue()

                if let eventHandler = monitor.eventHandler {
                    eventHandler()
                }
            }
        }

        // The directory monitor will listen to events that happen in both
        // directions of each directory's hierarchy and will coalesce events
        // that happen within 2 seconds of each other.
        do {
            let stream = try FSEventStreamRef(callback: callback, context: &context, directories: directories, latency: 2, configuration: [.fileEvents, .watchRoot])
            self.stream = stream
            self.eventHandler = eventHandler

            // FSEvents has a two-pronged approach: schedule a stream (and
            // record the changes) and start sending events. This granualarity
            // is not desirable for the directory monitor, so they are combined.
            do {
                stream.schedule()
                try stream.start()
            } catch {
                // This closure is executed if start() fails. Accordingly, the
                // stream must be unscheduled.
                stop()

                throw DirectoryMonitorError.streamCouldNotBeStarted
            }
        } catch {
            throw DirectoryMonitorError.streamCouldNotBeCreated
        }
    }

    /// Stops the monitor, preventing any further invocation of the event-
    /// handler block.
    func stop() {
        // Unschedule the stream from its run loop and remove the (only)
        // reference count before unsetting the pointer.
        if let stream = stream {
            stream.stop()
            stream.invalidate()
            stream.release()

            self.stream = nil
        }

        eventHandler = nil
    }

}

// MARK: - Error handling

enum DirectoryMonitorError: LocalizedError {
    case noDirectoriesProvided
    case directoryCannotBeOpened(path: String)
    case streamCouldNotBeCreated
    case streamCouldNotBeStarted

    var errorDescription: String? {
        switch self {
        case .noDirectoriesProvided:
            return "No directories have been provided"
        case .directoryCannotBeOpened(let path):
            return "The directory cannot be opened: \(path)"
        case .streamCouldNotBeCreated:
            return "The file-system event stream could not be created"
        case .streamCouldNotBeStarted:
            return "The file-system event stream could not be started"
        }
    }
}

// MARK: - Convenience extensions

private extension FSEventStreamRef {

    init(allocator: CFAllocator? = kCFAllocatorDefault, callback: @escaping FSEventStreamCallback, context: UnsafeMutablePointer<FSEventStreamContext>? = nil, directories: [URL], startAt: FSEventStreamEventId = FSEventStreamEventId.now, latency: TimeInterval = 0, configuration: FileSystemEventStreamConfiguration = .none) throws {
        let directories = directories.map({ $0.path as CFString }) as CFArray

        if let stream = FSEventStreamCreate(allocator, callback, context, directories, startAt, latency, configuration.rawValue) {
            self = stream
        } else {
            throw FileSystemEventStreamError.streamCouldNotBeCreated
        }
    }

    func schedule(runLoop: RunLoop = RunLoop.current, runLoopMode: CFRunLoopMode = CFRunLoopMode.defaultMode!) {
        FSEventStreamScheduleWithRunLoop(self, runLoop.getCFRunLoop(), runLoopMode.rawValue)
    }

    func start() throws {
        if !FSEventStreamStart(self) {
            throw FileSystemEventStreamError.streamCouldNotBeStarted
        }
    }

    func stop() {
        FSEventStreamStop(self)
    }

    func unschedule(runLoop: RunLoop, runLoopMode: CFRunLoopMode) {
        FSEventStreamUnscheduleFromRunLoop(self, runLoop.getCFRunLoop(), runLoopMode.rawValue)
    }

    func invalidate() {
        FSEventStreamInvalidate(self)
    }

    func release() {
        FSEventStreamRelease(self)
    }

}

private extension FSEventStreamContext {

    init(info: UnsafeMutableRawPointer?) {
        self.init(version: 0, info: info, retain: nil, release: nil, copyDescription: nil)
    }

}

private extension FSEventStreamEventId {

    static var now: FSEventStreamEventId {
        return FSEventStreamEventId(kFSEventStreamEventIdSinceNow)
    }

}

// MARK: - Convenience types

private struct FileSystemEventStreamConfiguration: OptionSet {

    let rawValue: FSEventStreamCreateFlags

    static let none = flag(kFSEventStreamCreateFlagNone)
    static let watchRoot = flag(kFSEventStreamCreateFlagWatchRoot)
    static let ignoreSelf = flag(kFSEventStreamCreateFlagIgnoreSelf)
    static let fileEvents = flag(kFSEventStreamCreateFlagFileEvents)

    private static func flag(_ flag: Int) -> FileSystemEventStreamConfiguration {
        return self.init(rawValue: FSEventStreamCreateFlags(flag))
    }
    
}

private enum FileSystemEventStreamError: Error {
    case streamCouldNotBeCreated
    case streamCouldNotBeStarted
}
