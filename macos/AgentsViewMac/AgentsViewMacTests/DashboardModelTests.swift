import Testing
import Foundation
@testable import AgentsViewMac

@Suite("DashboardModel Tests")
struct DashboardModelTests {
    
    // MARK: - Loading States
    
    @Test("Initial state is loading")
    func initialStateIsLoading() async {
        let model = DashboardModel(apiClient: MockAPIClient())
        #expect(model.state == .loading)
    }
    
    @Test("Successful fetch transitions to success")
    func successfulFetchTransitionsToSuccess() async {
        let mockClient = MockAPIClient()
        mockClient.shouldSucceed = true
        mockClient.mockResponse = createMockResponse()
        
        let model = DashboardModel(apiClient: mockClient)
        await model.refresh()
        
        #expect(model.state == .success)
        #expect(model.summary != nil)
    }
    
    @Test("Failed fetch transitions to error")
    func failedFetchTransitionsToError() async {
        let mockClient = MockAPIClient()
        mockClient.shouldSucceed = false
        mockClient.mockError = APIError.networkError("Connection failed")
        
        let model = DashboardModel(apiClient: mockClient)
        await model.refresh()
        
        if case .error(let message) = model.state {
            #expect(message.contains("Connection failed"))
        } else {
            Issue.record("Expected error state")
        }
    }
    
    @Test("Empty response shows empty state")
    func emptyResponseShowsEmptyState() async {
        let mockClient = MockAPIClient()
        mockClient.shouldSucceed = true
        mockClient.mockResponse = createEmptyResponse()
        
        let model = DashboardModel(apiClient: mockClient)
        await model.refresh()
        
        #expect(model.state == .empty)
    }
    
    // MARK: - Refresh Cancellation
    
    @Test("Refresh cancellation prevents state update")
    func refreshCancellationPreventsStateUpdate() async {
        let mockClient = MockAPIClient()
        mockClient.delaySeconds = 2.0
        mockClient.shouldSucceed = true
        
        let model = DashboardModel(apiClient: mockClient)
        
        // Start refresh
        let refreshTask = Task {
            await model.refresh()
        }
        
        // Cancel immediately
        refreshTask.cancel()
        
        // Wait briefly
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Should still be loading or cancelled, not success
        #expect(model.state == .loading)
    }
    
    // MARK: - Date Range Switching
    
    @Test("Date range change triggers refresh")
    func dateRangeChangeTriggersRefresh() async {
        let mockClient = MockAPIClient()
        mockClient.shouldSucceed = true
        mockClient.mockResponse = createMockResponse()
        
        let model = DashboardModel(apiClient: mockClient)
        await model.refresh()
        
        let initialFetchCount = mockClient.fetchCount
        
        // Change date range
        await model.setDateRange(from: "2026-09-01", to: "2026-09-15")
        
        #expect(mockClient.fetchCount > initialFetchCount)
    }
    
    // MARK: - Edge Cases
    
    @Test("Single point data series")
    func singlePointDataSeries() async {
        let mockClient = MockAPIClient()
        mockClient.shouldSucceed = true
        mockClient.mockResponse = createSingleDayResponse()
        
        let model = DashboardModel(apiClient: mockClient)
        await model.refresh()
        
        #expect(model.state == .success)
        #expect(model.summary?.daily.count == 1)
    }
    
    @Test("All zero values")
    func allZeroValues() async {
        let mockClient = MockAPIClient()
        mockClient.shouldSucceed = true
        mockClient.mockResponse = createAllZeroResponse()
        
        let model = DashboardModel(apiClient: mockClient)
        await model.refresh()
        
        #expect(model.state == .empty)
    }
    
    @Test("Equal maxima in chart data")
    func equalMaximaInChartData() async {
        let mockClient = MockAPIClient()
        mockClient.shouldSucceed = true
        mockClient.mockResponse = createEqualMaximaResponse()
        
        let model = DashboardModel(apiClient: mockClient)
        await model.refresh()
        
        #expect(model.state == .success)
        // All daily entries should have equal cost
        if let summary = model.summary {
            let costs = summary.daily.map { $0.totalCost.microdollars }
            #expect(Set(costs).count == 1)
        }
    }
    
    @Test("Negative comparison delta")
    func negativeComparisonDelta() async {
        let mockClient = MockAPIClient()
        mockClient.shouldSucceed = true
        mockClient.mockResponse = createNegativeComparisonResponse()
        
        let model = DashboardModel(apiClient: mockClient)
        await model.refresh()
        
        #expect(model.state == .success)
        if let comparison = model.summary?.comparison {
            #expect(comparison.deltaPct < 0)
        }
    }
}

// MARK: - Mock Data Helpers

