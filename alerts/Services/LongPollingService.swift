//
//  LongPollingService.swift
//  alerts
//
//  Long-Polling Service for Real-time Alert Changes
//  Replaces timer-based polling with server-side long-polling
//

import Foundation
import UIKit
import Combine

// MARK: - Long Poll Response

/// Response from the changes endpoint
struct LongPollResponse: Codable {
    let hasChanges: Bool
    let lastUpdated: String?
    let changeCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case hasChanges = "has_changes"
        case lastUpdated = "last_updated"
        case changeCount = "change_count"
    }
}

// MARK: - Long Polling State

enum LongPollingState: Equatable {
    case idle
    case polling
    case reconnecting(attempt: Int)
    case stopped
    case error(String)
    
    static func == (lhs: LongPollingState, rhs: LongPollingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.polling, .polling), (.stopped, .stopped):
            return true
        case (.reconnecting(let a), .reconnecting(let b)):
            return a == b
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - Long Polling Delegate

protocol LongPollingDelegate: AnyObject {
    /// Called when changes are detected on the server
    func longPollingDidDetectChanges()
    
    /// Called when the connection state changes
    func longPollingStateDidChange(_ state: LongPollingState)
    
    /// Called when an error occurs (for logging/debugging)
    func longPollingDidEncounterError(_ error: Error)
    
    /// Called when the app resumes from background - should trigger a full data refresh
    func longPollingDidResumeFromBackground()
}

// MARK: - Long Polling Service

final class LongPollingService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var state: LongPollingState = .idle
    @Published private(set) var lastChangeTimestamp: String?
    
    // MARK: - Configuration
    
    private let baseURL: String
    private let requestTimeout: TimeInterval = 90  // Long timeout for server hold
    private let maxBackoffInterval: TimeInterval = 30
    private let initialBackoffInterval: TimeInterval = 1
    
    // MARK: - Private Properties
    
    private var currentTask: URLSessionDataTask?
    private var isActive = false
    private var currentBackoff: TimeInterval = 1
    private var urlSession: URLSession?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    weak var delegate: LongPollingDelegate?
    
    // Authentication (optional)
    private var username: String {
        UserDefaults.standard.string(forKey: "oracle_username") ?? ""
    }
    
    private var password: String {
        UserDefaults.standard.string(forKey: "oracle_password") ?? ""
    }
    
    // MARK: - Initialization
    
    init(baseURL: String = "https://g12bbd4aea16cc4-orcl1.adb.ca-toronto-1.oraclecloudapps.com/ords/aitrader/alerts") {
        self.baseURL = baseURL
        setupURLSession()
        setupNotifications()
    }
    
    deinit {
        stop()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupURLSession() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = requestTimeout + 10
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        
        // Disable caching for real-time updates
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        
        urlSession = URLSession(configuration: config)
    }
    
