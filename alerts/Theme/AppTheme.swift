//
//  AppTheme.swift
//  alerts
//
//  Modern Glassmorphism Theme
//

import SwiftUI

// MARK: - Color Theme
extension Color {
    // Primary gradient colors
    static let gradientStart = Color(red: 0.1, green: 0.1, blue: 0.2)
    static let gradientEnd = Color(red: 0.05, green: 0.05, blue: 0.15)
    
    // Accent colors
    static let accentBuy = Color(red: 0.2, green: 0.8, blue: 0.5)
    static let accentSell = Color(red: 0.95, green: 0.4, blue: 0.4)
    static let accentWarning = Color(red: 1.0, green: 0.75, blue: 0.2)
    static let accentInfo = Color(red: 0.4, green: 0.7, blue: 1.0)
    
    // Glass colors
    static let glassBackground = Color.white.opacity(0.1)
    static let glassBorder = Color.white.opacity(0.2)
    static let glassHighlight = Color.white.opacity(0.05)
    
    // Priority colors
    static let priorityHigh = Color(red: 1.0, green: 0.3, blue: 0.3)
    static let priorityMedium = Color(red: 1.0, green: 0.7, blue: 0.2)
    static let priorityLow = Color(red: 0.5, green: 0.5, blue: 0.6)
}

// MARK: - Glass Card Modifier
struct GlassCard: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(colorScheme == .dark 
                          ? Color.white.opacity(0.08) 
                          : Color.black.opacity(0.05))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                colorScheme == .dark ? Color.white.opacity(0.3) : Color.white.opacity(0.8),
                                colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, padding: CGFloat = 16) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Gradient Background
struct GradientBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.08, blue: 0.15),
                        Color(red: 0.05, green: 0.05, blue: 0.1),
                        Color(red: 0.02, green: 0.02, blue: 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    // Ambient glow effects
                    ZStack {
                        Circle()
                            .fill(Color.accentBuy.opacity(0.15))
                            .frame(width: 300, height: 300)
                            .blur(radius: 80)
                            .offset(x: -100, y: -200)
                        
                        Circle()
                            .fill(Color.accentInfo.opacity(0.1))
                            .frame(width: 250, height: 250)
                            .blur(radius: 60)
                            .offset(x: 150, y: 400)
                    }
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.95, blue: 0.98),
                        Color(red: 0.9, green: 0.92, blue: 0.96),
                        Color(red: 0.85, green: 0.88, blue: 0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    ZStack {
                        Circle()
                            .fill(Color.accentBuy.opacity(0.08))
                            .frame(width: 300, height: 300)
                            .blur(radius: 80)
                            .offset(x: -100, y: -200)
                        
                        Circle()
                            .fill(Color.accentInfo.opacity(0.06))
                            .frame(width: 250, height: 250)
                            .blur(radius: 60)
                            .offset(x: 150, y: 400)
                    }
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Alert Type Colors
extension AlertType {
    var color: Color {
        switch self {
        case .buy: return .accentBuy
        case .sell: return .accentSell
        case .warning: return .accentWarning
        case .info: return .accentInfo
        }
    }
    
    var gradient: LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Priority Badge Colors
extension AlertPriority {
    var color: Color {
        switch self {
        case .high: return .priorityHigh
        case .medium: return .priorityMedium
        case .low: return .priorityLow
        }
    }
}

// MARK: - Shimmer Animation
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                    .animation(
                        Animation.linear(duration: 1.5).repeatForever(autoreverses: false),
                        value: phase
                    )
                }
            )
            .clipped()
            .onAppear {
                phase = 1
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}
