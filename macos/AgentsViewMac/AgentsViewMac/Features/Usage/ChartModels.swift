import Foundation

struct UsageChartSeries: Equatable, Sendable {
    let points: [UsageChartPoint]
    let domain: ClosedRange<Double>

    init(daily: [DailyUsageEntry]) {
        points = daily.sorted { $0.date < $1.date }.map {
            UsageChartPoint(date: $0.date, value: $0.totalCost.microdollars)
        }
        let maximum = points.map { Double($0.value) }.max() ?? 0
        domain = 0...max(1, maximum)
    }
}

struct UsageChartPoint: Equatable, Sendable {
    let date: String
    let value: Int64
}

func formatMicrodollars(_ value: Int64) -> String {
    let sign = value < 0 ? "-" : ""
    let absolute = value.magnitude
    return "\(sign)$\(absolute / 1_000_000).\(String(format: "%06llu", absolute % 1_000_000))"
}

func formatComparison(_ delta: Double) -> String {
    String(format: "%+.1f%%", delta * 100)
}

/// A single data point in a usage chart
struct ChartPoint: Identifiable, Sendable {
    let id: String
    let date: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let totalTokens: Int
    let cost: Money
    
    init(from entry: DailyUsageEntry) {
        self.id = entry.date
        self.date = entry.date
        self.inputTokens = entry.inputTokens
        self.outputTokens = entry.outputTokens
        self.cacheCreationTokens = entry.cacheCreationTokens
        self.cacheReadTokens = entry.cacheReadTokens
        self.totalTokens = entry.inputTokens + entry.outputTokens + entry.cacheCreationTokens + entry.cacheReadTokens
        self.cost = entry.totalCost
    }
}

/// Chart data prepared for native SwiftUI Charts
struct ChartData: Sendable {
    let points: [ChartPoint]
    let maxTokens: Int
    let maxCost: Money
    let minCost: Money
    let dateLabels: [String]
    
    /// Create chart data from daily usage entries
    ///
    /// - Parameter dailyEntries: Array of daily usage entries from API
    /// - Returns: Prepared chart data with normalized domains and labels
    static func from(dailyEntries: [DailyUsageEntry]) -> ChartData {
        guard !dailyEntries.isEmpty else {
            return ChartData(
                points: [],
                maxTokens: 0,
                maxCost: .zero,
                minCost: .zero,
                dateLabels: []
            )
        }
        
        // Convert entries to points
        let points = dailyEntries.map { ChartPoint(from: $0) }
        
        // Calculate max tokens
        let maxTokens = points.map(\.totalTokens).max() ?? 0
        
        // Calculate cost range
        let costs = points.map(\.cost.microdollars)
        let maxCostValue = costs.max() ?? 0
        let minCostValue = costs.min() ?? 0
        
        // Generate date labels
        let dateLabels = points.map { formatDateLabel($0.date) }
        
        return ChartData(
            points: points,
            maxTokens: maxTokens,
            maxCost: Money(microdollars: maxCostValue),
            minCost: Money(microdollars: minCostValue),
            dateLabels: dateLabels
        )
    }
    
    /// Get normalized token value (0-1) for a point
    ///
    /// - Parameter point: Chart point to normalize
    /// - Returns: Normalized value between 0 and 1
    func normalizedTokens(for point: ChartPoint) -> Double {
        guard maxTokens > 0 else { return 0.0 }
        return Double(point.totalTokens) / Double(maxTokens)
    }
    
    /// Get normalized cost value (0-1) for a point
    ///
    /// - Parameter point: Chart point to normalize
    /// - Returns: Normalized value between 0 and 1
    func normalizedCost(for point: ChartPoint) -> Double {
        let range = maxCost.microdollars - minCost.microdollars
        guard range > 0 else { return 0.0 }
        
        let offset = point.cost.microdollars - minCost.microdollars
        return Double(offset) / Double(range)
    }
    
