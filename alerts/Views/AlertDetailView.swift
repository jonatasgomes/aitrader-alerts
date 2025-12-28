//
//  AlertDetailView.swift
//  alerts
//
//  Detailed Alert View Modal
//

import SwiftUI

struct AlertDetailView: View {
    let alert: TradingAlert
    let onDismiss: () -> Void
    let onDelete: () -> Void
    let onMarkUnread: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @State private var showDeleteConfirm = false
    
    var body: some View {
        ZStack {
            // Background
            GradientBackground()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Main info card
                        mainInfoCard
                        
                        // Trading details
                        if alert.optionSymbol != nil || alert.percentChange != nil || alert.currentPrice != nil {
                            tradingDetailsCard
                        }
                        
                        // Metadata card
                        metadataCard
                        
                        // Actions
                        actionsView
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
        .alert("Delete Alert", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
                onDismiss()
            }
        } message: {
            Text("Are you sure you want to delete this alert? This action cannot be undone.")
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .secondary)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                    )
            }
            
            Spacer()
            
            Text("Alert Details")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(colorScheme == .dark ? .white : .primary)
            
            Spacer()
            
            // Placeholder for symmetry
            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding()
    }
    
    // MARK: - Main Info Card
    private var mainInfoCard: some View {
        VStack(spacing: 16) {
            // Type and Symbol
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(alert.type.color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Text(alert.type.emoji)
                        .font(.largeTitle)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.symbol)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                    
                    HStack(spacing: 8) {
                        Text(alert.type.rawValue)
                            .font(.system(size: 14, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(alert.type.color.opacity(0.2))
                            .foregroundColor(alert.type.color)
                            .cornerRadius(6)
                        
                        Text(alert.priority.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(alert.priority.color.opacity(0.2))
                            .foregroundColor(alert.priority.color)
                            .cornerRadius(6)
                    }
                }
                
                Spacer()
            }
            
            // Message
            Text(alert.message)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(4)
        }
        .glassCard()
    }
    
    // MARK: - Trading Details Card
    private var tradingDetailsCard: some View {
        VStack(spacing: 16) {
            Text("Trading Details")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let optionSymbol = alert.optionSymbol {
                    DetailCell(
                        icon: "doc.text.fill",
                        label: "Option",
                        value: formatOptionSymbol(optionSymbol),
                        color: .accentInfo
                    )
                }
                
                if let change = alert.percentChange {
                    DetailCell(
                        icon: change >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                        label: "Change",
                        value: String(format: "%+.1f%%", change),
                        color: change >= 0 ? .accentBuy : .accentSell
                    )
                }
                
                if let price = alert.currentPrice {
                    DetailCell(
                        icon: "dollarsign.circle.fill",
                        label: "Current",
                        value: String(format: "$%.2f", price),
                        color: .accentInfo
                    )
                }
                
                if let target = alert.targetPrice {
                    DetailCell(
                        icon: "target",
                        label: "Target",
                        value: String(format: "$%.2f", target),
                        color: .accentWarning
                    )
                }
            }
        }
        .glassCard()
    }
    
    // MARK: - Metadata Card
    private var metadataCard: some View {
        VStack(spacing: 12) {
            MetadataRow(
                icon: alert.source.icon,
                label: "Source",
                value: alert.source.displayName
            )
            
            Divider()
                .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
            
            MetadataRow(
                icon: "clock.fill",
                label: "Created",
                value: formatDate(alert.createdAt)
            )
            
            Divider()
                .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
            
            MetadataRow(
                icon: "number",
                label: "Alert ID",
                value: "#\(alert.id)"
            )
        }
        .glassCard()
    }
    
    // MARK: - Actions
    private var actionsView: some View {
        VStack(spacing: 12) {
            // Mark as Unread button - always visible since alert is marked read on open
            Button(action: {
                onMarkUnread()
                onDismiss()
            }) {
                HStack {
                    Image(systemName: "envelope.badge.fill")
                    Text("Mark as Unread")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.accentInfo)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentInfo.opacity(0.15))
                .cornerRadius(12)
            }
            
            Button(action: {
                showDeleteConfirm = true
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Delete Alert")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.accentSell)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentSell.opacity(0.15))
                .cornerRadius(12)
            }
        }
        .padding(.top, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Format OCC option symbol to readable format
    private func formatOptionSymbol(_ symbol: String) -> String {
        // OCC format: SYMBOL + YYMMDD + C/P + 8 digits strike
        // Example: SOFI270115C00030000 -> SOFI 30C Jan 15, 2027
        guard symbol.count >= 15 else { return symbol }
        
        // Extract underlying symbol (everything before the last 15 chars)
        let underlyingEnd = symbol.index(symbol.endIndex, offsetBy: -15)
        let underlying = String(symbol[..<underlyingEnd])
        
        let dateStart = symbol.index(symbol.endIndex, offsetBy: -15)
        let dateEnd = symbol.index(dateStart, offsetBy: 6)
        let dateStr = String(symbol[dateStart..<dateEnd])
        
        let typeIndex = symbol.index(symbol.endIndex, offsetBy: -9)
        let optionType = String(symbol[typeIndex])
        
        let strikeStart = symbol.index(symbol.endIndex, offsetBy: -8)
        let strikeStr = String(symbol[strikeStart...])
        
        if let strikeValue = Double(strikeStr) {
            let strike = Int(strikeValue / 1000)
            
            // Parse YYMMDD format
            let yearStr = String(dateStr.prefix(2))
            let monthStr = String(dateStr.dropFirst(2).prefix(2))
            let dayStr = String(dateStr.suffix(2))
            
            // Convert to full year (20XX)
            let year = 2000 + (Int(yearStr) ?? 0)
            let month = Int(monthStr) ?? 1
            let day = Int(dayStr) ?? 1
            
            // Get month abbreviation
            let monthNames = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", 
                             "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            let monthName = month >= 1 && month <= 12 ? monthNames[month] : "???"
            
            return "\(underlying) \(strike)\(optionType) \(monthName) \(day), \(year)"
        }
        
        return symbol
    }
}

// MARK: - Detail Cell
struct DetailCell: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .secondary)
            }
            
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(colorScheme == .dark ? .white : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
        .cornerRadius(10)
    }
}

// MARK: - Metadata Row
struct MetadataRow: View {
    let icon: String
    let label: String
    let value: String
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.accentInfo)
                .frame(width: 24)
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : .primary)
        }
    }
}

#Preview {
    AlertDetailView(
        alert: TradingAlert(
            id: 1,
            symbol: "SPY",
            message: "Your SPY 600C 01/17 is now 50% profitable - Consider taking profits on this position to lock in gains",
            type: .sell,
            priority: .high,
            source: .tradingBot,
            isRead: true,
            optionSymbol: "SPY250117C00600000",
            percentChange: 50.0,
            currentPrice: 12.50,
            targetPrice: 15.00
        ),
        onDismiss: {},
        onDelete: {},
        onMarkUnread: {}
    )
    .preferredColorScheme(.dark)
}
