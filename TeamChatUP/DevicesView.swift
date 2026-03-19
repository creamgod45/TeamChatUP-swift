//
//  DevicesView.swift
//  TeamChatUP
//
//  Created by Kiro on 2026/3/7.
//

import SwiftUI

struct DevicesView: View {
    @State private var authManager = PKCEAuthManager.shared
    @State private var devices: [Device] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var deviceToRevoke: Device?
    @State private var showRevokeAlert = false
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("載入中...")
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                        Button("重試") {
                            Task {
                                await loadDevices()
                            }
                        }
                    }
                    .padding()
                } else if devices.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "iphone")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("沒有已授權的設備")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(devices) { device in
                            DeviceRow(device: device) {
                                deviceToRevoke = device
                                showRevokeAlert = true
                            }
                        }
                    }
                }
            }
            .navigationTitle("已授權設備")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        Task {
                            await loadDevices()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .alert("撤銷設備", isPresented: $showRevokeAlert, presenting: deviceToRevoke) { device in
                Button("取消", role: .cancel) {}
                Button("撤銷", role: .destructive) {
                    Task {
                        await revokeDevice(device)
                    }
                }
            } message: { device in
                Text("確定要撤銷「\(device.deviceName)」的授權嗎？")
            }
        }
        .task {
            await loadDevices()
        }
    }
    
    private func loadDevices() async {
        isLoading = true
        errorMessage = nil
        
        do {
            devices = try await authManager.fetchDevices()
        } catch {
            errorMessage = "載入設備失敗: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func revokeDevice(_ device: Device) async {
        do {
            try await authManager.revokeDevice(id: device.id)
            await loadDevices()
        } catch {
            errorMessage = "撤銷設備失敗: \(error.localizedDescription)"
        }
    }
}

struct DeviceRow: View {
    let device: Device
    let onRevoke: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: deviceIcon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(device.deviceName)
                    .font(.headline)
                
                if let model = device.deviceModel {
                    Text(model)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let lastUsed = device.lastUsedAt {
                    Text("最後使用: \(formatDate(lastUsed))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onRevoke) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
    
    private var deviceIcon: String {
        switch device.deviceType?.lowercased() {
        case "ios":
            return "iphone"
        case "macos":
            return "laptopcomputer"
        default:
            return "desktopcomputer"
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        displayFormatter.locale = Locale(identifier: "zh_TW")
        
        return displayFormatter.string(from: date)
    }
}

