# `internal/db`

## 职责
SQLite 主归档（`sessions.db`）及其读写抽象：会话、消息、工具调用/结果、用量、分析、全文搜索、同步状态与 artifact 导入/导出。`DB` 同时维护 writer/reader 连接池和 schema/data-version 初始化。

## 边界
- 这是系统记录；不可用删除、drop、truncate 或重建旧库来处理数据版本。参见 [`storage.md`](./storage.md)。
- 解析器数据变化通过 `dataVersion` 标记 `NeedsResync()`；完整 resync 应创建新库、复制孤儿数据并原子替换。
- `Reader` 只承载受保护的查询访问；写入经 `Update`/批量写 API，不能绕过 writer 生命周期。
- PostgreSQL/DuckDB 的后端实现不应在此包内添加。

## 关键入口与数据流
- [`Open`](../../internal/db/db.go) 创建/初始化归档；[`OpenReadOnly`](../../internal/db/db.go) 用于冷读。
- `init` 执行 schema、列迁移、索引/触发器、sync marker 与自动化/覆盖率回填。
- [`SessionBatchWrite`](../../internal/db/session_batch.go) 是解析结果进入归档的批量边界；同步/镜像读取会话与变更标记。
- `Get*` 查询实现会话分页、消息窗口、活动/用量/分析；`Update` 提供事务提交/回滚。
- artifact publication/import 文件族维护跨设备 checkpoint、队列、阶段状态和 provenance。

## 常见修改路径
1. 新增持久化字段：更新 schema/列迁移、模型扫描、批量写入和所有镜像投影；递增 `dataVersion`（若改变解析结果），确认旧数据如何回填。
2. 改查询语义：先复用 `AnalyticsFilter`/排序/分页构造器，再同步检查 PostgreSQL 与 DuckDB 的等价行为。
3. 变更 archive 文件生命周期：保留 writer barrier、WAL checkpoint、连接 drain 与原子替换语义。
4. artifact 变更：沿 queue → claim/attempt → stage/landing → publication 的事务边界修改，避免部分确认。

## 必须继续读取
- [`storage.md`](./storage.md)、[`testing.md`](./testing.md)
- [`internal/db/store.go`](../../internal/db/store.go)、[`internal/db/schema.sql`](../../internal/db/schema.sql)
- [`internal/db/session_batch.go`](../../internal/db/session_batch.go)、[`internal/db/sessions.go`](../../internal/db/sessions.go)
- [`internal/db/artifact_publication.go`](../../internal/db/artifact_publication.go)、[`internal/db/artifact_import.go`](../../internal/db/artifact_import.go)

## 验证方式
针对性运行 `go test ./internal/db -run <TestName>`；schema/迁移改动至少覆盖临时 SQLite 的 `Open`、重开、旧版本迁移和事务回滚。不要用生产归档做破坏性实验。
