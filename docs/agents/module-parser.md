# Parser 模块

## 职责

`internal/parser` 将各类 AI 编程代理在本地文件、JSONL、SQLite 或虚拟多会话容器中的原始记录，统一转换为 `ParsedSession`、`ParsedMessage`、`ParsedUsageEvent` 等规范结构，并提供发现、监听、变更路径分类、来源查找、指纹和增量解析能力。

## 边界

- `AgentType`、`AgentDef` 和稳定注册表位于 [`types.go`](../../internal/parser/types.go)；注册表顺序会影响配置、同步和 watcher。
- Provider 负责来源形状、身份、freshness 和 lookup；同步引擎只应消费 `SourceRef`、`SourceFingerprint` 与规范化解析结果（见 [`provider.go`](../../internal/parser/provider.go)）。
- 文件扫描、持久化、远程同步和数据库写入属于上层 sync/storage；parser 不应把这些职责塞入具体 provider。
- 解析失败、数据版本、跳过和增量回退通过 `ParseOutcome`/`DataVersionState`/`SkipReason` 等契约表达，不能用“空结果”掩盖错误。

## 关键入口 / 数据流

1. `ProviderFactories` / `ProviderFactoryByType` / `NewProvider` 根据 `AgentType` 建立绑定 `ProviderConfig` 的 provider。
2. `Provider.Discover` 或 `DiscoverEach` 发现 `SourceRef`；`WatchPlan`/`ResolveWatchRoots` 提供 watcher 根目录。
3. 文件变更通过 `SourcesForChangedPath` 分类，必要时用 `FindSource` 从 session ID 和存储 hint 恢复来源。
4. `Fingerprint` 生成 skip-cache 和源元数据使用的稳定身份；`Parse` 返回一个或多个 `ParseResult`，多成员容器必须使用 session-scoped path。
5. 追加写入优先走 `ParseIncremental`；provider 返回 `ErrIncrementalNeedsFullParse` 或 `IncrementalUnsupported` 时由调用方执行替换式全量解析。
6. 解析结果携带消息、工具调用/结果、关系类型、token presence 和 usage events；`InferRelationshipTypes` 与 token 聚合辅助函数保持跨 provider 语义一致。

## 常见修改路径

- 新增代理：在 `types.go` 加 `AgentDef`，添加 `<agent>.go` 解析器与 `<agent>_provider.go` 来源适配，接入 `providerFactoryForDef`，再放最小 fixture 和对应测试。
- 调整既有格式：先改该代理的原始解码函数，再确认 `ParsedSession`/`ParsedMessage` 字段、时间、角色、工具和 token presence；若来源形状变化，同步修改 provider 的 discovery、fingerprint 与 changed-path 逻辑。
- 变更多会话容器：检查虚拟路径、成员身份、`Reconciliation*Resolver` 和完整覆盖证明，确保删除成员不会被容器路径误判为仍存在。
- 变更 token/cost：优先复用 `InferTokenPresence`、`UsageEventTokenAggregate`，不要从零值推断“字段不存在”。
- 加密或降级格式：保持不可解码内容的可见降级路径（例如 sidecar/history fallback），并显式设置 retry/data-version 状态。

## 必须继续读取的资料

- [`internal/parser/provider.go`](../../internal/parser/provider.go)：Provider、SourceRef、增量和 reconciliation 契约。
- [`internal/parser/types.go`](../../internal/parser/types.go)：规范数据结构、Agent registry、关系和 token 语义。
- 与目标代理同名的 parser/provider 文件及其 `*_test.go`、`testdata/`：格式事实和稳定 ID 约束。
- [`internal/sync`](../../internal/sync/)：调用方如何消费 discovery、fingerprint、parse 和覆盖范围（仅在修改跨层契约时阅读）。

## 验证方式

优先运行目标 provider 的 Go 测试（例如 `go test ./internal/parser -run 'Test<Agent>'`），并覆盖 fixture 解析、空/损坏输入、changed path、fingerprint 稳定性及增量回退。修改公共 provider 契约后，再由仓库维护者运行整体验证。