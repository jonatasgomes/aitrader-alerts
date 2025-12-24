//
//  MockAlertService.swift
//  alerts
//
//  Mock Database Service - To be replaced with Oracle Cloud DB
//

import Foundation
import Combine

protocol AlertServiceProtocol {
    var alerts: [TradingAlert] { get }
    var alertsPublisher: Published<[TradingAlert]>.Publisher { get }
    func startPolling()
    func stopPolling()
    func markAsRead(_ alert: TradingAlert)
    func markAllAsRead()
    func deleteAlert(_ alert: TradingAlert)
}

class MockAlertService: ObservableObject, AlertServiceProtocol {
    @Published var alerts: [TradingAlert] = []
    var alertsPublisher: Published<[TradingAlert]>.Publisher { $alerts }
    
    private var timer: Timer?
    private var mockAlertIndex = 0
    
    // Mock alerts that simulate real trading bot outputs
    private let mockAlertTemplates: [(String, String, AlertType, AlertPriority, AlertSource, String?, Double?)] = [
        ("IWM", "IWM call option 250C 01/17 is down 20% - Good entry point for LEAP position", .buy, .high, .screener, "IWM250117C00250000", -20.0),
        ("SPY", "Your SPY 600C 01/17 is now 50% profitable - Consider taking profits", .sell, .high, .tradingBot, "SPY250117C00600000", 50.0),
        ("SQQQ", "SQQQ showing bearish momentum - Scalping opportunity detected", .buy, .medium, .scalper, nil, -5.5),
        ("QQQ", "QQQ approaching resistance at $520 - Watch for reversal", .warning, .medium, .screener, nil, nil),
        ("TQQQ", "TQQQ call option 85C is down 15% from your entry - Hold or average down?", .info, .low, .tradingBot, "TQQQ250117C00085000", -15.0),
        ("NVDA", "NVDA unusual options activity detected - High volume on 150C weeklies", .info, .medium, .screener, "NVDA250103C00150000", nil),
        ("AMD", "AMD scalp trade triggered - Entry at $125.50, target $127.00", .buy, .high, .scalper, nil, nil),
        ("MSFT", "MSFT position hit stop loss at $420 - Exited with 3% loss", .warning, .high, .tradingBot, nil, -3.0),
        ("AAPL", "AAPL consolidating near $250 - Breakout imminent", .info, .low, .screener, nil, nil),
        ("TSLA", "TSLA put option 400P is up 35% - Take partial profits?", .sell, .medium, .tradingBot, "TSLA250117P00400000", 35.0),
    ]
    
    init() {
        // Load some initial alerts
        loadInitialAlerts()
    }
    
    private func loadInitialAlerts() {
        // Add 5 initial alerts with staggered times
        for i in 0..<5 {
            let template = mockAlertTemplates[i]
            let alert = TradingAlert(
                symbol: template.0,
                message: template.1,
                type: template.2,
                priority: template.3,
                source: template.4,
                createdAt: Date().addingTimeInterval(Double(-i * 300)), // Stagger by 5 minutes
                optionSymbol: template.5,
                percentChange: template.6
            )
            alerts.append(alert)
        }
        sortAlerts()
    }
    
    func startPolling() {
        // Simulate new alerts arriving every 30 seconds (for demo purposes)
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.generateNewAlert()
        }
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    private func generateNewAlert() {
        mockAlertIndex = (mockAlertIndex + 5) % mockAlertTemplates.count
        let template = mockAlertTemplates[mockAlertIndex]
        
        let alert = TradingAlert(
            symbol: template.0,
            message: template.1,
            type: template.2,
            priority: template.3,
            source: template.4,
            optionSymbol: template.5,
            percentChange: template.6
        )
        
        DispatchQueue.main.async {
            self.alerts.insert(alert, at: 0)
            
            // Trigger local notification
            NotificationManager.shared.sendLocalNotification(for: alert)
        }
    }
    
    func markAsRead(_ alert: TradingAlert) {
        if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
            alerts[index].isRead = true
        }
    }
    
    func markAllAsRead() {
        for i in alerts.indices {
            alerts[i].isRead = true
        }
    }
    
    func deleteAlert(_ alert: TradingAlert) {
        alerts.removeAll { $0.id == alert.id }
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
}
