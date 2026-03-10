#!/bin/bash

# Swift Typing 訊號測試腳本

echo "=========================================="
echo "Swift Typing 訊號功能測試"
echo "=========================================="
echo ""

echo "📋 測試前檢查清單："
echo ""
echo "1. 確認 Reverb 伺服器運行中..."
if ps aux | grep -q "[p]hp artisan reverb:start"; then
    echo "   ✅ Reverb 伺服器正在運行"
else
    echo "   ❌ Reverb 伺服器未運行"
    echo "   請執行: php artisan reverb:start"
    exit 1
fi

echo ""
echo "2. 確認音效檔案存在..."
if [ -f "/Users/a123/Documents/Xcode/TeamChatUP/TeamChatUP/Resource/typing.wav" ]; then
    echo "   ✅ typing.wav 檔案存在"
else
    echo "   ❌ typing.wav 檔案不存在"
    exit 1
fi

echo ""
echo "3. 確認後端程式碼已修改..."
if grep -q "UserTyping 事件建立" "/Users/a123/PhpstormProjects/TeamChatUP-backend/app/Events/UserTyping.php"; then
    echo "   ✅ UserTyping.php 已添加 log"
else
    echo "   ⚠️  UserTyping.php 可能未修改"
fi

echo ""
echo "=========================================="
echo "🧪 開始測試"
echo "=========================================="
echo ""

echo "步驟 1: 在 Xcode 中運行 Swift App"
echo "   - Clean Build (Shift + Command + K)"
echo "   - Run (Command + R)"
echo "   - 登入使用者（不是 user_id = 12）"
echo "   - 進入對話 ID = 7"
echo ""

echo "步驟 2: 在網頁版輸入文字"
echo "   - 開啟: https://teamchatup-backend.test/chat"
echo "   - 登入: user_id = 12"
echo "   - 進入對話 ID = 7"
echo "   - 在輸入框輸入文字"
echo ""

echo "步驟 3: 觀察 Xcode Console"
echo "   搜尋以下關鍵字："
echo "   - 'user.typing'"
echo "   - '收到輸入中訊號'"
echo "   - '播放輸入中音效'"
echo ""

echo "步驟 4: 確認聽到音效 🔊"
echo ""

echo "=========================================="
echo "📊 預期 Log 輸出"
echo "=========================================="
echo ""
echo "[📡 DEBUG] 收到事件: user.typing"
echo "[📺 DEBUG] 事件頻道: private-conversation.7"
echo "[📦 DEBUG] 事件資料內容: {...}"
echo "[⌨️ DEBUG] 收到輸入中訊號 - 使用者ID: 12, 對話ID: 7"
echo "[⌨️ DEBUG] 播放輸入中音效"
echo ""

echo "=========================================="
echo "🔍 即時監控後端 Log"
echo "=========================================="
echo ""
echo "執行以下指令監控後端活動："
echo "cd /Users/a123/PhpstormProjects/TeamChatUP-backend"
echo "tail -f storage/logs/laravel.log | grep -E 'typing|UserTyping|🔔|📡'"
echo ""

echo "按 Ctrl+C 停止監控"
echo ""
