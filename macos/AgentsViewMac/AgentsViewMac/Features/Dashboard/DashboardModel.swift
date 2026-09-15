import Foundation
import Observation

/// Dashboard state enum
enum DashboardState: Equatable {
    case loading
    case success
    case empty
    case error(String)
}

/// Dashboard view model that manages usage data fetching and state
///
/// This model is the single source of truth for dashboard UI state. It consumes
/// API models directly without recalculating costs (Go backend is authoritative).
@Observable
@MainActor
final class DashboardModel {
    
    // MARK: - Published State
    
    private(set) var state: DashboardState = .loading
    private(set) var summary: UsageSummaryResponse?
    
    // MARK: - Date Range
    
    private(set) var dateFrom: String
    private(set) var dateTo: String
    private(set) var timezone: String
    
    // MARK: - Dependencies
    
    private let apiClient: APIClientProtocol
    private var currentTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    /// Initialize dashboard model with API client
    ///
    /// - Parameters:
    ///   - apiClient: API client for fetching usage data
    ///   - dateFrom: Start date (defaults to 30 days ago)
    ///   - dateTo: End date (defaults to today)
    ///   - timezone: IANA timezone (defaults to system timezone)
    init(
        apiClient: APIClientProtocol,
        dateFrom: String? = nil,
        dateTo: String? = nil,
        timezone: String? = nil
    ) {
        self.apiClient = apiClient
        
        // Default to last 30 days
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        
        self.dateFrom = dateFrom ?? formatter.string(from: thirtyDaysAgo)
        self.dateTo = dateTo ?? formatter.string(from: now)
        self.timezone = timezone ?? TimeZone.current.identifier
    }
    
    // MARK: - Public Methods
    
    /// Refresh usage data from API
    func refresh() async {
        // Cancel any in-flight request
        currentTask?.cancel()
        
        state = .loading
        
        currentTask = Task {
            do {
                // Check for cancellation before making request
                try Task.checkCancellation()
                
                let response = try await apiClient.fetchUsageSummary(
                    from: dateFrom,
                    to: dateTo,
                    timezone: timezone
                )
                
                // Check for cancellation before updating state
                try Task.checkCancellation()
                
                // Determine state based on response
                if isEmptyResponse(response) {
                    state = .empty
                    summary = nil
                } else {
                    state = .success
                    summary = response
                }
            } catch is CancellationError {
                // Don't update state on cancellation
                return
            } catch let error as APIError {
                state = .error(error.localizedDescription ?? "Unknown error")
                summary = nil
            } catch {
                state = .error(error.localizedDescription)
                summary = nil
            }
        }
        
        await currentTask?.value
    }
    
    /// Set date range and refresh
    ///
    /// - Parameters:
    ///   - from: Start date in ISO 8601 format (YYYY-MM-DD)
    ///   - to: End date in ISO 8601 format (YYYY-MM-DD)
    func setDateRange(from: String, to: String) async {
        guard from != dateFrom || to != dateTo else {
            return
        }
        
        dateFrom = from
        dateTo = to
        await refresh()
    }
    
    /// Set timezone and refresh
    ///
    /// - Parameter timezone: IANA timezone identifier
    func setTimezone(_ timezone: String) async {
        guard timezone != self.timezone else {
            return
        }
        
        self.timezone = timezone
        await refresh()
    }
    
    // MARK: - Private Helpers
    
    /// Check if response represents empty usage data
    private func isEmptyResponse(_ response: UsageSummaryResponse) -> Bool {
        // Empty if no daily entries or all totals are zero
        if response.daily.isEmpty {
            return true
        }
        
        let totals = response.totals
        return totals.inputTokens == 0 &&
               totals.outputTokens == 0 &&
               totals.cacheCreationTokens == 0 &&
               totals.cacheReadTokens == 0 &&
               totals.totalCost.microdollars == 0 &&
               totals.copilotAICredits == 0
    }
}