    /// Format date string for chart labels
    ///
    /// - Parameter dateString: ISO 8601 date string (YYYY-MM-DD)
    /// - Returns: Formatted label string
    private static func formatDateLabel(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        // Use short month and day format (e.g., "Sep 1")
        let labelFormatter = DateFormatter()
        labelFormatter.dateFormat = "MMM d"
        return labelFormatter.string(from: date)
    }
}

// MARK: - Token Breakdown Chart Data

/// Token breakdown for stacked bar charts
struct TokenBreakdown: Identifiable, Sendable {
    let id = UUID()
    let category: String
    let value: Int
    let color: TokenCategory
    
    enum TokenCategory: String, CaseIterable {
        case input = "Input"
        case output = "Output"
        case cacheCreation = "Cache Creation"
        case cacheRead = "Cache Read"
    }
    
    /// Create token breakdowns from a daily entry
    ///
    /// - Parameter entry: Daily usage entry
    /// - Returns: Array of token breakdowns for each category
    static func from(entry: DailyUsageEntry) -> [TokenBreakdown] {
        [
            TokenBreakdown(category: TokenCategory.input.rawValue, value: entry.inputTokens, color: .input),
            TokenBreakdown(category: TokenCategory.output.rawValue, value: entry.outputTokens, color: .output),
            TokenBreakdown(category: TokenCategory.cacheCreation.rawValue, value: entry.cacheCreationTokens, color: .cacheCreation),
            TokenBreakdown(category: TokenCategory.cacheRead.rawValue, value: entry.cacheReadTokens, color: .cacheRead)
        ]
    }
}

// MARK: - Model Usage Chart Data

/// Model usage data for pie/bar charts
struct ModelUsageData: Identifiable, Sendable {
    let id: String
    let modelName: String
    let cost: Money
    let tokenCount: Int
    let percentage: Double
    
    /// Create model usage data from model totals
    ///
    /// - Parameter modelTotals: Array of model totals from API
    /// - Returns: Array of model usage data with calculated percentages
    static func from(modelTotals: [ModelTotal]) -> [ModelUsageData] {
        let totalCost = modelTotals.reduce(Int64(0)) { $0 + $1.cost.microdollars }
        
        return modelTotals.map { model in
            let tokenCount = model.inputTokens + model.outputTokens + 
                           model.cacheCreationTokens + model.cacheReadTokens
            let percentage = totalCost > 0 ? Double(model.cost.microdollars) / Double(totalCost) : 0.0
            
            return ModelUsageData(
                id: model.modelName,
                modelName: model.modelName,
                cost: model.cost,
                tokenCount: tokenCount,
                percentage: percentage
            )
        }
        .sorted { $0.cost.microdollars > $1.cost.microdollars }
    }
}

// MARK: - Project Usage Chart Data

/// Project usage data for horizontal bar charts
struct ProjectUsageData: Identifiable, Sendable {
    let id: String
    let projectName: String
    let cost: Money
    let tokenCount: Int
    let percentage: Double
    
    /// Create project usage data from project totals
    ///
    /// - Parameter projectTotals: Array of project totals from API
    /// - Returns: Array of project usage data with calculated percentages
    static func from(projectTotals: [ProjectTotal]) -> [ProjectUsageData] {
        let totalCost = projectTotals.reduce(Int64(0)) { $0 + $1.cost.microdollars }
        
        return projectTotals.map { project in
            let tokenCount = project.inputTokens + project.outputTokens + 
                           project.cacheCreationTokens + project.cacheReadTokens
            let percentage = totalCost > 0 ? Double(project.cost.microdollars) / Double(totalCost) : 0.0
            
            return ProjectUsageData(
                id: project.projectKey,
                projectName: project.project,
                cost: project.cost,
                tokenCount: tokenCount,
                percentage: percentage
            )
        }
        .sorted { $0.cost.microdollars > $1.cost.microdollars }
    }
}
