import Foundation


// MARK: - Usage Summary Response

public struct UsageSummaryResponse: Codable, Sendable {
    let schemaVersion: Int?
    let pricing: PricingBlock?
    let projects: [String: ProjectMapEntry]
    let from: String
    let to: String
    let totals: UsageTotals
    let daily: [DailyUsageEntry]
    let projectTotals: [ProjectTotal]
    let modelTotals: [ModelTotal]
    let agentTotals: [AgentTotal]
    let sessionCounts: UsageSessionCounts
    let cacheStats: CacheStats
    let unsupportedUsage: UnsupportedUsage?
    let comparison: Comparison?
    
    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case pricing, projects, from, to, totals, daily
        case projectTotals, modelTotals, agentTotals, sessionCounts, cacheStats, unsupportedUsage, comparison
    }
}

// MARK: - Usage Totals

public struct UsageTotals: Codable, Sendable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let totalCost: Money
    let copilotAICredits: Double?
    let cacheSavings: Money
    
    enum CodingKeys: String, CodingKey {
        case inputTokens, outputTokens
        case cacheCreationTokens, cacheReadTokens
        case totalCost, copilotAICredits, cacheSavings
    }
}

// MARK: - Daily Usage Entry

public struct DailyUsageEntry: Codable, Sendable {
    let date: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let totalCost: Money
    let modelsUsed: [String]
    let modelBreakdowns: [ModelBreakdown]
    let projectBreakdowns: [ProjectBreakdown]
    let agentBreakdowns: [AgentBreakdown]
    let machineBreakdowns: [MachineBreakdown]
}

// MARK: - Breakdowns

public struct ModelBreakdown: Codable, Sendable {
    let modelName: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let cost: Money
}

public struct ProjectBreakdown: Codable, Sendable {
    let projectKey: String
    let project: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let cost: Money
    
    enum CodingKeys: String, CodingKey {
        case projectKey = "project_key"
        case project, inputTokens, outputTokens, cacheCreationTokens, cacheReadTokens, cost
    }
}

public struct AgentBreakdown: Codable, Sendable {
    let agent: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let cost: Money
}

public struct MachineBreakdown: Codable, Sendable {
    let machineName: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let cost: Money
}

// MARK: - Totals

public struct ModelTotal: Codable, Sendable {
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let cost: Money
}

public struct ProjectTotal: Codable, Sendable {
    let projectKey: String
    let project: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let cost: Money
    
    enum CodingKeys: String, CodingKey {
        case projectKey = "project_key"
        case project, inputTokens, outputTokens, cacheCreationTokens, cacheReadTokens, cost
    }
}

public struct AgentTotal: Codable, Sendable {
    let agent: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let cost: Money
}

// MARK: - Stats

public struct UsageSessionCounts: Codable, Sendable {
    let total: Int
    let byProject: [String: Int]
    let byAgent: [String: Int]
}

public struct CacheStats: Codable, Sendable {
    let cacheReadTokens: Int
    let cacheCreationTokens: Int
    let uncachedInputTokens: Int
    let outputTokens: Int
    let hitRate: Double
    let savingsVsUncached: Money
}

public struct Comparison: Codable, Sendable {
    let priorFrom: String
    let priorTo: String
    let priorTotalCost: Money
    let deltaPct: Double
}

// MARK: - Supporting Types

public struct PricingBlock: Codable, Sendable {
    // Placeholder - not used in current implementation
}

public struct ProjectMapEntry: Codable, Sendable {}

public struct UnsupportedUsage: Codable, Sendable {
    let kind: String
}
