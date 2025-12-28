//
//  AlertListView.swift
//  alerts
//
//  Main Alert List Screen
//

import SwiftUI

struct AlertListView: View {
    @StateObject private var alertService = OracleAlertService()
    @StateObject private var notificationManager = NotificationManager.shared
    
    @State private var selectedAlert: TradingAlert?
    @State private var showSettings = false
    @State private var filterType: AlertType?
    @State private var filterSource: AlertSource?
    @State private var searchText = ""
    
    @Environment(\.colorScheme) var colorScheme
    
    var filteredAlerts: [TradingAlert] {
        var result = alertService.alerts
        
        if let type = filterType {
            result = result.filter { $0.type == type }
        }
        
        if let source = filterSource {
            result = result.filter { $0.source == source }
        }
        
        if !searchText.isEmpty {
            result = result.filter {
                $0.symbol.localizedCaseInsensitiveContains(searchText) ||
                $0.message.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    var body: some View {
        ZStack {
            GradientBackground()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Filters
                filterBar
                
                // Error banner
                if let error = alertService.errorMessage {
                    errorBanner(message: error)
                }
                
                // Alert list
                if alertService.isLoading && alertService.alerts.isEmpty {
                    loadingView
                } else if filteredAlerts.isEmpty {
                    emptyStateView
                } else {
                    alertListContent
                }
            }
        }
        .sheet(item: $selectedAlert) { alert in
            AlertDetailView(
                alert: alert,
                onDismiss: { selectedAlert = nil },
                onDelete: {
                    Task {
                        await alertService.deleteAlert(alert)
                    }
                },
                onMarkUnread: {
                    Task {
                        await alertService.markAsUnread(alert)
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .onAppear {
                // Mark as read when viewing details
                if !alert.isRead {
                    Task {
                        await alertService.markAsRead(alert)
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            notificationManager.requestAuthorization()
            notificationManager.setupNotificationCategories()
            alertService.startPolling()
        }
        .onDisappear {
            alertService.stopPolling()
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trading Alerts")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                    
                    Text("\(alertService.unreadCount) unread")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.accentBuy)
                }
                
                Spacer()
                
                // Refresh button
                Button(action: {
                    Task {
                        await alertService.fetchAlerts()
                    }
                }) {
                    Image(systemName: alertService.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.system(size: 18))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .secondary)
                        .padding(12)
                        .background(
                            Circle()
                                .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        )
                        .rotationEffect(.degrees(alertService.isLoading ? 360 : 0))
                        .animation(alertService.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: alertService.isLoading)
                }
                .disabled(alertService.isLoading)
                
                // Settings button
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .secondary)
                        .padding(12)
                        .background(
                            Circle()
                                .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        )
                }
            }
            
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .secondary)
                
                TextField("Search alerts...", text: $searchText)
                    .font(.system(size: 16))
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
            )
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
    
    // MARK: - Filter Bar
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Type filters
                ForEach(AlertType.allCases, id: \.self) { type in
                    FilterChip(
                        label: "\(type.emoji) \(type.rawValue)",
                        isSelected: filterType == type,
                        color: type.color
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            filterType = filterType == type ? nil : type
                        }
                    }
                }
                
                Divider()
                    .frame(height: 24)
                    .padding(.horizontal, 4)
                
                // Source filters
                ForEach(AlertSource.allCases, id: \.self) { source in
                    FilterChip(
                        label: source.displayName,
                        isSelected: filterSource == source,
                        color: .accentInfo
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            filterSource = filterSource == source ? nil : source
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 12)
    }
    
    // MARK: - Error Banner
    private func errorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.accentWarning)
            
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
            
            Spacer()
            
            Button(action: {
                Task {
                    await alertService.fetchAlerts()
                }
            }) {
                Text("Retry")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.accentBuy)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.accentWarning.opacity(0.2))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
                .tint(.accentInfo)
            
            Text("Loading alerts...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Alert List
    private var alertListContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredAlerts) { alert in
                    AlertCardView(
                        alert: alert,
                        onTap: {
                            selectedAlert = alert
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .slide.combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
        .refreshable {
            await alertService.fetchAlerts()
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.accentInfo.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.accentInfo.opacity(0.5))
            }
            
            Text("No Alerts")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(colorScheme == .dark ? .white : .primary)
            
            Text("Your trading bots haven't generated any alerts yet.\nThey'll appear here when triggered.")
                .font(.system(size: 15))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? color.opacity(0.2) : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)))
                )
                .foregroundColor(isSelected ? color : (colorScheme == .dark ? .white.opacity(0.7) : .secondary))
                .overlay(
                    Capsule()
                        .stroke(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        }
    }
}

#Preview {
    AlertListView()
        .preferredColorScheme(.dark)
}