    private func setupNotifications() {
        // Handle app lifecycle for safe background/foreground transitions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    // MARK: - Public Interface
    
    /// Start the long-polling service
    func start() {
        guard !isActive else {
            print("📡 LongPolling: Already active")
            return
        }
        
        isActive = true
        currentBackoff = initialBackoffInterval
        
        print("📡 LongPolling: Starting...")
        updateState(.polling)
        startLongPoll()
    }
    
    /// Stop the long-polling service
    func stop() {
        guard isActive else { return }
        
        isActive = false
        currentTask?.cancel()
        currentTask = nil
        
        endBackgroundTask()
        
        print("📡 LongPolling: Stopped")
        updateState(.stopped)
    }
    
    /// Check if the service is currently active
    var isRunning: Bool {
        return isActive
    }
    
    /// Force a new poll cycle (useful after local changes)
    func refresh() {
        guard isActive else { return }
        
        currentTask?.cancel()
        currentTask = nil
        currentBackoff = initialBackoffInterval
        
        startLongPoll()
    }
    
    // MARK: - Long Polling Logic
    
    private func startLongPoll() {
        guard isActive else { return }
        guard currentTask == nil else {
            print("📡 LongPolling: Request already in progress")
            return
        }
        
        // Build the changes endpoint URL with timestamp
        let timestamp = lastChangeTimestamp ?? currentTimestamp()
        let urlString = "\(baseURL)/changes/\(timestamp)"
        
        guard let url = URL(string: urlString) else {
            print("❌ LongPolling: Invalid URL - \(urlString)")
            updateState(.error("Invalid URL"))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = requestTimeout
        
        // Add Basic Auth if configured
        addAuthHeader(to: &request)
        
        print("📡 LongPolling: Starting request to \(urlString)")
        
        guard let session = urlSession else {
            print("❌ LongPolling: URLSession not configured")
            return
        }
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            self?.handleResponse(data: data, response: response, error: error)
        }
        
        currentTask = task
        task.resume()
    }
    
    private func handleResponse(data: Data?, response: URLResponse?, error: Error?) {
        currentTask = nil
        
        // Check if we're still active
        guard isActive else { return }
        
        // Handle errors
        if let error = error {
            handleError(error)
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            handleError(URLError(.badServerResponse))
            return
        }
        
        print("📡 LongPolling: Received response with status \(httpResponse.statusCode)")
        
        switch httpResponse.statusCode {
        case 200:
            // Changes detected or response received
            handleSuccessResponse(data: data)
            
        case 204:
            // No changes - immediately start new poll
            print("📡 LongPolling: No changes (204)")
            resetBackoff()
            DispatchQueue.main.async { [weak self] in
                self?.updateState(.polling)
                self?.startLongPoll()
            }
            
        case 304:
            // Not Modified - treat same as 204
            print("📡 LongPolling: Not modified (304)")
            resetBackoff()
            DispatchQueue.main.async { [weak self] in
                self?.updateState(.polling)
                self?.startLongPoll()
            }
            
        case 408, 504:
            // Request timeout or Gateway timeout - normal for long-polling
            print("📡 LongPolling: Timeout - restarting poll")
            resetBackoff()
            DispatchQueue.main.async { [weak self] in
                self?.startLongPoll()
            }
            
        case 429:
            // Rate limited - back off
            print("⚠️ LongPolling: Rate limited (429)")
            handleBackoff(isRateLimit: true)
            
        case 500...599:
            // Server error - retry with backoff
            print("❌ LongPolling: Server error (\(httpResponse.statusCode))")
            handleBackoff()
            
        default:
            print("❌ LongPolling: Unexpected status \(httpResponse.statusCode)")
            handleBackoff()
        }
    }
    
    private func handleSuccessResponse(data: Data?) {
        resetBackoff()
        
        // Try to parse the response
        if let data = data {
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(LongPollResponse.self, from: data)
                
                if let lastUpdated = response.lastUpdated {
                    lastChangeTimestamp = lastUpdated
                }
                
                if response.hasChanges {
                    print("📡 LongPolling: Changes detected!")
                    DispatchQueue.main.async { [weak self] in
                        self?.delegate?.longPollingDidDetectChanges()
                    }
                }
            } catch {
                // If parsing fails, assume changes occurred
                print("📡 LongPolling: Response parsed with fallback - assuming changes")
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.longPollingDidDetectChanges()
                }
            }
        } else {
            // No data but 200 - assume changes
            print("📡 LongPolling: 200 with no data - assuming changes")
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.longPollingDidDetectChanges()
            }
        }
        
        // Immediately start next poll
        DispatchQueue.main.async { [weak self] in
            self?.updateState(.polling)
            self?.startLongPoll()
        }
    }
    
    private func handleError(_ error: Error) {
        let nsError = error as NSError
        
        // Check if it's a cancellation (not an error)
        if nsError.code == NSURLErrorCancelled {
            print("📡 LongPolling: Request cancelled")
            return
        }
        
        print("❌ LongPolling: Error - \(error.localizedDescription)")
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.longPollingDidEncounterError(error)
        }
        
        // Handle specific network errors
        switch nsError.code {
        case NSURLErrorTimedOut:
            // Timeout is expected in long-polling - restart immediately
            print("📡 LongPolling: Request timed out - restarting")
            DispatchQueue.main.async { [weak self] in
                self?.startLongPoll()
            }
            
        case NSURLErrorNotConnectedToInternet,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorDataNotAllowed:
            // Network unavailable - retry with backoff
            print("⚠️ LongPolling: Network unavailable - backing off")
            handleBackoff()
            
        default:
            // Other errors - retry with backoff
            handleBackoff()
        }
    }
    
    // MARK: - Backoff Logic
    
    private func handleBackoff(isRateLimit: Bool = false) {
        guard isActive else { return }
        
        let attempt = Int(log2(currentBackoff / initialBackoffInterval)) + 1
        
        DispatchQueue.main.async { [weak self] in
            self?.updateState(.reconnecting(attempt: attempt))
        }
        
        // Calculate backoff with jitter
        let jitter = Double.random(in: 0...0.3) * currentBackoff
        let delay = min(currentBackoff + jitter, maxBackoffInterval)
        
        print("📡 LongPolling: Retry in \(String(format: "%.1f", delay))s (attempt \(attempt))")
        
        // Increase backoff for next time (exponential)
        currentBackoff = min(currentBackoff * 2, maxBackoffInterval)
        
        // Schedule retry without using Timer
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.isActive else { return }
            self.updateState(.polling)
            self.startLongPoll()
        }
    }
    
    private func resetBackoff() {
        currentBackoff = initialBackoffInterval
    }
    
    // MARK: - State Management
    
    private func updateState(_ newState: LongPollingState) {
        guard state != newState else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.state = newState
            self.delegate?.longPollingStateDidChange(newState)
        }
    }
    
    // MARK: - Background/Foreground Handling
    
    @objc private func appDidEnterBackground() {
        guard isActive else { return }
        
        print("📡 LongPolling: App entering background")
        
        // Start background task to allow current request to complete
        beginBackgroundTask()
        
        // Cancel current request - we'll resume when foregrounded
        // iOS doesn't allow long-running network in background
        currentTask?.cancel()
        currentTask = nil
    }
    
    @objc private func appWillEnterForeground() {
        guard isActive else { return }
        
        print("📡 LongPolling: App entering foreground")
        
        endBackgroundTask()
        
        // Notify delegate to do a full refresh (catches any changes that happened while in background)
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.longPollingDidResumeFromBackground()
        }
        
        // Resume polling
        currentBackoff = initialBackoffInterval
        updateState(.polling)
        startLongPoll()
    }
    
    @objc private func appWillTerminate() {
        stop()
    }
    
    private func beginBackgroundTask() {
        guard backgroundTask == .invalid else { return }
        
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
    
    // MARK: - Helpers
    
    private func currentTimestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
    
    private func addAuthHeader(to request: inout URLRequest) {
        guard !username.isEmpty && !password.isEmpty else { return }
        let credentials = "\(username):\(password)"
        if let credentialData = credentials.data(using: .utf8) {
            let base64Credentials = credentialData.base64EncodedString()
            request.addValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }
    }
}

// MARK: - Integration Example Extension

extension LongPollingService {
    
    /// Convenience method to integrate with OracleAlertService
    /// Call this from your main service's init
    static func createAndStart(delegate: LongPollingDelegate) -> LongPollingService {
        let service = LongPollingService()
        service.delegate = delegate
        service.start()
        return service
    }
}
