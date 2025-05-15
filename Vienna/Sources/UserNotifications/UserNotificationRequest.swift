//
//  UserNotificationRequest.swift
//  Vienna
//
//  Copyright 2023-2025 Eitot
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

@objc(VNAUserNotificationRequest)
class UserNotificationRequest: NSObject {

    /// The identifier of the notification.
    @objc let identifier: String

    /// Additional user info that is attached to the notification.
    @objc var userInfo: [AnyHashable: Any]?

    /// The title of the notification.
    @objc var title: String

    /// The subtitle of the notification.
    @objc var subtitle: String?

    /// The body text of the notification.
    @objc var body: String?

    /// Whether the notification plays a sound.
    @objc var playSound = false

    @objc
    init(identifier: String, title: String) {
        self.identifier = identifier
        self.title = title
    }

}
