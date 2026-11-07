import Foundation

struct MarketStatusService {
    static let indianTimeZone = MarketDataClient.indiaTimeZone

    private static var istCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = indianTimeZone
        return cal
    }

    /// True during the NSE/BSE regular session window (Mon–Fri, 9:15–15:30 IST).
    static var isWithinTradingHours: Bool {
        let cal = istCalendar
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        guard (2...6).contains(weekday) else { return false }
        let minutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        return minutes >= 9 * 60 + 15 && minutes <= 15 * 60 + 30
    }

    /// Market is open only if we're inside trading hours *and* the exchange has
    /// actually printed a trade today. This correctly reports exchange holidays
    /// (e.g. Diwali, Republic Day) as closed, which a clock check alone cannot.
    static func isMarketOpen(lastTradeTime: Date?) -> Bool {
        guard isWithinTradingHours else { return false }
        guard let lastTradeTime else { return true }
        return istCalendar.isDate(lastTradeTime, inSameDayAs: Date())
    }

    /// Clock-only check (used before any data has loaded).
    static var isMarketOpen: Bool { isWithinTradingHours }

    static func statusText(isOpen: Bool) -> String {
        isOpen ? "Market Open" : "Market Closed"
    }

    static var marketStatusText: String { statusText(isOpen: isMarketOpen) }

    static var nextRefreshInterval: TimeInterval {
        isWithinTradingHours ? AppConstants.refreshIntervalOpen : AppConstants.refreshIntervalClosed
    }

    /// "Updated 3:29 PM IST" style label.
    static func asOfText(_ date: Date?) -> String? {
        guard let date else { return nil }
        let f = DateFormatter()
        f.timeZone = indianTimeZone
        f.locale = Locale(identifier: "en_IN")
        let cal = istCalendar
        f.dateFormat = cal.isDateInToday(date) ? "h:mm a" : "d MMM, h:mm a"
        return "\(f.string(from: date)) IST"
    }
}
