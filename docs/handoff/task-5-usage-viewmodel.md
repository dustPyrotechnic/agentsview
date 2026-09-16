# Task 5 接手文档：使用量视图模型和图表模型

## 任务状态
**状态**: 未开始（已取消以切换 API）  
**原因**: 保护 Codex 官方 API 配额，切换到 ttapi

## 任务目标
构建 Dashboard 视图模型和原生图表数据准备逻辑

## 需要完成的工作

### 1. 创建文件
在 `macos/AgentsViewMac/AgentsViewMac/Features/Dashboard/`：
- `DashboardModel.swift` - @Observable 视图模型

在 `macos/AgentsViewMac/AgentsViewMac/Features/Usage/`：
- `ChartModels.swift` - 图表数据转换逻辑

在 `macos/AgentsViewMac/AgentsViewMacTests/`：
- `DashboardModelTests.swift` - 视图模型测试
- `ChartModelsTests.swift` - 图表逻辑测试

### 2. DashboardModel 设计

#### 状态管理
```swift
@Observable
@MainActor
class DashboardModel {
    enum LoadingState {
        case idle
        case loading
        case loaded(UsageData)
        case error(APIError)
    }
    
    private(set) var state: LoadingState = .idle
    var selectedRange: DateRange = .last7Days
    
    private let apiClient: APIClient
    private var loadTask: Task<Void, Never>?
    
    func load() async
    func refresh() async
    func changeRange(_ range: DateRange) async
}
```

#### 关键行为
- `load()` - 首次加载
- `refresh()` - 重新加载，取消之前的请求
- `changeRange()` - 切换日期范围，自动刷新
- 使用 Task 支持取消（避免重复请求）

### 3. ChartModels 设计

#### 日均图表数据
```swift
struct DailyChartPoint: Identifiable {
    let id: Date
    let date: Date
    let tokens: Int
    let costMicrodollars: Int
}

struct DailyChartData {
    let points: [DailyChartPoint]
    let maxTokens: Int
    let maxCostMicrodollars: Int
    let tokenDomain: ClosedRange<Int>
    let costDomain: ClosedRange<Decimal>
}
```

#### 转换逻辑
```swift
extension UsageData {
    func toDailyChartData() -> DailyChartData {
        // 1. 转换 daily entries 为 chart points
        // 2. 计算 max values
        // 3. 归一化域（确保非空，处理全零情况）
        // 4. 返回结构化数据
    }
}
```

#### 边界情况处理
- **空数据**: 返回空 points，域为 `0...1`
- **全零**: 域为 `0...1`（避免除零）
- **单点**: 域扩展为 `value*0.9...value*1.1`
- **负值**: 不应出现（microdollars 总是非负）

### 4. 模型分解和费用格式化

#### 按模型分组
```swift
struct ModelBreakdown: Identifiable {
    let id: String  // 模型名
    let name: String
    let tokens: Int
    let costMicrodollars: Int
    let percentage: Double  // 占总成本的百分比
}

extension UsageData {
    func modelBreakdown() -> [ModelBreakdown] {
        // 按成本降序排序
    }
}
```

#### 金额格式化
```swift
extension Int {
    var toDollars: Decimal {
        Decimal(self) / 1_000_000
    }
    
    func formatted() -> String {
        // $12.34 或 $0.001 (小于 1 cent 显示 3 位小数)
    }
}
```

### 5. 测试要求（TDD）

#### DashboardModel 测试
- ✅ 初始状态是 `.idle`
- ✅ `load()` 成功 → `.loaded`
- ✅ `load()` 失败 → `.error`
- ✅ 空响应 → `.loaded` with empty data
- ✅ `refresh()` 取消之前的 Task
- ✅ `changeRange()` 触发新请求

#### ChartModels 测试
- ✅ 正常数据转换
- ✅ 单点数据（域扩展）
- ✅ 全零值（域为 0...1）
- ✅ 相等最大值（tokens 和 cost 都相等）
- ✅ 负比较值（对比昨天降低了）
- ✅ 金额格式化（microdollars → $X.XX）

### 6. 验收标准
- 所有 ViewModel 测试通过
- 数据转换逻辑清晰、确定性
- 金额精度正确（microdollars）
- 提交为: `feat: model native usage dashboard`

## 技术决策

### 为什么用 @Observable 而非 ObservableObject
- Swift 6 推荐
- 更细粒度的依赖追踪
- 与 SwiftUI 自动集成

### 金额精度
- API 返回 `Int` microdollars（1美元 = 1,000,000 microdollars）
- 转换为 `Decimal` 仅在格式化时
- 避免 `Double`（浮点精度问题）

### 图表域归一化
确保图表总有有效域：
- 空数据 → `0...1`
- 单点 → 扩展 10% 上下边距
- 全零 → `0...1`

### Task 取消
使用 Swift Concurrency Task：
```swift
func refresh() async {
    loadTask?.cancel()
    loadTask = Task {
        await performLoad()
    }
    await loadTask?.value
}
```

## 依赖关系
- **依赖**: 
  - Task 1（Xcode 项目）✅ 已完成
  - Task 2（API 客户端）⏳ 待完成
- **被依赖**: 
  - Task 6（SwiftUI Dashboard 界面）
  - Task 7（菜单栏应用）

## 注意事项
1. 不重新计算成本（使用 API 返回的值）
2. microdollars 保持整数，直到 UI 格式化
3. 日期范围切换要取消之前的请求
4. 图表数据必须确定性（相同输入→相同输出）
5. 所有异步操作在 @MainActor 上下文

## 坑和风险
- **空数据渲染**: 图表库可能崩溃，必须处理空 points
- **除零错误**: 计算百分比时确保分母非零
- **时区问题**: 日期要用 API 返回的时区，不要用本地时区

## 下一步
1. 确保 Task 2（API 客户端）完成
2. 编写失败的测试
3. 实现 DashboardModel
4. 实现 ChartModels 转换逻辑
5. 运行测试确保通过
6. 提交 commit
