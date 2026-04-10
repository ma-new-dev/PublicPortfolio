import Foundation

enum AppConstants {
    enum API {
        static let yahooChartBase = "https://query1.finance.yahoo.com/v8/finance/chart"
        static let yahooSearchBase = "https://query1.finance.yahoo.com/v1/finance/search"
        static let exchangeRateURL = "https://open.er-api.com/v6/latest/INR"
    }

    static let refreshIntervalOpen: TimeInterval = 15      // seconds, when market is open
    static let refreshIntervalClosed: TimeInterval = 300    // 5 minutes when closed
    static let exchangeRateCacheSeconds: TimeInterval = 3600 // 1 hour
}
