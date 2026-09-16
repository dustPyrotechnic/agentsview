# Task 4 接手文档：Sidecar 生命周期管理器

## 任务状态
**状态**: 未开始（已取消以切换 API）  
**原因**: 保护 Codex 官方 API 配额，切换到 ttapi

## 任务目标
实现 Go sidecar 进程的启动、健康检查、停止管理

## 需要完成的工作

### 1. 创建文件
在 `macos/AgentsViewMac/AgentsViewMac/Core/Sidecar/`：
- `SidecarState.swift` - 状态枚举和转换逻辑
- `SidecarManager.swift` - 进程管理主逻辑

在 `macos/AgentsViewMac/AgentsViewMacTests/`：
- `SidecarManagerTests.swift` - 单元测试（使用 mock Process）

### 2. 状态机设计

#### SidecarState.swift
```swift
enum SidecarState: Equatable {
    case stopped
    case starting
    case ready(port: Int)
    case failed(Error)
}
```

状态转换：
- `stopped` → `starting`（调用 start）
- `starting` → `ready(port)`（健康检查通过）
- `starting` → `failed`（启动失败/超时）
- `ready` → `stopped`（主动停止）
- `ready` → `failed`（进程意外退出）

### 3. SidecarManager 实现

#### 核心功能
```swift
@MainActor
class SidecarManager: ObservableObject {
    @Published private(set) var state: SidecarState = .stopped
    
    func start() async throws
    func stop() async
    func restart() async throws
}
```

#### 启动流程
1. 定位 `agentsview` 二进制
   - 优先：Bundle.main.resourceURL/agentsview
   - 开发模式：从环境变量 `AGENTSVIEW_SIDECAR_PATH` 覆盖
2. 启动进程：`Process()` + 参数 `["serve", "--background", "--host", "127.0.0.1"]`
3. 解析日志获取端口号（或固定端口）
4. 健康检查：轮询 `http://127.0.0.1:{port}/health`
   - 间隔：500ms
   - 超时：10秒
   - 成功标准：HTTP 200

#### 停止流程
1. 发送 SIGTERM（优雅停止）
2. 等待最多 5 秒
3. 如果未退出，发送 SIGKILL
4. 清理 Process 资源

#### 进程监控
- 监听 `Process.terminationHandler`
- 意外退出 → `state = .failed`

### 4. 测试要求（TDD）

#### 测试场景
- ✅ stopped → starting → ready 正常流程
- ✅ 进程提前退出（starting 时崩溃）
- ✅ 健康检查超时（10秒未就绪）
- ✅ 优雅停止超时（5秒后强制 kill）
- ✅ 二进制文件不存在
- ✅ 端口已被占用

#### Mock 策略
使用协议隔离 Process：
```swift
protocol ProcessProtocol {
    func launch() throws
    func terminate()
    var isRunning: Bool { get }
}
```

测试中注入 MockProcess

### 5. 验收标准
- 所有 `SidecarManagerTests` 通过
- 进程管理健壮（启动、健康检查、停止）
- 线程安全（@MainActor）
- 提交为: `feat: manage Go sidecar lifecycle`

## 技术决策

### 为什么用 @MainActor
- Process 和 state 管理适合主线程
- 与 SwiftUI @Observable 模型集成方便
- 避免数据竞争

### 健康检查实现
使用 `URLSession` 轮询 `/health` 端点：
```swift
func waitForHealth(port: Int, timeout: TimeInterval) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if let response = try? await checkHealth(port: port), 
           response.statusCode == 200 {
            return
        }
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms
    }
    throw SidecarError.healthCheckTimeout
}
```

### 端口发现
Go sidecar 使用随机端口（`--port 0`）或固定端口：
- 方案 A：解析 stdout 获取实际端口
- 方案 B：使用固定端口（如 58080）

推荐方案 B（简单可靠）

## 依赖关系
- **依赖**: Task 1（Xcode 项目结构）✅ 已完成
- **被依赖**: Task 7（菜单栏应用需要 sidecar 管理）

## 注意事项
1. 开发时 sidecar 路径可能不在 bundle 中
2. 健康检查可能需要重试（sidecar 启动需要时间）
3. 停止时必须优雅关闭（避免数据损坏）
4. macOS 沙箱可能影响 Process 权限（开发签名暂时关闭沙箱）

## 坑和风险
- **Xcode 调试时 Process 行为异常**：用 `xcodebuild` 构建的 .app 测试
- **健康检查端口不匹配**：确保 sidecar 日志输出可解析或使用固定端口
- **优雅停止失败**：Go 程序需要正确处理 SIGTERM

## 下一步
1. 实现 SidecarState 枚举
2. 编写失败的测试（mock Process）
3. 实现 SidecarManager
4. 手动测试实际 sidecar 启动（不在单元测试中）
5. 提交 commit
