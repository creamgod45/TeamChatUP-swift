//
//  PKCEManager.swift
//  TeamChatUP
//
//  Created by Kiro on 2026/3/7.
//

import Foundation
import CryptoKit

final class PKCEManager {
    
    /// 生成 code_verifier (43-128 字元的隨機字串)
    static func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        
        let verifier = Data(buffer)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        AppLogger.shared.debug("生成 code_verifier: \(verifier.prefix(10))... (長度: \(verifier.count))")
        return verifier
    }
    
    /// 從 verifier 計算 code_challenge (SHA256 + Base64URL)
    static func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else {
            AppLogger.shared.error("無法將 verifier 轉換為 Data")
            return ""
        }
        
        let hash = SHA256.hash(data: data)
        let hashData = Data(hash)
        
        let challenge = hashData
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        AppLogger.shared.debug("生成 code_challenge: \(challenge.prefix(10))... (長度: \(challenge.count))")
        return challenge
    }
    
    /// 驗證 verifier 和 challenge 是否匹配（用於測試）
    static func verifyChallenge(_ challenge: String, verifier: String) -> Bool {
        let computedChallenge = generateCodeChallenge(from: verifier)
        let isValid = computedChallenge == challenge
        AppLogger.shared.debug("PKCE 驗證: \(isValid ? "✅ 成功" : "❌ 失敗")")
        return isValid
    }
}
