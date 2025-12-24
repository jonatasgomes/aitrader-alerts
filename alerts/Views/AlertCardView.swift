//
//  AlertCardView.swift
//  alerts
//
//  Individual Alert Card Component
//

import SwiftUI

struct AlertCardView: View {
    let alert: TradingAlert
    let onTap: () -> Void
    let onSwipeDelete: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @State private var offset: CGFloat = 0
    @State private var isSwiping = false
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background
            HStack {
                Spacer()
                VStack {
                    Image(systemName: "trash.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text("Delete")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .frame(width: 80)
                .frame(maxHeight: .infinity)
                .background(Color.red.opacity(0.8))
            }
            .cornerRadius(20)
            
            // Main card content
            HStack(spacing: 12) {
                // Type indicator
                VStack {
                    ZStack {
                        Circle()
                            .fill(alert.type.color.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Text(alert.type.emoji)
                            .font(.title2)
                    }
                    
                    // Priority badge
                    Text(alert.priority.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(alert.priority.color.opacity(0.2))
                        .foregroundColor(alert.priority.color)
                        .cornerRadius(4)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Header row
                    HStack {
                        Text(alert.symbol)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                        
                        if let optionSymbol = alert.optionSymbol {
                            Text(formatOptionSymbol(optionSymbol))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentInfo.opacity(0.15))
                                .foregroundColor(.accentInfo)
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        if let change = alert.percentChange {
                            PercentChangeBadge(value: change)
                        }
                    }
                    
                    // Message
                    Text(alert.message)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Footer
                    HStack {
                        // Source badge
                        HStack(spacing: 4) {
                            Image(systemName: alert.source.icon)
                                .font(.system(size: 10))
                            Text(alert.source.displayName)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .secondary)
                        .cornerRadius(6)
                        
                        Spacer()
                        
                        // Timestamp
                        Text(alert.timeAgo)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .secondary)
                        
                        // Unread indicator
                        if !alert.isRead {
                            Circle()
                                .fill(Color.accentBuy)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            .glassCard(cornerRadius: 20, padding: 16)
            .overlay(
                // Left accent border
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(alert.type.gradient)
                        .frame(width: 4)
                        .padding(.vertical, 12)
                    Spacer()
                }
                .padding(.leading, 4)
            )
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if gesture.translation.width < 0 {
                            offset = gesture.translation.width
                            isSwiping = true
                        }
                    }
                    .onEnded { gesture in
                        withAnimation(.spring()) {
                            if gesture.translation.width < -100 {
                                offset = -1000
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onSwipeDelete()
                                }
                            } else {
                                offset = 0
                            }
                            isSwiping = false
                        }
                    }
            )
        }
        .onTapGesture {
            if !isSwiping {
                onTap()
            }
        }
    }
    
    // Format OCC option symbol to readable format
    private func formatOptionSymbol(_ symbol: String) -> String {
        // OCC format: SYMBOL + 6 digits date + C/P + 8 digits strike
        // Example: IWM250117C00250000 -> 250C 01/17
        guard symbol.count >= 15 else { return symbol }
        
        let dateStart = symbol.index(symbol.endIndex, offsetBy: -15)
        let dateEnd = symbol.index(dateStart, offsetBy: 6)
        let dateStr = String(symbol[dateStart..<dateEnd])
        
        let typeIndex = symbol.index(symbol.endIndex, offsetBy: -9)
        let optionType = String(symbol[typeIndex])
        
        let strikeStart = symbol.index(symbol.endIndex, offsetBy: -8)
        let strikeStr = String(symbol[strikeStart...])
        
        if let strikeValue = Double(strikeStr) {
            let strike = Int(strikeValue / 1000)
            let month = String(dateStr.prefix(2).suffix(2))
            let day = String(dateStr.suffix(2))
            return "\(strike)\(optionType) \(month)/\(day)"
        }
        
        return symbol
    }
}

// MARK: - Percent Change Badge
struct PercentChangeBadge: View {
    let value: Double
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .bold))
            Text(String(format: "%.1f%%", abs(value)))
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(value >= 0 ? Color.accentBuy.opacity(0.2) : Color.accentSell.opacity(0.2))
        .foregroundColor(value >= 0 ? .accentBuy : .accentSell)
        .cornerRadius(8)
    }
}

#Preview {
    ZStack {
        GradientBackground()
        VStack {
            AlertCardView(
                alert: TradingAlert(
                    symbol: "IWM",
                    message: "IWM call option 250C 01/17 is down 20% - Good entry point for LEAP position",
                    type: .buy,
                    priority: .high,
                    source: .screener,
                    optionSymbol: "IWM250117C00250000",
                    percentChange: -20.0
                ),
                onTap: {},
                onSwipeDelete: {}
            )
            .padding()
        }
    }
    .preferredColorScheme(.dark)
}
