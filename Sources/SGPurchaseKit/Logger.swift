//
//  File.swift
//  SGPurchaseKit
//
//  Created by 王培屹 on 2/1/25.
//

import Foundation
class Logger {
    static func log(_ message: String) {
        guard SGPurchases.enableLog else {
            return
        }
        NSLog("[SGPurchaseKit] \(message)")
    }
}
