import Foundation

/// Represents a monetary value in microdollars (1/1,000,000 of a dollar).
/// Preserves exact precision throughout calculations.
struct Money: Codable, Equatable, Sendable {
    let microdollars: Int64
    
    init(microdollars: Int64) {
        self.microdollars = microdollars
    }
    
    /// Convert to dollars as Decimal for display formatting
    var dollars: Decimal {
        Decimal(microdollars) / 1_000_000
    }
    
    /// Format as currency string
    func formatted() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 6
        return formatter.string(from: dollars as NSDecimalNumber) ?? "$0.00"
    }
    
    static let zero = Money(microdollars: 0)
}
