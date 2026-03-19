//
//  AuthenticationManager.swift
//  TeamChatUP
//
//  Created by creamgod45 on 2026/3/6.
//

import Foundation
import Combine
import AuthenticationServices
import Observation

@Observable @MainActor
class AuthenticationManager {
    static let shared = AuthenticationManager()
    
    var isAuthenticated = false
    var currentUser: User?
    
    private init() {
        // Check if token exists in keychain
        if let token = KeychainManager.shared.load() {
            Task {
                await validateToken(token)
            }
        }
    }
    
    func login() async {
        // TODO: Implement WorkOS OAuth flow using ASWebAuthenticationSession
        // For now, using mock authentication
        
        // Mock user for development
        let mockUser = User(
            id: 1,
            name: "測試使用者",
            email: "test@example.com",
            avatar: nil,
            role: "user"
        )
        
        self.currentUser = mockUser
        self.isAuthenticated = true
        
        // Save mock token
        KeychainManager.shared.save(token: "mock_token_for_development")
    }
    
    func logout() async {
        // Clear token from keychain
        KeychainManager.shared.delete()
        
        // Reset state
        self.currentUser = nil
        self.isAuthenticated = false
    }
    
    private func validateToken(_ token: String) async {
        // TODO: Implement API call to /api/auth/me
        // For now, mock validation
        
        let mockUser = User(
            id: 1,
            name: "測試使用者",
            email: "test@example.com",
            avatar: nil,
            role: "user"
        )
        
        self.currentUser = mockUser
        self.isAuthenticated = true
    }
}

