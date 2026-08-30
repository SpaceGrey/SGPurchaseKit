import Foundation
import StoreKit

public enum RestorePurchaseError: Error, Equatable, Sendable {
    case userCancelled
    case networkUnavailable
    case notAvailableInStorefront
    case notEntitled
    case storeKitFailure(domain: String, code: Int)

    static func classify(_ error: Error) -> Self {
        classify(error, depth: 0)
    }

    private static func classify(_ error: Error, depth: Int) -> Self {
        guard depth < 3 else {
            return failure(for: error)
        }
        if error is CancellationError {
            return .userCancelled
        }
        if let urlError = error as? URLError {
            return urlError.code == .cancelled ? .userCancelled : .networkUnavailable
        }
        if let storeKitError = error as? StoreKitError {
            switch storeKitError {
            case .userCancelled:
                return .userCancelled
            case .networkError:
                return .networkUnavailable
            case .systemError(let underlyingError):
                return classify(underlyingError, depth: depth + 1)
            case .notAvailableInStorefront:
                return .notAvailableInStorefront
            case .notEntitled:
                if #available(iOS 15.4, macOS 12.3, tvOS 15.4, watchOS 8.5, *) {
                    return .notEntitled
                }
                return failure(for: error)
            case .unsupported:
                return failure(for: error)
            case .unknown:
                return failure(for: error)
            @unknown default:
                return failure(for: error)
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return nsError.code == URLError.Code.cancelled.rawValue ? .userCancelled : .networkUnavailable
        }
        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return classify(underlyingError, depth: depth + 1)
        }
        return failure(for: error)
    }

    private static func failure(for error: Error) -> Self {
        let nsError = error as NSError
        return .storeKitFailure(domain: nsError.domain, code: nsError.code)
    }
}
