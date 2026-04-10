import Foundation

struct MarketStatusService {
    static let indianTimeZone = TimeZone(identifier: "Asia/Kolkata")!

    static var isMarketOpen: Bool {
        let calendar = Calendar.current
        var cal = calendar
        cal.timeZone = indianTimeZone

        let now = Date()
        let weekday = cal.component(.weekday, from: now)

        // Weekdays only (Mon=2 to Fri=6)
        guard (2...6).contains(weekday) else { return false }

        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let totalMinutes = hour * 60 + minute

        // Market hours: 9:15 AM to 3:30 PM IST
        let openMinutes = 9 * 60 + 15    // 555
        let closeMinutes = 15 * 60 + 30  // 930

        return totalMinutes >= openMinutes && totalMinutes <= closeMinutes
    }

    static var marketStatusText: String {
        isMarketOpen ? "Market Open" : "Market Closed"
    }

    static var nextRefreshInterval: TimeInterval {
        isMarketOpen ? AppConstants.refreshIntervalOpen : AppConstants.refreshIntervalClosed
    }
}
