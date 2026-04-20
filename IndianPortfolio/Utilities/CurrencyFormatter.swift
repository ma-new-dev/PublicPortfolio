import Foundation

enum CurrencyFormatter {

    private static let inrFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "INR"
        f.currencySymbol = "\u{20B9}"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        f.locale = Locale(identifier: "en_IN")
        return f
    }()

    private static let usdFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.currencySymbol = "$"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        f.locale = Locale(identifier: "en_US")
        return f
    }()

    private static let percentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        f.positivePrefix = "+"
        return f
    }()

    /// Format as plain INR (e.g. ₹2,450.50) — used for per-share prices
    static func formatINR(_ value: Double) -> String {
        inrFormatter.string(from: NSNumber(value: value)) ?? "\u{20B9}\(value)"
    }

    /// Format as INR Crore (e.g. ₹12.45 Cr) — used for holding/portfolio values
    static func formatINRCrore(_ value: Double) -> String {
        let crores = value / 10_000_000
        if crores >= 1 {
            return String(format: "\u{20B9}%.2f Cr", crores)
        } else if crores >= 0.01 {
            return String(format: "\u{20B9}%.4f Cr", crores)
        } else {
            // Below 1 lakh, just show plain INR
            return formatINR(value)
        }
    }

    static func formatUSDMillion(_ value: Double) -> String {
        let billions = value / 1_000_000_000
        let millions = value / 1_000_000
        if billions >= 1 {
            return String(format: "$%.2fB", billions)
        } else if millions >= 1 {
            return String(format: "$%.2fM", millions)
        } else if millions >= 0.001 {
            return String(format: "$%.4fM", millions)
        } else {
            return String(format: "$%.2f", value)
        }
    }

    /// Format market cap in INR — uses L Cr (lakh crore) for very large values
    static func formatMarketCapINR(_ value: Double) -> String {
        let crores = value / 10_000_000
        if crores >= 100_000 {
            // e.g. ₹20.50 L Cr  (lakh crore)
            return String(format: "\u{20B9}%.2f L Cr", crores / 100_000)
        } else if crores >= 1 {
            return String(format: "\u{20B9}%.2f Cr", crores)
        } else {
            return formatINR(value)
        }
    }

    /// Format market cap in USD — uses B (billions) / M (millions)
    static func formatMarketCapUSD(_ value: Double) -> String {
        let billions = value / 1_000_000_000
        let millions = value / 1_000_000
        if billions >= 1 {
            return String(format: "$%.2fB", billions)
        } else if millions >= 1 {
            return String(format: "$%.2fM", millions)
        } else {
            return String(format: "$%.2f", value)
        }
    }

    static func formatPercent(_ value: Double) -> String {
        let formatted = percentFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(formatted)%"
    }

    static func formatChange(_ value: Double) -> String {
        let prefix = value >= 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.2f", value))"
    }

    /// Format share quantity in millions (e.g. "1.50M" for 1500000, "0.25M" for 250000)
    static func formatSharesMillions(_ quantity: Int) -> String {
        let millions = Double(quantity) / 1_000_000
        if millions >= 1 {
            return String(format: "%.2fM", millions)
        } else if millions >= 0.01 {
            return String(format: "%.2fM", millions)
        } else {
            // Below 10K shares, just show the number
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.maximumFractionDigits = 0
            return f.string(from: NSNumber(value: quantity)) ?? "\(quantity)"
        }
    }
}
