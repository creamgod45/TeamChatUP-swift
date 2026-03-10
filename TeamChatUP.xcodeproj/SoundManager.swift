//
//  SoundManager.swift
//  TeamChatUP
//
//  Created by Kiro on 2026/3/7.
//

import AVFoundation

@MainActor
final class SoundManager {
    static let shared = SoundManager()
    
    private var audioPlayer: AVAudioPlayer?
    
    private init() {
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            AppLogger.shared.debug("音效 session 配置成功")
        } catch {
            AppLogger.shared.error("音效 session 配置失敗", error: error)
        }
        #endif
    }
    
    func playMessageSound() {
        AppLogger.shared.debug("�� 準備播放訊息音效")
        
        guard let soundURL = Bundle.main.url(forResource: "tethys", withExtension: "mp3") else {
            AppLogger.shared.error("❌ 找不到音效檔案: tethys.mp3")
            return
        }
        
        AppLogger.shared.debug("✅ 找到音效檔案: \(soundURL.path)")
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            AppLogger.shared.info("�� 訊息音效播放成功")
        } catch {
            AppLogger.shared.error("❌ 播放音效失敗", error: error)
        }
    }
}
