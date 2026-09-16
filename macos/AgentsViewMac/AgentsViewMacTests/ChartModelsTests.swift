import Testing
import Foundation
@testable import AgentsViewMac

@Suite("ChartModels Tests")
struct ChartModelsTests {
    
    // MARK: - Chart Data Preparation
    
    @Test("Prepare chart data from daily entries")
    func prepareChartDataFromDailyEntries() {
        let daily = [
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
                inputTokens: 20_000,
                outputTokens: 10_000,
                cacheCreationTokens: 2_000,
                cacheReadTokens: 1_000,
                totalCost: Money(microdollars: 300_000),
                modelsUsed: ["claude-sonnet-4"],
                modelBreakdowns: [],
                projectBreakdowns: [],
                agentBreakdowns: [],
                machineBreakdowns: []
            )
        ]
        
        let chartData = ChartData.from(dailyEntries: daily)
        
        #expect(chartData.points.count == 2)
        #expect(chartData.points[0].date == "2026-09-01")
        #expect(chartData.points[0].totalTokens == 15_000)
        #expect(chartData.points[0].cost.microdollars == 150_000)
        #expect(chartData.points[1].totalTokens == 30_000)
        #expect(chartData.points[1].cost.microdollars == 300_000)
    }
    
    @Test("Normalize chart domain with varying values")
    func normalizeChartDomainWithVaryingValues() {
        let daily = [
            DailyUsageEntry(
                date: "2026-09-01",
                inputTokens: 10_000,
                outputTokens: 5_000,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                totalCost: Money(microdollars: 100_000),
                modelsUsed: [],
                modelBreakdowns: [],
                projectBreakdowns: [],
                agentBreakdowns: [],
                machineBreakdowns: []
            ),
            DailyUsageEntry(
                date: "2026-09-02",
                inputTokens: 50_000,
                outputTokens: 25_000,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                totalCost: Money(microdollars: 500_000),
                modelsUsed: [],
                modelBreakdowns: [],
                projectBreakdowns: [],
                agentBreakdowns: [],
                machineBreakdowns: []
            )
        ]
        
        let chartData = ChartData.from(dailyEntries: daily)
        
        #expect(chartData.maxTokens == 75_000)
        #expect(chartData.maxCost.microdollars == 500_000)
        #expect(chartData.minCost.microdollars == 100_000)
    }
    
    // MARK: - Edge Cases
    
    @Test("Single point series")
    func singlePointSeries() {
        let daily = [
            DailyUsageEntry(
                date: "2026-09-01",
                inputTokens: 10_000,
                outputTokens: 5_000,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                totalCost: Money(microdollars: 150_000),
                modelsUsed: [],
                modelBreakdowns: [],
                projectBreakdowns: [],
                agentBreakdowns: [],
                machineBreakdowns: []
            )
        ]
        
        let chartData = ChartData.from(dailyEntries: daily)
        
        #expect(chartData.points.count == 1)
        #expect(chartData.maxTokens == 15_000)
        #expect(chartData.maxCost.microdollars == 150_000)
        #expect(chartData.minCost.microdollars == 150_000)
    }
    
    @Test("All zero values")
    func allZeroValues() {
        let daily = [
            DailyUsageEntry(
                date: "2026-09-01",
                inputTokens: 0,
                outputTokens: 0,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                totalCost: Money(microdollars: 0),
                modelsUsed: [],
                modelBreakdowns: [],
                projectBreakdowns: [],
                agentBreakdowns: [],
                machineBreakdowns: []
            ),
            DailyUsageEntry(
                date: "2026-09-02",
                inputTokens: 0,
                outputTokens: 0,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                totalCost: Money(microdollars: 0),
                modelsUsed: [],
                modelBreakdowns: [],
                projectBreakdowns: [],
                agentBreakdowns: [],
                machineBreakdowns: []
            )
        ]
        
        let chartData = ChartData.from(dailyEntries: daily)
        
        #expect(chartData.points.count == 2)
        #expect(chartData.maxTokens == 0)
        #expect(chartData.maxCost.microdollars == 0)
        #expect(chartData.minCost.microdollars == 0)
    }
    
    @Test("Equal maxima")
    func equalMaxima() {
        let daily = [
            DailyUsageEntry(
                date: "2026-09-01",
                inputTokens: 10_000,
                outputTokens: 5_000,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                totalCost: Money(microdollars: 150_000),
                modelsUsed: [],
                modelBreakdowns: [],
                projectBreakdowns: [],
                agentBreakdowns: [],
                machineBreakdowns: []
            ),
            DailyUsageEntry(
                date: "2026-09-02",
                inputTokens: 10_000,
                outputTokens: 5_000,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                totalCost: Money(microdollars: 150_000),
                modelsUsed: [],
                modelBreakdowns: [],
                projectBreakdowns: [],
                agentBreakdowns: [],
                machineBreakdowns: []
            ),
            DailyUsageEntry(
                date: "2026-09-03",
                inputTokens: 10_000,
                outputTokens: 5_000,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                totalCost: Money(microdollars: 150_000),
                modelsUsed: [],
                modelBreakdowns: [],
                projectBreakdowns: [],
                agentBreakdowns: [],
                machineBreakdowns: []
            )
        ]
        
        let chartData = ChartData.from(dailyEntries: daily)
        
        #expect(chartData.points.count == 3)
        #expect(chartData.maxTokens == 15_000)
        #expect(chartData.maxCost.microdollars == 150_000)
        // All points should have equal values
        let allEqual = chartData.points.allSatisfy { $0.cost.microdollars == 150_000 }
        #expect(allEqual)
    }
    
    @Test("Empty daily entries")
    func emptyDailyEntries() {
        let daily: [DailyUsageEntry] = []
        
        let chartData = ChartData.from(dailyEntries: daily)
        
        #expect(chartData.points.isEmpty)
        #expect(chartData.maxTokens == 0)
        #expect(chartData.maxCost.microdollars == 0)
        #expect(chartData.minCost.microdollars == 0)
    }
    
    // MARK: - Date Labels
    
    @Test("Date label formatting")
    func dateLabelFormatting() {
        let daily = [
            DailyUsageEntry(
                date: "2026-09-01",
                inputTokens: 10_000,
                outputTokens: 5_000,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                totalCost: Money(microdollars: 150_000),
                modelsUsed: [],
                modelBreakdowns: [],
                projectBreakdowns: [],
                agentBreakdowns: [],
                machineBreakdowns: []
            ),
            DailyUsageEntry(
                date: "2026-09-15",
                inputTokens: 20_000,
                outputTokens: 10_000,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                totalCost: Money(microdollars: 300_000),
                modelsUsed: [],
                modelBreakdowns: [],
                projectBreakdowns: [],
                agentBreakdowns: [],
                machineBreakdowns: []
            )
        ]
        
        let chartData = ChartData.from(dailyEntries: daily)
        
        // Labels should be deterministic and readable
        #expect(chartData.dateLabels.count == 2)
        #expect(chartData.dateLabels[0].contains("Sep") || chartData.dateLabels[0].contains("9"))
        #expect(chartData.dateLabels[1].contains("Sep") || chartData.dateLabels[1].contains("9"))
    }
    
    // MARK: - Normalized Values
    
    @Test("Normalized values are in 0-1 range")
    func normalizedValuesAreInZeroToOneRange() {
        let daily = [
            DailyUsageEntry(
                date: "2026-09-01",
                inputTokens: 5_000,
                outputTokens: 2_500,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                totalCost: Money(microdollars: 75_000),
                modelsUsed: [],
                modelBreakdowns: [],
                projectBreakdowns: [],
                agentBreakdowns: [],
                machineBreakdowns: []
            ),
            DailyUsageEntry(
                date: "2026-09-02",
                inputTokens: 10_000,
                outputTokens: 5_000,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                totalCost: Money(microdollars: 150_000),
                modelsUsed: [],
                modelBreakdowns: [],
                projectBreakdowns: [],
                agentBreakdowns: [],
                machineBreakdowns: []
            )
        ]
        
        let chartData = ChartData.from(dailyEntries: daily)
        
        for point in chartData.points {
            let normalizedTokens = chartData.normalizedTokens(for: point)
            let normalizedCost = chartData.normalizedCost(for: point)
            
            #expect(normalizedTokens >= 0.0 && normalizedTokens <= 1.0)
            #expect(normalizedCost >= 0.0 && normalizedCost <= 1.0)
        }
    }
    
    @Test("Normalization handles zero max")
    func normalizationHandlesZeroMax() {
        let daily = [
            DailyUsageEntry(
                date: "2026-09-01",
                inputTokens: 0,
                outputTokens: 0,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                totalCost: Money(microdollars: 0),
                modelsUsed: [],
                modelBreakdowns: [],
                projectBreakdowns: [],
                agentBreakdowns: [],
                machineBreakdowns: []
            )
        ]
        
        let chartData = ChartData.from(dailyEntries: daily)
        
        if let point = chartData.points.first {
            let normalizedTokens = chartData.normalizedTokens(for: point)
            let normalizedCost = chartData.normalizedCost(for: point)
            
            // Should not crash and should return sensible values
            #expect(normalizedTokens == 0.0)
            #expect(normalizedCost == 0.0)
        }
    }
    
    // MARK: - Money Precision
    
    @Test("Money stays in microdollars until formatting")
    func moneyStaysInMicrodollarsUntilFormatting() {
        let daily = [
            DailyUsageEntry(
                date: "2026-09-01",
                inputTokens: 10_000,
                outputTokens: 5_000,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                totalCost: Money(microdollars: 1_234_567), // $1.234567
                modelsUsed: [],
                modelBreakdowns: [],
                projectBreakdowns: [],
                agentBreakdowns: [],
                machineBreakdowns: []
            )
        ]
        
        let chartData = ChartData.from(dailyEntries: daily)
        
        // Money should remain as microdollars
        #expect(chartData.points[0].cost.microdollars == 1_234_567)
        #expect(chartData.maxCost.microdollars == 1_234_567)
        
        // No float conversion in chart data
        #expect(type(of: chartData.points[0].cost.microdollars) == Int64.self)
    }
}
