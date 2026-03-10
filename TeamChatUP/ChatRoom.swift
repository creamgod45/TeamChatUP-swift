//
//  ChatRoom.swift
//  TeamChatUP
//
//  Created by creamgod45 on 2026/3/6.
//

import Foundation
import SwiftData

@Model
final class ChatRoom {
    var id: UUID
    var name: String
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \Message.chatRoom)
    var messages: [Message] = []
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}
