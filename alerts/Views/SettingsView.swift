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
    
    // Oracle Configuration
    @AppStorage("oracle_base_url") private var oracleBaseURL = "https://g12bbd4aea16cc4-orcl1.adb.ca-toronto-1.oraclecloudapps.com/ords/aitrader/alerts"
    @AppStorage("oracle_username") private var oracleUsername = ""
    @State private var oraclePassword = ""
    @State private var showPassword = false
    @State private var connectionStatus: ConnectionStatus = .notConfigured
    @State private var isTestingConnection = false
    
    enum ConnectionStatus {
        case notConfigured
        case testing
        case connected
        case error(String)
        
        var color: Color {
            switch self {
            case .notConfigured: return .accentWarning
            case .testing: return .accentInfo
            case .connected: return .accentBuy
            case .error: return .accentSell
            }
        }
        
        var text: String {
            switch self {
            case .notConfigured: return "Not Configured"
            case .testing: return "Testing..."
            case .connected: return "Connected"
            case .error(let msg): return "Error: \(msg)"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                GradientBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Oracle Connection Section
                        settingsSection(title: "Oracle Cloud Database") {
                            VStack(spacing: 16) {
                                // Connection Status
                                HStack {
                                    Image(systemName: "externaldrive.connected.to.line.below.fill")
                                        .foregroundColor(connectionStatus.color)
                                        .frame(width: 24)
                                    
                                    Text("Connection Status")
                                        .font(.system(size: 15, weight: .medium))
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 4) {
                                        if case .testing = connectionStatus {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        } else {
                                            Circle()
                                                .fill(connectionStatus.color)
                                                .frame(width: 8, height: 8)
                                        }
                                        Text(connectionStatus.text)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(connectionStatus.color)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Divider()
                                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                                
                                // ORDS URL
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("ORDS Base URL")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                                    
                                    TextField("https://your-instance.oraclecloud.com/ords/schema", text: $oracleBaseURL)
                                        .font(.system(size: 14))
                                        .padding(12)
                                        .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                                        .cornerRadius(10)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .keyboardType(.URL)
                                }
                                
                                // Username
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Username (optional)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                                    
                                    TextField("ORDS_USER", text: $oracleUsername)
                                        .font(.system(size: 14))
                                        .padding(12)
                                        .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                                        .cornerRadius(10)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                }
                                
                                // Password
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Password (optional)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                                    
                                    HStack {
                                        if showPassword {
                                            TextField("••••••••", text: $oraclePassword)
                                                .font(.system(size: 14))
                                        } else {
                                            SecureField("••••••••", text: $oraclePassword)
                                                .font(.system(size: 14))
                                        }
                                        
                                        Button(action: { showPassword.toggle() }) {
                                            Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .secondary)
                                        }
                                    }
                                    .padding(12)
                                    .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                                    .cornerRadius(10)
                                }
                                
                                // Test Connection Button
                                Button(action: testConnection) {
                                    HStack {
                                        Image(systemName: "network")
                                        Text("Test Connection")
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            colors: [.accentInfo, .accentInfo.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(10)
                                }
                                .disabled(oracleBaseURL.isEmpty || isTestingConnection)
                                .opacity(oracleBaseURL.isEmpty ? 0.5 : 1)
                            }
                        }
                        
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
                        
                        // Data Sync Section
                        settingsSection(title: "Data Sync") {
                            VStack(spacing: 16) {
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
                                    
                                    Text("1.1.0")
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
                                
                                Divider()
                                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                                
                                HStack {
                                    Image(systemName: "database.fill")
                                        .foregroundColor(.accentInfo)
                                        .frame(width: 24)
                                    
                                    Text("Powered by Oracle 23ai")
                                        .font(.system(size: 15, weight: .medium))
                                    
                                    Spacer()
                                }
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
                        // Save password to UserDefaults (in production, use Keychain)
                        if !oraclePassword.isEmpty {
                            UserDefaults.standard.set(oraclePassword, forKey: "oracle_password")
                        }
                        dismiss()
                    }
                    .foregroundColor(.accentBuy)
                }
            }
            .onAppear {
                // Load password from UserDefaults
                oraclePassword = UserDefaults.standard.string(forKey: "oracle_password") ?? ""
                updateConnectionStatus()
            }
        }
    }
    
    private func updateConnectionStatus() {
        if oracleBaseURL.isEmpty {
            connectionStatus = .notConfigured
        }
    }
    
    private func testConnection() {
        guard !oracleBaseURL.isEmpty else { return }
        
        isTestingConnection = true
        connectionStatus = .testing
        
        // Test the connection
        Task {
            do {
                let urlString = "\(oracleBaseURL)/all"
                guard let url = URL(string: urlString) else {
                    throw URLError(.badURL)
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.addValue("application/json", forHTTPHeaderField: "Accept")
                request.timeoutInterval = 10
                
                // Add auth if provided
                if !oracleUsername.isEmpty && !oraclePassword.isEmpty {
                    let credentials = "\(oracleUsername):\(oraclePassword)"
                    if let credentialData = credentials.data(using: .utf8) {
                        let base64Credentials = credentialData.base64EncodedString()
                        request.addValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
                    }
                }
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                await MainActor.run {
                    if (200...299).contains(httpResponse.statusCode) {
                        connectionStatus = .connected
                    } else if httpResponse.statusCode == 401 {
                        connectionStatus = .error("Unauthorized")
                    } else {
                        connectionStatus = .error("HTTP \(httpResponse.statusCode)")
                    }
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    connectionStatus = .error(error.localizedDescription)
                    isTestingConnection = false
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
