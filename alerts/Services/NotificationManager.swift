//
//  NotificationManager.swift
//  alerts
//
//  Handles Local and Push Notifications
//

import Foundation
import Combine
import UserNotifications

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    
    override init() {
        super.init()
        checkAuthorization()
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted {
                    print("✅ Notification permission granted")
                } else if let error = error {
                    print("❌ Notification permission error: \(error.localizedDescription)")
                }
            }
        }
        
        // Set delegate for foreground notifications
        UNUserNotificationCenter.current().delegate = self
    }
    
    func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func sendLocalNotification(for alert: TradingAlert) {
        guard isAuthorized else {
            print("⚠️ Notifications not authorized")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "\(alert.type.emoji) \(alert.symbol) - \(alert.type.rawValue)"
        content.body = alert.message
        content.sound = alert.priority == .high ? .defaultCritical : .default
        content.badge = 1
        
        // Add category for actions
        content.categoryIdentifier = "TRADING_ALERT"
        
        // Add user info for handling tap
        content.userInfo = [
            "alertId": String(alert.id),
            "symbol": alert.symbol,
            "type": alert.type.rawValue
        ]
        
        // Immediate trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: String(alert.id),
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send notification: \(error.localizedDescription)")
            } else {
                print("📬 Notification sent for \(alert.symbol)")
            }
        }
    }
    
    func clearBadge() {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(0)
        }
    }
    
    func updateBadge(count: Int) {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(count)
        }
    }
    
    func setupNotificationCategories() {
        // Define actions for notifications
        let markReadAction = UNNotificationAction(
            identifier: "MARK_READ",
            title: "Mark as Read",
            options: []
        )
        
        let viewAction = UNNotificationAction(
            identifier: "VIEW",
            title: "View Details",
            options: .foreground
        )
        
        let category = UNNotificationCategory(
            identifier: "TRADING_ALERT",
            actions: [viewAction, markReadAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    // Show notification even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        if let alertId = userInfo["alertId"] as? String {
            print("📱 User tapped notification for alert: \(alertId)")
            // Post notification for app to handle navigation
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenAlert"),
                object: nil,
                userInfo: ["alertId": alertId]
            )
        }
        
        completionHandler()
    }
}