func createMockResponse() -> UsageSummaryResponse {
    UsageSummaryResponse(
        schemaVersion: 1,
        pricing: nil,
        projects: [:],
        from: "2026-09-01",
        to: "2026-09-15",
        totals: UsageTotals(
            inputTokens: 100_000,
            outputTokens: 50_000,
            cacheCreationTokens: 10_000,
            cacheReadTokens: 5_000,
            totalCost: Money(microdollars: 1_500_000),
            copilotAICredits: 0,
            cacheSavings: Money(microdollars: 50_000)
        ),
        daily: [
            DailyUsageEntry(
                date: "2026-09-01",
                inputTokens: 10_000,
                outputTokens: 5_000,
                cacheCreationTokens: 1_000,
                cacheReadTokens: 500,
                totalCost: Money(microdollars: 150_000),
                modelsUsed: ["claude-sonnet-4"],
                modelBreakdowns: [],
                projectBreakdowns: [],
                agentBreakdowns: [],
                machineBreakdowns: []
            )
        ],
        projectTotals: [],
        modelTotals: [
            ModelTotal(
                modelName: "claude-sonnet-4",
                inputTokens: 100_000,
                outputTokens: 50_000,
                cacheCreationTokens: 10_000,
                cacheReadTokens: 5_000,
                cost: Money(microdollars: 1_500_000)
            )
        ],
        agentTotals: [],
        sessionCounts: UsageSessionCounts(
            totalSessions: 10,
            humanSessions: 8,
            automatedSessions: 2
        ),
        cacheStats: CacheStats(
            cacheHitRate: 0.5,
            cacheHits: 5_000,
            cacheMisses: 5_000,
            totalRequests: 10_000
        ),
        unsupportedUsage: nil,
        comparison: Comparison(
            priorFrom: "2026-08-01",
            priorTo: "2026-08-15",
            priorTotalCost: Money(microdollars: 1_200_000),
            deltaPct: 25.0
        )
    )
}

func createEmptyResponse() -> UsageSummaryResponse {
    UsageSummaryResponse(
        schemaVersion: 1,
        pricing: nil,
        projects: [:],
        from: "2026-09-01",
        to: "2026-09-15",
        totals: UsageTotals(
            inputTokens: 0,
            outputTokens: 0,
            cacheCreationTokens: 0,
            cacheReadTokens: 0,
            totalCost: Money(microdollars: 0),
            copilotAICredits: 0,
            cacheSavings: Money(microdollars: 0)
        ),
        daily: [],
        projectTotals: [],
        modelTotals: [],
        agentTotals: [],
        sessionCounts: UsageSessionCounts(
            totalSessions: 0,
            humanSessions: 0,
            automatedSessions: 0
        ),
        cacheStats: CacheStats(
            cacheHitRate: 0,
            cacheHits: 0,
            cacheMisses: 0,
            totalRequests: 0
        ),
        unsupportedUsage: nil,
        comparison: nil
    )
}

func createSingleDayResponse() -> UsageSummaryResponse {
    var response = createMockResponse()
    response.daily = [response.daily[0]]
    return response
}

func createAllZeroResponse() -> UsageSummaryResponse {
    createEmptyResponse()
}

func createEqualMaximaResponse() -> UsageSummaryResponse {
    UsageSummaryResponse(
        schemaVersion: 1,
        pricing: nil,
        projects: [:],
        from: "2026-09-01",
        to: "2026-09-03",
        totals: UsageTotals(
            inputTokens: 30_000,
            outputTokens: 15_000,
            cacheCreationTokens: 3_000,
            cacheReadTokens: 1_500,
            totalCost: Money(microdollars: 450_000),
            copilotAICredits: 0,
            cacheSavings: Money(microdollars: 15_000)
        ),
        daily: [
            DailyUsageEntry(
                date: "2026-09-01",
                inputTokens: 10_000,
                outputTokens: 5_000,
                cacheCreationTokens: 1_000,
                cacheReadTokens: 500,
                totalCost: Money(microdollars: 150_000),
                modelsUsed: ["claude-sonnet-4"],
                modelBreakdowns: [],
                projectBreakdowns: [],
                agentBreakdowns: [],
                machineBreakdowns: []
            ),
            DailyUsageEntry(
                date: "2026-09-02",
                inputTokens: 10_000,
                outputTokens: 5_000,
                cacheCreationTokens: 1_000,
                cacheReadTokens: 500,
                totalCost: Money(microdollars: 150_000),
                modelsUsed: ["claude-sonnet-4"],
                modelBreakdowns: [],
                projectBreakdowns: [],
                agentBreakdowns: [],
                machineBreakdowns: []
            ),
            DailyUsageEntry(
                date: "2026-09-03",
                inputTokens: 10_000,
                outputTokens: 5_000,
                cacheCreationTokens: 1_000,
                cacheReadTokens: 500,
                totalCost: Money(microdollars: 150_000),
                modelsUsed: ["claude-sonnet-4"],
                modelBreakdowns: [],
                projectBreakdowns: [],
                agentBreakdowns: [],
                machineBreakdowns: []
            )
        ],
        projectTotals: [],
        modelTotals: [],
        agentTotals: [],
        sessionCounts: UsageSessionCounts(
            totalSessions: 3,
            humanSessions: 3,
            automatedSessions: 0
        ),
        cacheStats: CacheStats(
            cacheHitRate: 0.5,
            cacheHits: 1_500,
            cacheMisses: 1_500,
            totalRequests: 3_000
        ),
        unsupportedUsage: nil,
        comparison: nil
    )
}

func createNegativeComparisonResponse() -> UsageSummaryResponse {
    var response = createMockResponse()
    response.comparison = Comparison(
        priorFrom: "2026-08-01",
        priorTo: "2026-08-15",
        priorTotalCost: Money(microdollars: 2_000_000),
        deltaPct: -25.0
    )
    return response
}

// MARK: - Mock API Client

class MockAPIClient: APIClientProtocol {
    var shouldSucceed = true
    var mockResponse: UsageSummaryResponse?
    var mockError: APIError?
    var delaySeconds: Double = 0
    var fetchCount = 0
    
    func fetchUsageSummary(from: String, to: String, timezone: String) async throws -> UsageSummaryResponse {
        fetchCount += 1
        
        if delaySeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        }
        
        // Check for cancellation
        try Task.checkCancellation()
        
        if shouldSucceed {
            return mockResponse ?? createMockResponse()
        } else {
            throw mockError ?? APIError.networkError("Mock error")
        }
    }
}
