# AgentsView macOS SwiftUI 客户端设计

## 状态

已确认采用：SwiftUI 原生 macOS 客户端 + Go 本地服务/sidecar。统计图全部使用 SwiftUI 原生绘制，不引入 WebView 图表库或第三方图表依赖。

## 背景与目标

仓库当前已有 Tauri 2 桌面包装器：它携带 Go `agentsview` binary，启动本地 HTTP 服务，并在 WebView 中加载 Svelte 前端；macOS 还已有菜单栏状态项。后端已有 `/api/v1/usage/summary`、`/api/v1/usage/comparison` 及 analytics 路由，能提供 Token、成本、日聚合、项目和模型维度数据。

本项目新增真正的 macOS 原生客户端，目标是：

- 用 SwiftUI 提供原生主窗口和统计界面；
- 用 macOS 菜单栏显示当前 Token 消耗、预计费用和服务状态；
- 复用 Go 的 SQLite、解析、同步、定价和 API 逻辑；
- 支持 sidecar 启动、健康检查、停止、重启和错误呈现；
- 保留现有 Tauri 实现，直到 SwiftUI 客户端达到可替代发布标准。

非目标：本阶段不把解析器、数据库迁移、同步引擎或成本算法重写为 Swift；不迁移全部 Svelte 页面；不新增云端服务。

## 方案与取舍

### 方案 A：SwiftUI 客户端 + Go sidecar/API（采用）

SwiftUI 负责窗口、菜单栏、图表和交互；Go 继续作为本地权威业务层。优点是复用现有数据正确性和跨 provider 逻辑，迁移风险小，能够逐页替换前端。代价是需要管理本地进程和 API 兼容性。

### 方案 B：SwiftUI 直接读取 SQLite

减少 HTTP 层，但会复制 schema、迁移、查询和数据模型，且无法自然复用同步与 parser。放弃。

### 方案 C：SwiftUI 外壳 + WKWebView

交付快，但主界面仍是 Web UI，无法满足原生统计界面和长期原生客户端目标。仅作为迁移期间的回退，不作为目标架构。

## 架构

```text
AgentsView.app
├── SwiftUI macOS client
│   ├── App lifecycle / WindowGroup
│   ├── MenuBarExtra status item
│   ├── Native dashboard and charts
│   ├── URLSession API client
│   └── Sidecar process manager
└── Go agentsview sidecar
    ├── SQLite archive
    ├── parser and sync engine
    ├── usage and cost aggregation
    └── authenticated loopback HTTP API
```

新增工程放在 `macos/`，采用 Swift Package/Xcode 工程可编译的 macOS target。建议目录：

```text
macos/
├── AgentsViewMac/
│   ├── App/
│   ├── Core/API/
│   ├── Core/Sidecar/
│   ├── Core/Formatting/
│   ├── Models/
│   ├── Features/Dashboard/
│   ├── Features/Usage/
│   ├── Features/Sessions/
│   ├── Features/Settings/
│   └── Resources/
└── AgentsViewMac.xcodeproj
```

Swift 数据流使用 `@Observable` 和 `@MainActor` 状态模型。`APIClient` 只负责请求、解码和统一错误；`SidecarManager` 只负责进程生命周期；ViewModel 负责把 API 模型转换为视图所需的窄数据；视图不直接拼接 URL、不处理 JSON、不执行数据库逻辑。

金额在 Swift 侧使用后端微美元整数或 `Decimal`，展示层通过 `FormatStyle` 格式化，禁止用 `Double` 做累计。所有 API 响应必须校验 `code`，错误同时保留机器可读 code 和用户可读 message。

## API 契约

优先复用现有接口：

- `GET /api/v1/usage/summary`：总 Token、总成本、按日数据、项目/模型聚合、缓存统计；
- `GET /api/v1/usage/comparison`：当前区间与上一周期的成本比较；
- `GET /api/v1/analytics/*`：后续统计页面需要的分析维度；
- `GET /api/v1/events`：必要时用于同步完成或数据刷新通知。

Swift 客户端的第一版 Dashboard 使用 `usage/summary`，以日期范围和时区作为参数。不得在 Swift 重算成本或自行合并 usage rows。若现有响应字段不足以表达菜单栏所需的“预计费用”，在 Go 侧增加一个向后兼容的字段或专用轻量响应；该字段必须明确：

- 已发生费用：基于已定价 usage 的实际累计；
- 预计费用：基于当前区间、已知定价和未完成/可推断 usage 的估算；
- 未定价数据：单独计数并在 UI 显示，不得静默计入零成本。

