//
//  UserNotificationCenter.swift
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
import UserNotifications
import os.log

@objc(VNAUserNotificationCenter)
class UserNotificationCenter: NSObject {

    @objc static let current = UserNotificationCenter()

    // MARK: Registering notifications

    @objc(VNAUserNotificationAuthorizationStatus)
    enum AuthorizationStatus: Int {
        case notDetermined
        case provisional
        case authorized
        case denied
    }

    @objc(VNAUserNotificationSettings)
    class UserNotificationSettings: NSObject {
        @objc let authorizationStatus: AuthorizationStatus

        @objc(isSoundEnabled)
        let soundEnabled: Bool

        init(authorizationStatus: AuthorizationStatus, soundEnabled: Bool) {
            self.authorizationStatus = authorizationStatus
            self.soundEnabled = soundEnabled
        }
    }

    /// Retrieves the authorization status.
    ///
    /// - Parameter completionHandler: The block to execute asynchronously with
    ///     the results. It may be executed on a background thread.
    @objc(getNotificationSettingsWithCompletionHandler:)
    func getNotificationSettings(
        completionHandler: @escaping (_ settings: UserNotificationSettings) -> Void
    ) {
        guard #available(macOS 10.14, *) else {
            // NSNotificationCenter has no mechanism to query authorization.
            let notificationSettings = UserNotificationSettings(
                authorizationStatus: .authorized,
                soundEnabled: true
            )
            completionHandler(notificationSettings)
            return
        }

        UNUserNotificationCenter.current().getNotificationSettings { authorizationSettings in
            let authorizationStatus: AuthorizationStatus
            switch authorizationSettings.authorizationStatus {
            case .notDetermined:
                authorizationStatus = .notDetermined
            case .provisional:
                authorizationStatus = .provisional
            case .authorized:
                authorizationStatus = .authorized
            case .denied:
                authorizationStatus = .denied
            @unknown default:
                authorizationStatus = .denied
                os_log(
                    "User notification center did ignore unknown authorization status: %@",
                    log: .userNotificationCenter,
                    type: .debug,
                    String(reflecting: authorizationSettings.authorizationStatus)
                )
            }
            let notificationSettings = UserNotificationSettings(
                authorizationStatus: authorizationStatus,
                soundEnabled: authorizationSettings.soundSetting == .enabled
            )
            completionHandler(notificationSettings)
        }
    }

    /// Requests the user's authorization to allow notifications.
    ///
    /// - Parameter completionHandler: The block to execute asynchronously with
    ///     the authorization status. It may be executed on a background thread.
    /// - Note: Currently only authorization for sounds and alerts as well as
    ///     provisional notifications and badges are requested.
    @objc(requestAuthorizationWithCompletionHandler:)
    func requestAuthorization(completionHandler: @escaping (_ granted: Bool) -> Void) {
        guard #available(macOS 10.14, *) else {
            // NSNotificationCenter has no mechanism to request authorization.
            completionHandler(true)
            return
        }

        let center = UNUserNotificationCenter.current()
        // Provisional notifications and badges should always be requested.
        // Although Vienna uses NSDockTile to set the badge count instead of
        // the UNNotificationContent.badge property, the authorization is still
        // needed to show the badge setting in System Settings.
        let authorizationOptions: UNAuthorizationOptions = [.badge, .sound, .alert, .provisional]
        center.requestAuthorization(options: authorizationOptions) { granted, error in
            if let error {
                os_log(
                    "User notification center authorization request failed with error: %{public}@",
                    log: .userNotificationCenter,
                    type: .debug,
                    error.localizedDescription
                )
            }
            // `granted` is true when any options were granted; false when all
            // options were denied.
            completionHandler(granted)
        }
    }

    // MARK: Handling notifications

    @objc(addNotificationRequest:withCompletionHandler:)
    func add(
        _ request: UserNotificationRequest,
        withCompletionHandler completionHandler: ((_ error: (any Error)?) -> Void)? = nil
    ) {
        guard #available(macOS 10.14, *) else {
            let center = NSUserNotificationCenter.default
            center.add(request, withCompletionHandler: completionHandler)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = request.title
        if let subtitle = request.subtitle {
            content.subtitle = subtitle
        }
        if let body = request.body {
            content.body = body
        }
        if let userInfo = request.userInfo {
            content.userInfo = userInfo
        }
        if let threadIdentifier = request.threadIdentifier {
            content.threadIdentifier = threadIdentifier
        }
        content.sound = request.playSound ? .default : nil
        let notificationRequest = UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(notificationRequest) { completionHandler?($0) }
    }

    @objc
    func getDeliveredNotifications(
        completionHandler: @escaping (_ notifications: [UserNotificationResponse]) -> Void
    ) {
        guard #available(macOS 10.14, *) else {
            let center = NSUserNotificationCenter.default
            center.getDeliveredNotifications(completionHandler: completionHandler)
            return
        }
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { notifications in
            let notifications = notifications.map { notification in
                let request = notification.request
                return UserNotificationResponse(
                    identifier: request.identifier,
                    threadIdentifier: request.content.threadIdentifier,
                    userInfo: request.content.userInfo
                )
            }
            completionHandler(notifications)
        }
    }

    @objc
    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        guard #available(macOS 10.14, *) else {
            let center = NSUserNotificationCenter.default
            center.removeDeliveredNotifications(withIdentifiers: identifiers)
            return
        }
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    // MARK: Delegate

    @objc weak var delegate: (any UserNotificationCenterDelegate)? {
        didSet {
            if #available(macOS 10.14, *) {
                UNUserNotificationCenter.current().delegate = self
            } else {
                NSUserNotificationCenter.default.delegate = self
            }
        }
    }

}

