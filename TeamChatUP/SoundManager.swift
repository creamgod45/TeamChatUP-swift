//
//  SoundManager.swift
//  TeamChatUP
//
//  Created by Kiro on 2026/3/7.
//

import AVFoundation

@MainActor
final class SoundManager: NSObject, AVAudioPlayerDelegate {
    static let shared = SoundManager()
    
    // 使用 Set 來持有正在播放的 players，避免被自動釋放
    private var activePlayers: Set<AVAudioPlayer> = []
    
    private override init() {
        super.init()
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            AppLogger.shared.error("無法配置音訊會話", error: error)
        }
        #endif
    }
    
    func playMessageSound() {
        playSound(named: "tethys", extension: "mp3", volume: 1.0, label: "新訊息")
    }

    func playTypingSound() {
        // 輸入音效稍微調高一點點到 0.5
        playSound(named: "typing", extension: "wav", volume: 0.5, label: "輸入中")
    }
    
    private func playSound(named name: String, extension ext: String, volume: Float, label: String) {
        guard let soundURL = Bundle.main.url(forResource: name, withExtension: ext) else {
            AppLogger.shared.error("❌ 找不到音效檔案: \(name).\(ext)")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: soundURL)
            player.delegate = self
            player.volume = volume
            player.prepareToPlay()
            
            if player.play() {
                activePlayers.insert(player)
                AppLogger.shared.debug("🔊 正在播放\(label)音效 (\(name).\(ext))")
            } else {
                AppLogger.shared.error("❌ 播放\(label)音效失敗")
            }
        } catch {
            AppLogger.shared.error("❌ 初始化\(label)音效失敗", error: error)
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            activePlayers.remove(player)
        }
    }
}
