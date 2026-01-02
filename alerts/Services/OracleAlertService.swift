//
//  OracleAlertService.swift
//  alerts
//
//  Oracle Cloud Database Service for Trading Alerts
//

import Foundation
import Combine

// MARK: - Oracle Alert Response Models
struct OracleAlertsResponse: Codable {
    let items: [OracleAlert]
}

struct OracleAlert: Codable {
    let id: Int
    let alertText: String
    let alertSource: String
    let symbol: String
    let symbolType: String
    let underlying: String
    let score: String
    let status: String
    let userAction: String?
    let createdAt: String
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case alertText = "alert_text"
        case alertSource = "alert_source"
        case symbol
        case symbolType = "symbol_type"
        case underlying
        case score
        case status
        case userAction = "user_action"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Alert Service Protocol
protocol AlertServiceProtocol {
    var alerts: [TradingAlert] { get }
    var alertsPublisher: Published<[TradingAlert]>.Publisher { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    func fetchAlerts() async
    func startPolling()
    func stopPolling()
    func markAsRead(_ alert: TradingAlert) async
    func deleteAlert(_ alert: TradingAlert) async
}

// MARK: - Last Screening Response
struct LastScreeningResponse: Codable {
    let items: [LastScreeningItem]
}

struct LastScreeningItem: Codable {
    let lastScreening: String
    
    enum CodingKeys: String, CodingKey {
        case lastScreening = "last_screening"
    }
}

// MARK: - Oracle Alert Service
class OracleAlertService: ObservableObject, AlertServiceProtocol {
    @Published var alerts: [TradingAlert] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var pollingState: LongPollingState = .idle
    @Published private(set) var lastScreeningDate: Date?
    
    var alertsPublisher: Published<[TradingAlert]>.Publisher { $alerts }
    
    // Long-polling service replaces timer-based polling
    private var longPollingService: LongPollingService?
    
    // Oracle REST Data Services (ORDS) Configuration
    // Default to the actual ORDS endpoint
    private var baseURL: String {
        UserDefaults.standard.string(forKey: "oracle_base_url")?.trimmingCharacters(in: .whitespacesAndNewlines) 
            ?? "https://g12bbd4aea16cc4-orcl1.adb.ca-toronto-1.oraclecloudapps.com/ords/aitrader/alerts"
    }
    
    private var username: String {
        UserDefaults.standard.string(forKey: "oracle_username") ?? ""
    }
    
    private var password: String {
        UserDefaults.standard.string(forKey: "oracle_password") ?? ""
    }
    
    init() {
        // Fetch alerts on init
        Task {
            await fetchAlerts()
        }
    }
    
    // MARK: - Fetch Alerts
    @MainActor
    func fetchAlerts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch alerts and last screening time concurrently
            async let alertsFetch = performFetch()
            async let screeningFetch = fetchLastScreeningDate()
            
            let fetchedAlerts = try await alertsFetch
            self.alerts = fetchedAlerts
            
            // Update last screening date (don't fail if this errors)
            if let screeningDate = try? await screeningFetch {
                self.lastScreeningDate = screeningDate
            }
            
            print("✅ Fetched \(fetchedAlerts.count) alerts from Oracle")
            
            // Sync badge count with unread alerts
            updateBadgeCount()
        } catch {
            errorMessage = "Failed to fetch alerts: \(error.localizedDescription)"
            print("❌ Error fetching alerts: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Fetch Last Screening Date
    private func fetchLastScreeningDate() async throws -> Date? {
        let urlString = "\(baseURL)/changes/last_screening"
        
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        addAuthHeader(to: &request)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }
        
        let decoder = JSONDecoder()
        let screeningResponse = try decoder.decode(LastScreeningResponse.self, from: data)
        
        guard let firstItem = screeningResponse.items.first else {
            return nil
        }
        
        return parseDate(firstItem.lastScreening)
    }
    
    private func performFetch() async throws -> [TradingAlert] {
        // Use the /all endpoint to get all alerts
        let urlString = "\(baseURL)/all"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        
        // Add Basic Auth if credentials are provided
        addAuthHeader(to: &request)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            print("❌ HTTP Error: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
            }
            throw URLError(.init(rawValue: httpResponse.statusCode))
        }
        
        let decoder = JSONDecoder()
        let oracleResponse = try decoder.decode(OracleAlertsResponse.self, from: data)
        
        // Convert and sort alerts
        var tradingAlerts = oracleResponse.items.compactMap { convertToTradingAlert($0) }
        
        // Sort by priority first, then by date (newest first)
        tradingAlerts.sort { a, b in
            if a.priority.sortOrder != b.priority.sortOrder {
                return a.priority.sortOrder < b.priority.sortOrder
            }
            return a.createdAt > b.createdAt
        }
        
        return tradingAlerts
    }
    
