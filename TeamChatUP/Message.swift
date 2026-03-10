//
//  Message.swift
//  TeamChatUP
//
//  Created by creamgod45 on 2026/3/6.
//

import Foundation
import SwiftData

@Model
final class Message {
    var id: UUID
    var content: String
    var senderName: String
    var timestamp: Date
    var chatRoom: ChatRoom?
    
    init(content: String, senderName: String, chatRoom: ChatRoom) {
        self.id = UUID()
        self.content = content
        self.senderName = senderName
        self.timestamp = Date()
        self.chatRoom = chatRoom
    }
}
