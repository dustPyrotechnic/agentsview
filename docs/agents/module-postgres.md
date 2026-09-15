# `internal/postgres`

## 职责
PostgreSQL/CockroachDB 远端存储适配：连接与 TLS 校验、schema 初始化、SQLite → PG push、会话/消息/分析/搜索读取，以及远端 curation、vector 与 usage 能力。`Store` 实现 [`db.Store`](../../internal/db/store.go)。

## 边界
- 远端 schema 是 `agentsview`（或调用方指定 schema）；连接入口必须经过 [`Open`](../../internal/postgres/connect.go) 与 [`EnsureSchema`](../../internal/postgres/schema.go)。
- `Store.ReadOnly()` 对通用本地写路径返回只读；明确支持的 PG curation/insight 写入走专用事务方法。
- SQLite 是主归档，PG push 必须保持行为/查询形状与 SQLite 尽可能一致；不要只修一个主后端。
- DSN、token、密码和 URL query 不得进入日志或错误文本；使用 `RedactDSN`/Quack 类似的脱敏约束。

## 关键入口与数据流
- [`NewStore`](../../internal/postgres/store.go) → [`Open`](../../internal/postgres/connect.go) → schema/search_path 校验。
- [`EnsureSchema`](../../internal/postgres/schema.go) 管理表、索引、约束及兼容迁移。
- [`Push`](../../internal/postgres/push.go) 从 `db.DB` 读取会话窗口、指纹和删除 journal，在事务中 upsert/删除目标行；`sync.go`/fingerprint 文件维护增量边界。
- `analytics*.go`、`activity*.go`、`search_content*.go` 将参数化 SQL 映射到 `db`/activity/export 类型。
- vector push/search 与 `vector_schema.go` 管理 PG 向量表；不能把 SQLite vectors.db 当成 PG 的写源。

## 常见修改路径
1. 新增镜像字段：先改 `db` 投影与 push fingerprint，再改 PG schema/upsert/scanner，最后对齐 DuckDB（若适用）。
2. 新增查询：复用 `paramBuilder`、分块 IN 参数和现有 filter builder；保持排序、去重、NULL 与时间边界和 SQLite 相同。
3. schema 变化：更新 schema 版本/兼容迁移与集成 fixture；禁止依赖隐式 search_path 或未校验标识符。
4. 连接安全：保留 TLS 检查、loopback 例外、DSN 脱敏；不要把 `allowInsecure` 扩大成默认行为。

## 必须继续读取
- [`storage.md`](./storage.md)、[`internal/db/store.go`](../../internal/db/store.go)
- [`internal/postgres/connect.go`](../../internal/postgres/connect.go)、[`schema.go`](../../internal/postgres/schema.go)
- [`internal/postgres/push.go`](../../internal/postgres/push.go)、[`sync.go`](../../internal/postgres/sync.go)、[`push_fingerprint.go`](../../internal/postgres/push_fingerprint.go)
- [`internal/postgres/search_content.go`](../../internal/postgres/search_content.go)

## 验证方式
单元 SQL 构造可运行 `go test ./internal/postgres -run <TestName>`；schema/push/查询语义需用专用 PG 数据库，并按 [`storage.md`](./storage.md) 的 `make test-postgres` 或 `TEST_PG_URL` 流程验证。不要对生产 schema 运行测试。