API schema/version 只有在不兼容时才递增；更新 OpenAPI 和 server focused tests。

## 原生统计界面

Dashboard 采用 macOS 原生层次结构：顶部区间选择和刷新，下面是摘要卡片，再下面是主要趋势图与维度排行。

第一版指标：

- 总 Token：输入、输出、缓存写入、缓存读取；
- 总费用与预计费用；
- 当前周期相对上一周期的变化百分比；
- 按天 Token/费用趋势；
- 按模型、项目的费用排行；
- 未定价 usage 提示。

图表全部用 SwiftUI 原生 API 组合实现：`Canvas`/`Path` 绘制折线、面积和柱形，SwiftUI `Shape` 绘制网格与标记，原生手势提供 hover/选择点详情。图表模型先把 API 数据转换为稳定的坐标域和标记点，避免 View 内进行聚合。窗口变窄时转为纵向布局；无数据、部分数据、加载、错误和刷新状态均有明确呈现；不使用 `AnyView` 或第三方图表库。

视觉方向：macOS 原生材质和语义颜色、克制的渐变、清晰的数字层级、足够留白、深色模式兼容；不复制现有 Web CSS。动画只用于区间切换、数据更新和 hover 状态，并尊重 Reduce Motion。

## 菜单栏

使用 SwiftUI `MenuBarExtra`，显示简短摘要而非完整 Dashboard：

- 图标旁显示当日费用或 Token 数；
- 弹出菜单显示总 Token、已用费用、预计费用、更新时间；
- 点击“打开 AgentsView”显示主窗口并聚焦；
- 提供刷新、打开设置、退出；
- sidecar 未启动、启动中、不可用时显示对应状态和恢复操作。

菜单栏刷新采用可取消的定时任务和事件触发相结合，避免高频轮询；窗口进入后台仍保持低频状态更新。菜单栏数字使用与 Dashboard 相同的格式化器，保证口径一致。

## Sidecar 生命周期

Swift 侧通过 `Process` 启动 Go binary，参数保持与现有桌面实现一致：`serve --background --host 127.0.0.1`。binary 路径优先使用 app bundle 内资源，开发环境允许配置路径。启动流程：启动进程 → 读取启动输出/端口 → probe 健康端点 → 创建 API client → 加载 Dashboard。

必须覆盖：启动超时、端口解析失败、进程提前退出、数据版本不兼容、API 断连、用户退出、重复启动和重启竞态。退出时先优雅停止 sidecar，超时才终止子进程。Token、API key 和完整启动环境不得写入日志。

## 测试策略

Go：复用现有 usage/analytics focused tests；新增或修改 API 时覆盖响应字段、日期/时区、未定价数据、预计费用语义和 OpenAPI schema。

Swift：

- API decoder 测试成功 envelope、非零 `code`、缺失/未知字段和日期金额解码；
- ViewModel 测试 loading/success/empty/error、刷新取消和周期切换；
- 图表模型测试空数据、单点、全零、最大值相同、跨日期和负变化率；
- SidecarManager 测试启动失败、健康检查超时和退出状态转换；
- 菜单栏摘要测试与 Dashboard 使用同一数据口径。

测试只锁定可观察行为，不测试 SwiftUI 私有 View 层级或源代码文本。

## 验收标准

1. 在 macOS 上可构建并启动 SwiftUI 客户端。
2. 客户端能启动 Go sidecar，并在本地服务就绪后显示数据。
3. Dashboard 使用 SwiftUI 原生图表显示 Token 和费用趋势，不依赖 WebView/第三方图表库。
4. 菜单栏能显示 Token 消耗、已用费用、预计费用、更新时间和服务状态。
5. 区间切换、刷新、空数据、未定价、错误和 sidecar 重启有可理解的 UI 状态。
6. 费用与现有 Go `/api/v1/usage/summary` 口径一致，不在 Swift 重算。
7. Go focused tests、Swift tests、macOS 构建和实际启动烟测通过。
8. 现有 Tauri 桌面目录和行为不被破坏。

## 风险与控制

- Swift/Go API 演进：固定 schema version，使用兼容解码和 OpenAPI 测试。
- sidecar 打包与签名：先支持本地开发和 `.app` 构建，再接入 release bundle；不把密钥硬编码进 app。
- 统计口径不一致：Go 是唯一成本计算来源，Swift 只展示。
- 原生图表复杂度：第一版限定折线、柱形、面积和 hover 明细，避免引入图表框架。
- 现有 Tauri 共存：新客户端放在独立 `macos/`，共享 Go API，不修改 Tauri 启动状态机，除非后续明确迁移。
