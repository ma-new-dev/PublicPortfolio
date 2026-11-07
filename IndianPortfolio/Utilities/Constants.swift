import Foundation

enum AppConstants {
    static let refreshIntervalOpen: TimeInterval = 15      // seconds, when market is open
    static let refreshIntervalClosed: TimeInterval = 300    // 5 minutes when closed
    static let exchangeRateCacheSeconds: TimeInterval = 300 // 5 minutes (live FX quote)
}