    // MARK: - Convert Oracle Alert to TradingAlert
    private func convertToTradingAlert(_ oracleAlert: OracleAlert) -> TradingAlert? {
        // Parse ISO 8601 timestamp
        let date = parseDate(oracleAlert.createdAt) ?? Date()
        
        // Parse updated_at if present
        let updatedDate: Date? = oracleAlert.updatedAt.flatMap { parseDate($0) }
        
        // Map Oracle source to AlertSource
        let source: AlertSource
        switch oracleAlert.alertSource.uppercased() {
        case "SCREENER_BOT", "SCREENER":
            source = .screener
        case "SCALPER", "SCALPER_BOT":
            source = .scalper
        case "TRADING_BOT":
            source = .tradingBot
        default:
            source = .manual
        }
        
        // Map score to priority
        let priority: AlertPriority
        switch oracleAlert.score.uppercased() {
        case "HIGH":
            priority = .high
        case "MEDIUM":
            priority = .medium
        default:
            priority = .low
        }
        
        // Determine alert type from symbol type and alert text
        let alertType: AlertType
        let alertTextLower = oracleAlert.alertText.lowercased()
        if alertTextLower.contains("sell") || alertTextLower.contains("profit") || alertTextLower.contains("overbought") || alertTextLower.contains("rip") {
            alertType = .sell
        } else if alertTextLower.contains("buy") || alertTextLower.contains("dip") || alertTextLower.contains("entry") {
            alertType = .buy
        } else if alertTextLower.contains("warning") || alertTextLower.contains("stop") || alertTextLower.contains("loss") {
            alertType = .warning
        } else {
            alertType = .info
        }
        
        // Determine if read status
        let isRead = oracleAlert.status.uppercased() == "READ"
        
        return TradingAlert(
            id: oracleAlert.id,
            symbol: oracleAlert.underlying,
            message: oracleAlert.alertText,
            type: alertType,
            priority: priority,
            source: source,
            createdAt: date,
            updatedAt: updatedDate,
            isRead: isRead,
            symbolType: oracleAlert.symbolType.lowercased(),
            optionSymbol: oracleAlert.symbol,
            percentChange: extractPercentChange(from: oracleAlert.alertText),
            currentPrice: nil,
            targetPrice: nil
        )
    }
    
    // Parse various date formats
    private func parseDate(_ dateString: String) -> Date? {
        let formatters: [DateFormatter] = {
            let iso8601 = DateFormatter()
            iso8601.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
            iso8601.locale = Locale(identifier: "en_US_POSIX")
            
            let iso8601Short = DateFormatter()
            iso8601Short.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            iso8601Short.locale = Locale(identifier: "en_US_POSIX")
            
            let iso8601NoTZ = DateFormatter()
            iso8601NoTZ.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
            iso8601NoTZ.locale = Locale(identifier: "en_US_POSIX")
            iso8601NoTZ.timeZone = TimeZone(identifier: "UTC")
            
            return [iso8601, iso8601Short, iso8601NoTZ]
        }()
        
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        // Try ISO8601DateFormatter as fallback
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        isoFormatter.formatOptions = [.withInternetDateTime]
        return isoFormatter.date(from: dateString)
    }
    
    // Extract percent change from alert text if present
    private func extractPercentChange(from text: String) -> Double? {
        // Look for patterns like "-20%", "+15%", "down 20%", "up 15%"
        let patterns = [
            "(-?\\d+\\.?\\d*)%",
            "down (\\d+\\.?\\d*)%?",
            "up (\\d+\\.?\\d*)%?"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    if let valueRange = Range(match.range(at: 1), in: text) {
                        let valueStr = String(text[valueRange])
                        if var value = Double(valueStr) {
                            // Make negative if "down"
                            if text.lowercased().contains("down") && value > 0 {
                                value = -value
                            }
                            return value
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Long Polling
    func startPolling() {
        stopPolling() // Clear any existing service
        
        // Create and configure the long-polling service
        longPollingService = LongPollingService(baseURL: baseURL)
        longPollingService?.delegate = self
        longPollingService?.start()
        
        print("📡 Started long-polling service")
    }
    
    func stopPolling() {
        longPollingService?.stop()
        longPollingService = nil
    }
    
    /// Force a refresh of the long-polling connection
    func refreshPolling() {
        longPollingService?.refresh()
    }
    
    // MARK: - Mark as Read
    @MainActor
    func markAsRead(_ alert: TradingAlert) async {
        // Skip if already read
        guard !alert.isRead else { return }
        
        // Optimistic update
        if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
            alerts[index].isRead = true
        }
        
        // Update in database using PUT /alert/{id}
        do {
            try await updateAlertStatus(id: alert.id, status: "READ")
            print("✅ Marked alert \(alert.id) as read")
            updateBadgeCount()
        } catch {
            print("❌ Error marking alert as read: \(error)")
            // Revert optimistic update on failure
            if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
                alerts[index].isRead = false
            }
        }
    }
    
    // MARK: - Mark as Unread
    @MainActor
    func markAsUnread(_ alert: TradingAlert) async {
        // Always update - don't check alert.isRead since the alert object
        // is a snapshot and may be stale (e.g., was just marked as read on open)
        
        // Optimistic update
        if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
            alerts[index].isRead = false
        }
        
        // Update in database using PUT /alert/{id}
        do {
            try await updateAlertStatus(id: alert.id, status: "NEW")
            print("✅ Marked alert \(alert.id) as unread")
            updateBadgeCount()
        } catch {
            print("❌ Error marking alert as unread: \(error)")
            // Revert optimistic update on failure
            if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
                alerts[index].isRead = true
            }
        }
    }
    
