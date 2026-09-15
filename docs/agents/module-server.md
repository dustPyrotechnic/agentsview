# HTTP 服务模块

## 职责
`internal/server` 提供嵌入式 SPA、Huma/OpenAPI API、SSE、认证/CORS/gzip/base-path 中间件，并把请求编排到 DB、session service、sync engine、remote sync 和后台任务。

## 边界
- `Server` 持有 config、`db.Store`、主/按需 `sync.Engine`、session service、broadcaster、HTTP mux/API；构造入口是 [`server.go`](../../internal/server/server.go) 的 `New`。
- 路由按 `huma_routes_*.go` 分域注册；通用 mux、SPA、生命周期和 OpenAPI 在 `server.go`/`huma_routes.go`。HTTP 层不应复制 parser、DB schema 或同步解析逻辑。
- `APIVersion` 是 daemon discovery 与客户端可解码契约；无法兼容时必须显式 bump，并同步 CLI/remote-sync 兼容分支。
- `auth.go` 保护 `/api/` 与可选 pprof；SSE (`/watch`、`/api/v1/events`) 不能依赖浏览器 EventSource 自定义 header，使用其既有认证路径。`basePath` 要同时影响路由和 SPA `<base href>`。

## 关键入口与数据流
1. `New` 选择具体 store 对应的 session service/backend，应用 options，准备嵌入 web assets。
2. `Server` 注册 Huma API 与 REST handlers；请求通过 middleware（auth、deadline、gzip 等）进入 route。
3. session/sync mutation handler 调用 service 或 engine；变更后通过 broadcaster/SSE 通知客户端，必要时调用 mutation notify hooks。
4. `artifact_exchange.go`、`huma_routes_remote_sync.go` 对远端同步提供受认证、loopback/配置约束的 HTTP 边界；错误需脱敏。

## 常见修改路径
- 新 API：在对应 `huma_routes_*.go` 定义输入/输出 schema、注册 route，更新 OpenAPI/HTTP focused tests；不要直接绕过 Huma 注册表。
- 新 middleware/跨请求策略：先确认 `auth.go`、`compress.go`、`deadline.go` 和 route 顺序，再覆盖本地、远程、SSE、base-path 情况。
- 新 SSE 事件：扩展 `broadcaster.go` 的 scope/event 语义，确保订阅可取消、发送非阻塞并且 shutdown 能取消 request context。
- 改 remote/artifact endpoint：同时检查 bearer auth、loopback/host 校验、请求大小、错误 redaction 与 API 版本。

## 必须继续读取
- [`remote-access.md`](../remote-access.md)：远端 HTTP、认证和增量协议。
- [`session-api.md`](../session-api.md)：会话 API 契约。
- [`mcp.md`](../mcp.md)：MCP 暴露边界。
- [`testing.md`](testing.md)：HTTP focused tests 和 testify 约定。
- 源码：[`server.go`](../../internal/server/server.go)、[`huma_routes.go`](../../internal/server/huma_routes.go)、[`auth.go`](../../internal/server/auth.go)、[`broadcaster.go`](../../internal/server/broadcaster.go)、[`artifact_exchange.go`](../../internal/server/artifact_exchange.go)。

## 验证方式
运行 `internal/server` 的 focused tests，覆盖新 route 的状态码/JSON/OpenAPI、认证拒绝、SSE 生命周期及必要的 base-path；再用 httptest 或本地 server smoke test 验证真实 HTTP 响应。项目级验证由上层负责。
