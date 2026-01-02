//
//  Alert.swift
//  alerts
//
//  Trading Alert Model
//

import Foundation

enum AlertType: String, Codable, CaseIterable {
    case buy = "BUY"
    case sell = "SELL"
    case warning = "WARNING"
    case info = "INFO"
    
    var emoji: String {
        switch self {
        case .buy: return "📈"
        case .sell: return "📉"
        case .warning: return "⚠️"
        case .info: return "ℹ️"
        }
    }
}

enum AlertPriority: String, Codable, CaseIterable {
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"
    
    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
}

enum AlertSource: String, Codable, CaseIterable {
    case screener = "SCREENER"
    case scalper = "SCALPER"
    case tradingBot = "TRADING_BOT"
    case manual = "MANUAL"
    
    var displayName: String {
        switch self {
        case .screener: return "Screener"
        case .scalper: return "Scalper"
        case .tradingBot: return "Trading Bot"
        case .manual: return "Manual"
        }
    }
    
    var icon: String {
        switch self {
        case .screener: return "magnifyingglass.circle.fill"
        case .scalper: return "bolt.circle.fill"
        case .tradingBot: return "cpu.fill"
        case .manual: return "hand.raised.circle.fill"
        }
    }
}

struct TradingAlert: Identifiable, Codable, Equatable {
    let id: Int
    let symbol: String
    let message: String
    let type: AlertType
    let priority: AlertPriority
    let source: AlertSource
    let createdAt: Date
    let updatedAt: Date?
    var isRead: Bool
    
    // Optional trading details
    let symbolType: String?  // "stock" or "option"
    let optionSymbol: String?
    let percentChange: Double?
    let currentPrice: Double?
    let targetPrice: Double?
    
    init(
        id: Int,
        symbol: String,
        message: String,
        type: AlertType,
        priority: AlertPriority,
        source: AlertSource,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        isRead: Bool = false,
        symbolType: String? = nil,
        optionSymbol: String? = nil,
        percentChange: Double? = nil,
        currentPrice: Double? = nil,
        targetPrice: Double? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.message = message
        self.type = type
        self.priority = priority
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isRead = isRead
        self.symbolType = symbolType
        self.optionSymbol = optionSymbol
        self.percentChange = percentChange
        self.currentPrice = currentPrice
        self.targetPrice = targetPrice
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}
