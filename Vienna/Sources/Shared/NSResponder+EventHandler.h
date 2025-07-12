//
//  NSResponder+EventHandler.h
//  Vienna
//
//  Copyright 2025 Eitot
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

@import Cocoa;

NS_ASSUME_NONNULL_BEGIN

@interface NSResponder (EventHandler)

/// Handles the event and returns `YES` if handled successfully. The default
/// implementation first sends `-vna_supplementalHandlerForEvent:` to its next
/// responder and passes the message to it, if not `nil`. Otherwise, it passes
/// the message to its next responder recursively, ultimately returning `NO` if
/// there are no more responders.
- (BOOL)vna_handleEvent:(NSEvent *)event NS_SWIFT_NAME(handle(_:));

/// Whether the receiver can handle the event. The default implementation
/// returns `NO`.
- (BOOL)vna_canHandleEvent:(NSEvent *)event NS_SWIFT_NAME(canHandle(_:));

/// Returns a supplemental handler for the event or `nil` if there is none.
/// The default implementation returns `nil`.
- (nullable NSResponder *)vna_supplementalHandlerForEvent:(NSEvent *)event
    NS_SWIFT_NAME(supplementalHandler(for:));

@end

NS_ASSUME_NONNULL_END