    // MARK: - Delete Alert
    @MainActor
    func deleteAlert(_ alert: TradingAlert) async {
        // Optimistic update
        let removedAlert = alert
        let originalIndex = alerts.firstIndex(where: { $0.id == alert.id })
        alerts.removeAll { $0.id == alert.id }
        
        // Delete from database using DELETE /alert/{id}
        do {
            try await performDelete(id: alert.id)
            print("✅ Deleted alert \(alert.id)")
            updateBadgeCount()
        } catch {
            print("❌ Error deleting alert: \(error)")
            // Revert optimistic update on failure
            if let index = originalIndex {
                alerts.insert(removedAlert, at: min(index, alerts.count))
            } else {
                alerts.append(removedAlert)
            }
            sortAlerts()
        }
    }
    
    private func updateAlertStatus(id: Int, status: String) async throws {
        // PUT /alert/{id} with {"status": "READ"}
        let urlString = "\(baseURL)/alert/\(id)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        addAuthHeader(to: &request)
        
        let body: [String: Any] = ["status": status]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ Update failed with status \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
            }
            throw URLError(.init(rawValue: httpResponse.statusCode))
        }
    }
    
    private func performDelete(id: Int) async throws {
        // DELETE /alert/{id}
        let urlString = "\(baseURL)/alert/\(id)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        addAuthHeader(to: &request)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // 204 No Content is expected for successful delete
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.init(rawValue: httpResponse.statusCode))
        }
    }
    
    private func addAuthHeader(to request: inout URLRequest) {
        guard !username.isEmpty && !password.isEmpty else { return }
        let credentials = "\(username):\(password)"
        if let credentialData = credentials.data(using: .utf8) {
            let base64Credentials = credentialData.base64EncodedString()
            request.addValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }
    }
    
    private func sortAlerts() {
        alerts.sort { a, b in
            if a.priority.sortOrder != b.priority.sortOrder {
                return a.priority.sortOrder < b.priority.sortOrder
            }
            return a.createdAt > b.createdAt
        }
    }
    
    var unreadCount: Int {
        alerts.filter { !$0.isRead }.count
    }
    
    private func updateBadgeCount() {
        NotificationManager.shared.updateBadge(count: unreadCount)
    }
}

// MARK: - Long Polling Delegate
extension OracleAlertService: LongPollingDelegate {
    
    func longPollingDidDetectChanges() {
        // Server reported changes - fetch the updated alerts
        print("📡 Changes detected - refreshing alerts")
        Task { @MainActor in
            await fetchAlerts()
        }
    }
    
    func longPollingStateDidChange(_ state: LongPollingState) {
        // Update the published state for UI observation
        DispatchQueue.main.async { [weak self] in
            self?.pollingState = state
        }
        
        switch state {
        case .polling:
            print("📡 Long-polling: Active")
        case .reconnecting(let attempt):
            print("📡 Long-polling: Reconnecting (attempt \(attempt))")
        case .stopped:
            print("📡 Long-polling: Stopped")
        case .error(let message):
            print("❌ Long-polling error: \(message)")
        case .idle:
            break
        }
    }
    
    func longPollingDidEncounterError(_ error: Error) {
        // Log the error but don't surface to user - reconnection is automatic
        print("⚠️ Long-polling encountered error: \(error.localizedDescription)")
    }
    
    func longPollingDidResumeFromBackground() {
        // App returned from background - do a full refresh to catch any missed changes
        print("📡 Resuming from background - refreshing alerts")
        Task { @MainActor in
            await fetchAlerts()
        }
    }
}

// MARK: - Double Extension
extension Double {
    func clamped(to range: ClosedRange<Double>, `default` defaultValue: Double) -> Double {
        if self == 0 { return defaultValue }
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
