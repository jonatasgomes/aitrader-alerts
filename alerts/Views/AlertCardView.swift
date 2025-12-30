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
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
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
        .onTapGesture {
            onTap()
        }
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
                    id: 1,
                    symbol: "IWM",
                    message: "IWM call option 250C 01/17 is down 20% - Good entry point for LEAP position",
                    type: .buy,
                    priority: .high,
                    source: .screener,
                    optionSymbol: "IWM250117C00250000",
                    percentChange: -20.0
                ),
                onTap: {}
            )
            .padding()
        }
    }
    .preferredColorScheme(.dark)
}
