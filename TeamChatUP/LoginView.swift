//
//  LoginView.swift
//  TeamChatUP
//
//  Created by creamgod45 on 2026/3/6.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var pkceAuthManager = PKCEAuthManager.shared
    @State private var showManualCodeEntry = false
    @State private var loginMethod: LoginMethod = .automatic
    
    enum LoginMethod {
        case automatic
        case manual
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            
            Text("TeamChatUP")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("團隊即時通訊平台")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            VStack(spacing: 16) {
                // 自動登入按鈕
                Button {
                    pkceAuthManager.startAuthorization()
                } label: {
                    HStack {
                        Image(systemName: "link")
                        Text("自動授權登入")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                .disabled(pkceAuthManager.isLoading)
                
                // 手動輸入授權碼按鈕
                Button {
                    showManualCodeEntry = true
                } label: {
                    HStack {
                        Image(systemName: "keyboard")
                        Text("手動輸入授權碼")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.2))
                    .foregroundStyle(.primary)
                    .cornerRadius(12)
                }
                .disabled(pkceAuthManager.isLoading)
            }
            .padding(.horizontal, 40)
            
            if pkceAuthManager.isLoading {
                ProgressView()
                    .padding(.top, 8)
            }
            
            if let error = pkceAuthManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showManualCodeEntry) {
            ManualCodeEntryView()
        }
    }
}

struct ManualCodeEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var pkceAuthManager = PKCEAuthManager.shared
    @State private var authorizationCode = ""
    @State private var isSubmitting = false
    @State private var hasOpenedBrowser = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 說明
                VStack(alignment: .leading, spacing: 12) {
                    Label("步驟 1", systemImage: "1.circle.fill")
                        .font(.headline)
                    
                    Text("點擊下方按鈕開啟瀏覽器進行授權")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        pkceAuthManager.startManualAuthorization()
                        hasOpenedBrowser = true
                    } label: {
                        HStack {
                            Image(systemName: "safari")
                            Text("開啟授權頁面")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .disabled(pkceAuthManager.isLoading)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                
                // 輸入授權碼
                VStack(alignment: .leading, spacing: 12) {
                    Label("步驟 2", systemImage: "2.circle.fill")
                        .font(.headline)
                    
                    Text("完成授權後，複製授權碼並貼到下方")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    TextField("貼上授權碼", text: $authorizationCode)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .font(.system(.body, design: .monospaced))
                    
                    Button {
                        submitCode()
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle")
                                Text("確認登入")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(authorizationCode.isEmpty ? Color.gray : Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .disabled(authorizationCode.isEmpty || isSubmitting)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                
                if let error = pkceAuthManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("手動授權")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func submitCode() {
        isSubmitting = true
        
        Task {
            await pkceAuthManager.exchangeManualCode(code: authorizationCode.trimmingCharacters(in: .whitespacesAndNewlines))
            
            isSubmitting = false
            
            if pkceAuthManager.isAuthenticated {
                dismiss()
            }
        }
    }
}

#Preview {
    LoginView()
}
