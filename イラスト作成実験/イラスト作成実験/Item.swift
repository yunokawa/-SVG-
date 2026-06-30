//
//  Item.swift
//  イラスト作成実験
//
//  Created by 佐々木駿 on 2025/10/23.
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
