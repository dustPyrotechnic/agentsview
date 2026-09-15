# 同步与发现模块

## 职责
`internal/sync` 负责从各 Agent 原生目录（及可选 S3/远端临时树）发现 source、分类变更、解析并写入 SQLite archive；提供 watcher、轮询、增量/全量同步、重建与 worker 调度。

## 边界
- 核心是 [`engine.go`](../../internal/sync/engine.go) 的 `Engine` 与 `EngineConfig`。Engine 串行化所有同步操作（`syncMu`），维护 agent roots、machine attribution、skip cache、provider factories、进度与 retention budget。
- parser provider 负责 native layout 的发现/解析；sync 负责调度、状态、写入和变更范围，不在此重复具体格式解析。
- 文件监听由 `watcher.go`、`watch_backend*.go` 实现；事件批处理与恢复在 `watch_batch_accumulator.go`/`watch_batch_sync.go`。无法可靠监听的 root 使用 polling。
- 远端同步可通过 ID prefix、path rewriter、ephemeral engine 配置隔离本地水位和 skip cache；不要把远端临时路径污染本地状态。

## 关键入口与数据流
1. 构造 `NewEngine`（见 `engine.go`），注入 DB、agent dirs、machine/source mapping、provider factories 和可选 emitter。
2. `SyncAll`/`SyncPaths` 等入口发现 sources，按变更范围 fingerprint/skip-cache，调用 provider `Parse` 或增量解析。
3. 解析结果形成 pending writes，经锁与保护规则提交 archive；`SyncStats`/progress 返回结果，写入后触发 emitter。
4. `Watcher` 收集 filesystem events，批处理/去抖后调用 scoped sync；rename、delete、tombstone 和 periodic full pass 走恢复/审计路径。

## 常见修改路径
- 新 Agent：在 parser 增加 provider/注册与 capabilities，再在 sync 增加必要的 root 分类、增量/恢复策略；为发现、重命名、删除、arrival-order 与大归档工作量添加 focused tests。
- 新 watcher 行为：先看 `WatchPlan`/`WatchRoots`、batch accumulator、poll fallback 和 `watchBatchNeeds...` 语义；按 changed batch 限定工作，保留 full-sync/reconcile recovery。
- 改 skip/fingerprint：维护 mtime、inode/change-time、truncate/rewrite、provider stat hash 一致性；成功写入后才持久化 hash，失败必须可重试。
- 改远端/重建：使用 `EngineConfig` 的 `IDPrefix`、`PathRewriter`、`Ephemeral`；full rebuild 完成后再 swap，避免覆盖 active archive。

## 必须继续读取
- [`background-work.md`](background-work.md)：watcher、polling、调度、内存与 cardinality 约束。
- [`filesystem-sync.md`](../filesystem-sync.md)：session source、machine label、传输和持久 archive 语义。
- [`remote-access.md`](../remote-access.md)：HTTP remote sync/manifest/rebuild 协议。
- [`storage.md`](storage.md)：SQLite 写入、锁和持久化边界。
- [`testing.md`](testing.md)：同步回归测试与最小验证。
- 源码：[`engine.go`](../../internal/sync/engine.go)、[`watcher.go`](../../internal/sync/watcher.go)、[`watch_batch_sync.go`](../../internal/sync/watch_batch_sync.go)、[`watch_backend.go`](../../internal/sync/watch_backend.go)。

## 验证方式
运行 `internal/sync` focused tests：先覆盖 provider discovery/parse，再覆盖 `SyncPaths`/`SyncAll`、watch batch/poll fallback、删除/tombstone、重试与 bounded-work 回归。需要时用隔离临时目录和 test DB 做 smoke；不要用 live archive 或真实 transcript 做 profiling。
