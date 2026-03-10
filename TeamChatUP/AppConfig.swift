//
//  AppConfig.swift
//  TeamChatUP
//
//  Created by Kiro on 2026/3/7.
//

import Foundation

enum AppConfig {
    enum Environment {
        case development
        case staging
        case production
        
        static var current: Environment {
            #if DEBUG
            return .development
            #else
            return .production
            #endif
        }
    }
    
    static var apiBaseURL: String {
        switch Environment.current {
        case .development:
            return "https://teamchatup-backend.test/api"
        case .staging:
            return "https://staging-api.teamchatup.com/api"
        case .production:
            return "https://api.teamchatup.com/api"
        }
    }

    static var websocketURL: String {
        switch Environment.current {
        case .development:
            return "wss://teamchatup-backend.test"
        case .staging:
            return "wss://staging-ws.teamchatup.com"
        case .production:
            return "wss://ws.teamchatup.com"
        }
    }
    
    static var deviceAuthURL: String {
        switch Environment.current {
        case .development:
            return "https://teamchatup-backend.test/device/authorize"
        case .staging:
            return "https://staging.teamchatup.com/device/authorize"
        case .production:
            return "https://teamchatup.com/device/authorize"
        }
    }
    
    static var urlScheme: String {
        return "teamchatup"
    }
    
    static var workOSClientID: String {
        return "YOUR_WORKOS_CLIENT_ID"
    }
    
    static var workOSRedirectURI: String {
        return "teamchatup://auth/callback"
    }
}

// MARK: - Reverb Configuration

struct ReverbConfig {
    let key: String
    let host: String
    let port: Int
    let useTLS: Bool
    let authEndpoint: String
}
extension AppConfig {
    static var reverbConfig: ReverbConfig {
        switch Environment.current {
        case .development:
            return ReverbConfig(
                key: "de8kqizuqz5ozrxidl0a",
                host: "teamchatup-backend.test",
                port: 8080,
                useTLS: true,
                authEndpoint: "https://teamchatup-backend.test/api/broadcasting/auth"
            )
        case .staging:
            return ReverbConfig(
                key: "STAGING_REVERB_KEY",
                host: "staging.teamchatup.com",
                port: 8080,
                useTLS: true,
                authEndpoint: "https://staging.teamchatup.com/broadcasting/auth"
            )
        case .production:
            return ReverbConfig(
                key: "PRODUCTION_REVERB_KEY",
                host: "teamchatup.com",
                port: 8080,
                useTLS: true,
                authEndpoint: "https://teamchatup.com/broadcasting/auth"
            )
        }
    }
}

