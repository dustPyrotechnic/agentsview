# Task 2 接手文档：Swift API 客户端

## 任务状态
**状态**: 未开始（已取消以切换 API）  
**原因**: 保护 Codex 官方 API 配额，切换到 ttapi

## 任务目标
实现 Swift API 客户端和模型，对接 Go 后端的 usage API

## 需要完成的工作

### 1. 阅读现有 API（前置步骤）
- 读取 `internal/server/usage.go` 了解现有 API 响应格式
- 读取 `internal/server/huma_routes_usage.go` 了解路由定义
- 确认 `/api/v1/usage/summary` 端点的完整响应结构

### 2. 创建文件
在 `macos/AgentsViewMac/AgentsViewMac/Core/API/` 目录：
- `APIClient.swift` - HTTP 客户端封装
- `UsageModels.swift` - Codable 数据模型
- `APIError.swift` - 错误类型定义

在 `macos/AgentsViewMac/AgentsViewMacTests/`：
- `APIClientTests.swift` - 单元测试

### 3. 实现内容

#### UsageModels.swift
需要映射的字段（基于 Go API）：
```swift
struct UsageResponse: Codable {
    let code: Int
    let message: String
    let data: UsageData
}

struct UsageData: Codable {
    let range: DateRange
    let totals: UsageTotals
    let daily: [DailyUsage]
    let byModel: [String: ModelUsage]
    let byProject: [String: ProjectUsage]?
    let comparison: ComparisonData?
    let pricing: PricingInfo
}

struct UsageTotals: Codable {
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
    let actualCostMicrodollars: Int
    let estimatedCostMicrodollars: Int
    let unpricedUsage: Bool
}
```

#### APIClient.swift
- 基础 URL 配置（默认 `http://127.0.0.1:端口`）
- `fetchUsageSummary(range: DateRange, timezone: TimeZone)` 方法
- URL 参数构造（`range=7d`、`from=`、`to=`、`timezone=`）
- 响应解码和 `{code, message, data}` 信封验证
- 使用 `URLSession` + `async/await`

#### APIError.swift
```swift
enum APIError: Error, LocalizedError {
    case networkError(Error)
    case invalidResponse
    case apiError(code: Int, message: String)
    case decodingError(Error)
}
```

### 4. 测试要求（TDD）
先写测试，确保失败，再实现：
- ✅ 成功解码正常响应
- ✅ 处理非零 API code（业务错误）
- ✅ 处理畸形 JSON
- ✅ 正确解析 microdollars 成本
- ✅ 忽略未知可选字段（向后兼容）
- ✅ 日期范围和时区参数正确构造

### 5. 验收标准
- 所有 `APIClientTests` 通过
- 模型完整映射 Go API 响应
- 支持日期范围和时区参数
- 提交为: `feat: add Swift usage API client`

## 技术决策

### 使用 Swift 6 Concurrency
- `async/await` 而非回调
- `URLSession.data(for:)` 异步 API

### 金额处理
- 保持 `Int` microdollars（不用 `Double`）
- 转换为 `Decimal` 仅在 UI 格式化时

### 错误处理
- 区分网络错误、解码错误、业务错误
- 提供本地化 `errorDescription`

## 依赖关系
- **依赖**: Task 1（Xcode 项目结构）✅ 已完成
- **被依赖**: Task 7（菜单栏应用需要 API 客户端）

## 注意事项
1. Go API 已存在，不要重新设计响应格式
2. microdollars 是整数，保持精度
3. 可选字段要用 `?`，确保向后兼容
4. 时区参数可能需要 IANA 格式（如 `America/New_York`）

## 下一步
1. 读取 `internal/server/usage.go` 确认字段
2. 编写失败的测试
3. 实现模型和客户端
4. 运行测试确保通过
5. 提交 commit
