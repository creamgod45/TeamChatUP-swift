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
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        #endif
    }
    
    func playMessageSound() {
        guard let soundURL = Bundle.main.url(forResource: "tethys", withExtension: "mp3") else {
            print("Sound file not found: tethys.mp3")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            AppLogger.shared.debug("🔊 播放新訊息音效")
        } catch {
            print("Failed to play sound: \(error)")
            AppLogger.shared.error("❌ 播放新訊息音效失敗: \(error)")
        }
    }

    func playTypingSound() {
        guard let soundURL = Bundle.main.url(forResource: "typing", withExtension: "wav") else {
            print("Sound file not found: typing.wav")
            AppLogger.shared.warning("⚠️ 找不到 typing.wav 音效檔案")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.volume = 0.3 // 降低音量避免太吵
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            AppLogger.shared.debug("⌨️ 播放輸入中音效")
        } catch {
            print("Failed to play typing sound: \(error)")
            AppLogger.shared.error("❌ 播放輸入音效失敗: \(error)")
        }
    }
}
