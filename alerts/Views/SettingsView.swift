//
//  SettingsView.swift
//  alerts
//
//  App Settings
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("pollingInterval") private var pollingInterval: Double = 30
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("vibrationEnabled") private var vibrationEnabled = true
    
    var body: some View {
        NavigationView {
            ZStack {
                GradientBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Notifications Section
                        settingsSection(title: "Notifications") {
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "bell.badge.fill")
                                        .foregroundColor(.accentInfo)
                                        .frame(width: 24)
                                    
                                    Text("Push Notifications")
                                        .font(.system(size: 15, weight: .medium))
                                    
                                    Spacer()
                                    
                                    if notificationManager.isAuthorized {
                                        Text("Enabled")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.accentBuy)
                                    } else {
                                        Button("Enable") {
                                            notificationManager.requestAuthorization()
                                        }
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.accentWarning)
                                    }
                                }
                                
                                Divider()
                                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                                
                                Toggle(isOn: $soundEnabled) {
                                    HStack {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .foregroundColor(.accentInfo)
                                            .frame(width: 24)
                                        Text("Sound")
                                            .font(.system(size: 15, weight: .medium))
                                    }
                                }
                                .tint(.accentBuy)
                                
                                Divider()
                                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                                
                                Toggle(isOn: $vibrationEnabled) {
                                    HStack {
                                        Image(systemName: "iphone.radiowaves.left.and.right")
                                            .foregroundColor(.accentInfo)
                                            .frame(width: 24)
                                        Text("Vibration")
                                            .font(.system(size: 15, weight: .medium))
                                    }
                                }
                                .tint(.accentBuy)
                            }
                        }
                        
                        // Data Source Section
                        settingsSection(title: "Data Source") {
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "cloud.fill")
                                        .foregroundColor(.accentInfo)
                                        .frame(width: 24)
                                    
                                    Text("Database")
                                        .font(.system(size: 15, weight: .medium))
                                    
                                    Spacer()
                                    
                                    Text("Mock Data")
                                        .font(.system(size: 13, weight: .semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.accentWarning.opacity(0.2))
                                        .foregroundColor(.accentWarning)
                                        .cornerRadius(6)
                                }
                                
                                Divider()
                                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "clock.fill")
                                            .foregroundColor(.accentInfo)
                                            .frame(width: 24)
                                        
                                        Text("Polling Interval")
                                            .font(.system(size: 15, weight: .medium))
                                        
                                        Spacer()
                                        
                                        Text("\(Int(pollingInterval))s")
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundColor(.accentInfo)
                                    }
                                    
                                    Slider(value: $pollingInterval, in: 10...120, step: 10)
                                        .tint(.accentBuy)
                                }
                            }
                        }
                        
                        // About Section
                        settingsSection(title: "About") {
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.accentInfo)
                                        .frame(width: 24)
                                    
                                    Text("Version")
                                        .font(.system(size: 15, weight: .medium))
                                    
                                    Spacer()
                                    
                                    Text("1.0.0")
                                        .font(.system(size: 14))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                                }
                                
                                Divider()
                                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                                
                                HStack {
                                    Image(systemName: "swift")
                                        .foregroundColor(.orange)
                                        .frame(width: 24)
                                    
                                    Text("Built with SwiftUI")
                                        .font(.system(size: 15, weight: .medium))
                                    
                                    Spacer()
                                }
                            }
                        }
                        
                        // Oracle Connection Status (placeholder)
                        settingsSection(title: "Oracle Cloud Database") {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "externaldrive.connected.to.line.below.fill")
                                        .foregroundColor(.accentWarning)
                                        .frame(width: 24)
                                    
                                    Text("Connection Status")
                                        .font(.system(size: 15, weight: .medium))
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.accentWarning)
                                            .frame(width: 8, height: 8)
                                        Text("Not Configured")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.accentWarning)
                                    }
                                }
                                
                                Text("Oracle Cloud 23ai database connection will be configured in a future update.")
                                    .font(.system(size: 12))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.accentBuy)
                }
            }
        }
    }
    
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .secondary)
                .padding(.leading, 4)
            
            content()
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 1)
                )
        }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
