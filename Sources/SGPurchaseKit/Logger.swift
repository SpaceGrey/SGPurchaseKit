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
        let formatted = "[SGPurchaseKit] \(message)"
        if let logHandler = SGPurchases.logHandler {
            logHandler(formatted)
            return
        }
        NSLog("%@", formatted)
    }

    static func storeKitErrorDescription(_ error: Error) -> String {
        let nsError = error as NSError
        var details = [
            "type=\(String(reflecting: type(of: error)))",
            "domain=\(nsError.domain)",
            "code=\(nsError.code)",
            "description=\(nsError.localizedDescription)"
        ]
        if let failureReason = nsError.localizedFailureReason {
            details.append("failureReason=\(failureReason)")
        }
        if let recoverySuggestion = nsError.localizedRecoverySuggestion {
            details.append("recoverySuggestion=\(recoverySuggestion)")
        }
        if let debugDescription = nsError.userInfo[NSDebugDescriptionErrorKey] as? String {
            details.append("debugDescription=\(debugDescription)")
        }
        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            let underlyingNSError = underlyingError as NSError
            details.append(
                "underlyingDomain=\(underlyingNSError.domain) " +
                "underlyingCode=\(underlyingNSError.code) " +
                "underlyingDescription=\(underlyingNSError.localizedDescription)"
            )
        }
        return details.joined(separator: ", ")
    }
}
