//
//  BackgroundTaskManager.swift
//  alerts
//
//  Manages Background App Refresh for periodic alert sync
//

import Foundation
import BackgroundTasks
import UIKit

final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    // Task identifier - must match Info.plist BGTaskSchedulerPermittedIdentifiers
    private let refreshTaskIdentifier = "com.aitrader.alerts.refresh"
    
    // Minimum interval between background fetches (iOS may delay longer)
    private let minimumFetchInterval: TimeInterval = 15 * 60 // 15 minutes
    
    private init() {}
    
    // MARK: - Registration
    
    /// Register background tasks - call this in AppDelegate didFinishLaunching
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: refreshTaskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        print("📋 Background tasks registered")
    }
    
    // MARK: - Scheduling
    
    /// Schedule the next background refresh - call when app enters background
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: minimumFetchInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📋 Background refresh scheduled for ~\(Int(minimumFetchInterval/60)) minutes from now")
        } catch {
            print("❌ Could not schedule app refresh: \(error.localizedDescription)")
        }
    }
    
    /// Cancel any pending background tasks
    func cancelPendingTasks() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        print("📋 Cancelled pending background tasks")
    }
    
    // MARK: - Task Handling
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        print("📋 Background refresh starting...")
        
        // Schedule the next refresh before we do any work
        scheduleAppRefresh()
        
        // Create a task to fetch alerts
        let fetchTask = Task {
            do {
                let alerts = try await fetchAlertsInBackground()
                let unreadCount = alerts.filter { !$0.isRead }.count
                
                // Update the badge
                await MainActor.run {
                    NotificationManager.shared.updateBadge(count: unreadCount)
                }
                
                print("📋 Background refresh complete: \(unreadCount) unread alerts")
                task.setTaskCompleted(success: true)
            } catch {
                print("❌ Background refresh failed: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
        }
        
        // Handle task expiration
        task.expirationHandler = {
            fetchTask.cancel()
            print("⚠️ Background refresh expired")
        }
    }
    
    // MARK: - Background Fetch
    
    private func fetchAlertsInBackground() async throws -> [TradingAlert] {
        // Build the fetch request
        let baseURL = UserDefaults.standard.string(forKey: "oracle_base_url")?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "https://g12bbd4aea16cc4-orcl1.adb.ca-toronto-1.oraclecloudapps.com/ords/aitrader/alerts"
        
        let urlString = "\(baseURL)/all"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 25 // Background tasks have limited time
        
        // Add auth if configured
        let username = UserDefaults.standard.string(forKey: "oracle_username") ?? ""
        let password = UserDefaults.standard.string(forKey: "oracle_password") ?? ""
        
        if !username.isEmpty && !password.isEmpty {
            let credentials = "\(username):\(password)"
            if let credentialData = credentials.data(using: .utf8) {
                let base64Credentials = credentialData.base64EncodedString()
                request.addValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            }
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // Parse the response
        let decoder = JSONDecoder()
        let oracleResponse = try decoder.decode(OracleAlertsResponse.self, from: data)
        
        // Convert to TradingAlert (simplified - just need read status)
        return oracleResponse.items.map { oracleAlert in
            TradingAlert(
                id: oracleAlert.id,
                symbol: oracleAlert.underlying,
                message: oracleAlert.alertText,
                type: .info,
                priority: .low,
                source: .manual,
                isRead: oracleAlert.status.uppercased() == "READ"
            )
        }
    }
}

// MARK: - Debug Helper

extension BackgroundTaskManager {
    /// Debug: Simulate a background fetch (for testing in debugger)
    /// Run this in lldb: e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.aitrader.alerts.refresh"]
    func debugSimulateRefresh() {
        print("📋 To simulate background refresh, run this in Xcode debugger:")
        print("e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@\"com.aitrader.alerts.refresh\"]")
    }
}
