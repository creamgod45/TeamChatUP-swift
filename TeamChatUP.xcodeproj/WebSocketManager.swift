// MARK: - Heartbeat

private func startHeartbeat() {
    stopHeartbeat()
    
    let interval: TimeInterval = 10 // 改成 10 秒方便測試
    
    AppLogger.shared.info("�� 啟動心跳機制 (間隔: \(Int(interval)) 秒)")
    AppLogger.shared.info("�� 當前執行緒: \(Thread.current)")
    AppLogger.shared.info("�� 是否主執行緒: \(Thread.isMainThread)")
    
    // 使用更簡單的方式建立 Timer
    heartbeatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
        AppLogger.shared.info("⏰ Timer 觸發！")
        AppLogger.shared.info("�� Timer 執行緒: \(Thread.current)")
        AppLogger.shared.info("�� Timer 是否主執行緒: \(Thread.isMainThread)")
        
        guard let self = self else {
            AppLogger.shared.warning("⚠️ self 已被釋放")
            return
        }
        
        // 直接呼叫，不用 Task 包裝
        self.sendPing()
    }
    
    // 確保 timer 有效
    if let timer = heartbeatTimer {
        AppLogger.shared.info("✅ Timer 建立成功，有效: \(timer.isValid)")
        AppLogger.shared.info("✅ Timer 下次觸發時間: \(timer.fireDate)")
    } else {
        AppLogger.shared.error("❌ Timer 建立失敗")
    }
    
    // 立即發送第一次 ping
    AppLogger.shared.info("�� 立即發送第一次 ping")
    sendPing()
}

private func stopHeartbeat() {
    if let timer = heartbeatTimer {
        AppLogger.shared.info("�� 停止心跳機制")
        timer.invalidate()
    }
    heartbeatTimer = nil
}

private func sendPing() {
    AppLogger.shared.info("�� sendPing() 開始執行")
    AppLogger.shared.info("�� sendPing 執行緒: \(Thread.current)")
    AppLogger.shared.info("�� isConnected: \(isConnected)")
    AppLogger.shared.info("�� webSocketTask 是否為 nil: \(webSocketTask == nil)")
    
    guard isConnected else {
        AppLogger.shared.warning("⚠️ 無法發送 ping：未連線")
        return
    }
    
    guard let task = webSocketTask else {
        AppLogger.shared.warning("⚠️ 無法發送 ping：webSocketTask 為 nil")
        return
    }
    
    // 檢查上次 pong 時間
    if let lastPong = lastPongTime {
        let timeSinceLastPong = Date().timeIntervalSince(lastPong)
        AppLogger.shared.debug("⏱️ 距離上次 pong: \(Int(timeSinceLastPong)) 秒")
        
        if timeSinceLastPong > heartbeatInterval * Double(maxMissedPongs) {
            AppLogger.shared.error("❌ 長時間未收到 pong，觸發重連")
            handleDisconnection()
            return
        }
    }
    
    let pingMessage: [String: Any] = [
        "event": "pusher:ping",
        "data": [:]
    ]
    
    do {
        let jsonData = try JSONSerialization.data(withJSONObject: pingMessage)
        let message = URLSessionWebSocketTask.Message.data(jsonData)
        
        AppLogger.shared.info("�� 正在發送 ping...")
        
        task.send(message) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    AppLogger.shared.error("❌ 發送 ping 失敗", error: error)
                    self?.missedPongCount += 1
                    
                    if let count = self?.missedPongCount, count >= self?.maxMissedPongs ?? 3 {
                        AppLogger.shared.error("❌ 連續 \(count) 次 ping 失敗，觸發重連")
                        self?.handleDisconnection()
                    }
                } else {
                    AppLogger.shared.info("✅ ping 發送成功")
                }
            }
        }
    } catch {
        AppLogger.shared.error("❌ 序列化 ping 訊息失敗", error: error)
    }
}

