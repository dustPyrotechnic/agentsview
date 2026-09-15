# `internal/duckdb`

## 职责
DuckDB 派生只读镜像：从 SQLite 主归档执行全量 rebuild 或按会话 fingerprint 的增量 push，并提供本地镜像、只读 Store 与 Quack 远端读取连接。镜像包含 sessions/messages/usage/curation/analytics 等查询投影。

## 边界
- DuckDB 不是系统记录；删除镜像必须不丢数据。规则见 [`storage.md`](./storage.md)。
- schema/data/source 版本变化必须 bump `SchemaVersion`、新建文件、验证后原子替换；禁止 in-place 迁移和旧镜像兼容 shim。
- push 只写本地镜像文件；`duckdb push` 不得写远端 Quack。远端仅由 `NewQuackStore` 读取。
- cursor、版本、scope、fingerprint 写入镜像自身 `sync_metadata`，不得写 SQLite sync state。
- 替换已有文件前必须由 `ProbeMirror` 确认是 agentsview 镜像；未知文件 fail closed。

## 关键入口与数据流
- [`Push`](../../internal/duckdb/sync.go) 先 probe，再选择 rebuild 或 bounded incremental push；增量应用 deletion journal、scope 变化、fingerprint 改变的 session，并最后推进 metadata。
- [`rebuild.go`](../../internal/duckdb/rebuild.go) 在临时文件建立 schema、导入投影、校验并 rename；[`probe.go`](../../internal/duckdb/probe.go) 识别镜像和版本。
- [`Open`](../../internal/duckdb/connect.go)/`OpenReadOnly` 管理本地连接；[`NewStoreFromConfig`](../../internal/duckdb/connect.go) 根据 config 选择本地或 Quack。
- `Store` 查询通过 `queryContext` 兼容本地 DuckDB 与 attached remote；analytics/activity 逻辑保持 SQLite/PG 可观察语义。

## 常见修改路径
1. 新增镜像列/投影：更新 schema、rebuild、session upsert/fingerprint、增量删除与读扫描；若来源变化同步 bump 版本。
2. 修改 push：维持“候选窗口 → fingerprint 分流 → replace whole session → metadata finalize”的顺序；失败不得推进 cursor。
3. 修改远端连接：保留 attach timeout、URL/token 脱敏、TLS/loopback 规则，并确认 Quack SQL 语法。
4. 修改镜像替换/watch：保持读句柄可用、原子 rename、文件身份检测和 stale alias 清理。

## 必须继续读取
- [`storage.md`](./storage.md)、[`internal/duckdb/sync.go`](../../internal/duckdb/sync.go)
- [`internal/duckdb/rebuild.go`](../../internal/duckdb/rebuild.go)、[`probe.go`](../../internal/duckdb/probe.go)、[`schema.go`](../../internal/duckdb/schema.go)
- [`internal/duckdb/connect.go`](../../internal/duckdb/connect.go)、[`store.go`](../../internal/duckdb/store.go)、[`mirror_watch.go`](../../internal/duckdb/mirror_watch.go)

## 验证方式
运行针对性 `go test ./internal/duckdb -run <TestName>`；重点覆盖 probe/version mismatch、全量 rebuild、增量 fingerprint/deletion、未知文件拒绝和 Quack timeout。不要运行项目级全量测试或把生产文件作为替换目标。