// MARK: - UNUserNotificationCenterDelegate

@available(macOS 10.14, *)
extension UserNotificationCenter: UNUserNotificationCenterDelegate {

    // Sent when the user responded to a notification.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer {
            completionHandler()
        }
        guard let delegate else {
            return
        }
        let request = response.notification.request
        let identifier = request.identifier
        let threadIdentifier = request.content.threadIdentifier
        let userInfo = request.content.userInfo as? [String: AnyHashable]
        let response = UserNotificationResponse(
            identifier: identifier,
            threadIdentifier: threadIdentifier,
            userInfo: userInfo
        )
        delegate.userNotificationCenter(self, didReceive: response)
    }

}

// MARK: - NSUserNotificationCenterDelegate (deprecated)

@available(macOS, deprecated: 10.14)
extension UserNotificationCenter: NSUserNotificationCenterDelegate {

    // Sent when the user responded to a notification.
    func userNotificationCenter(
        _ center: NSUserNotificationCenter,
        didActivate notification: NSUserNotification
    ) {
        guard let delegate else {
            return
        }
        guard let identifier = notification.identifier else {
            os_log(
                "User notification center did activate unhandled notification: %@",
                log: .userNotificationCenter,
                type: .debug,
                notification
            )
            return
        }
        let response = UserNotificationResponse(
            identifier: identifier,
            userInfo: notification.userInfo
        )
        delegate.userNotificationCenter(self, didReceive: response)
    }

}

// MARK: - NSUserNotificationCenter (deprecated)

@available(macOS, deprecated: 10.14)
extension NSUserNotificationCenter {

    fileprivate func add(
        _ request: UserNotificationRequest,
        withCompletionHandler completionHandler: ((_ error: (any Error)?) -> Void)? = nil
    ) {
        defer {
            completionHandler?(nil)
        }
        // Remove any previous notification with the same identifier to trigger
        // the presentation on delivery.
        if let notification = deliveredNotifications.first(where: { $0.identifier == request.identifier }) {
            removeDeliveredNotification(notification)
        }
        let notification = NSUserNotification()
        notification.identifier = request.identifier
        notification.userInfo = request.userInfo as? [String: Any]
        notification.title = request.title
        notification.subtitle = request.subtitle
        notification.informativeText = request.body
        notification.soundName = request.playSound ? NSUserNotificationDefaultSoundName : nil
        deliver(notification)
    }

    fileprivate func getDeliveredNotifications(
        completionHandler: @escaping (_ notifications: [UserNotificationResponse]) -> Void
    ) {
        let notifications = deliveredNotifications.compactMap { notification in
            guard let identifier = notification.identifier else {
                return nil as UserNotificationResponse?
            }
            return UserNotificationResponse(
                identifier: identifier,
                userInfo: notification.userInfo
            )
        }
        completionHandler(notifications)
    }

    fileprivate func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        for notification in deliveredNotifications {
            if let identifier = notification.identifier, identifiers.contains(identifier) {
                removeDeliveredNotification(notification)
            }
        }
    }

}

// MARK: -

extension OSLog {

    fileprivate static let userNotificationCenter = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "--",
        category: "UserNotificationCenter"
    )

}
