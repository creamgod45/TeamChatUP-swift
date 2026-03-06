//
//  Item.swift
//  TeamChatUP
//
//  Created by creamgod45 on 2026/3/6.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
