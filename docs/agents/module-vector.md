# `internal/vector`

## 职责
维护 `vectors.db` 中的 embedding 镜像与 sqlite-vec 索引：按可配置 `IndexSpec` 管理 message/recall 两个独立 store，刷新可嵌入文档、构建/激活 generation、分块 embedding、搜索、修复和向 PG 导出的快照。

## 边界
- vectors.db 是可丢弃派生镜像，不等同于 `internal/db` 的 SQLite archive；版本不匹配时写路径重建，读路径返回 `ErrMirrorVersionMismatch`。不要做 in-place 迁移。
- 不跨 `IndexSpec` 读取或删除表；每个 spec 的 mirror、metadata、kit 表名必须互不重叠。
- 构建只通过 `UnitSource.ScanEmbeddableUnits` 获取内容；encoder 负责 OpenAI-compatible/Ollama HTTP，必须验证维度、NaN/Inf/零范数和错误可重试性。
- 导出只允许 active generation 且 coverage 完整；`BeginExport` 持有一致性读事务。

## 关键入口与数据流
- [`Open`/`OpenSpec`](../../internal/vector/index.go) 注册 sqlite-vec、打开 vectors.db、检查/准备 mirror schema，并绑定 split overlap。
- [`Refresh`](../../internal/vector/mirror.go) 将 db.EmbeddableUnit 写入镜像，按 content hash 和 scope 删除/更新文档。
- [`Build`](../../internal/vector/build.go) resolve generation → refresh → 分 chunk 编码 → 写 stamps/chunks → activate；`manager.go` 负责 encoder 选择、并发构建状态与生命周期拒绝。
- [`Search`](../../internal/vector/search.go) 组合全文/向量候选并返回命中；`repair.go` 处理缺失/失效 embedding。
- [`Export`](../../internal/vector/export.go) 输出 generation、文档、chunk、hash，供 PostgreSQL vector push 使用。

## 常见修改路径
1. 改文档身份或分块：同步 `DocKey`、`ChunkOverlap`、fingerprint、refresh 删除和 export；确认旧镜像必须重建。
2. 新增 generation 状态：同时更新 schema、coverage 查询、manager refusal matrix、CLI-facing `GenerationInfo`。
3. 改 encoder：保持批量顺序与 response index 对齐；保留 HTTP retry/backoff、Ollama CPU fallback 及永久错误分类。
4. 新增 spec：分配完全不重叠的表前缀/metadata，定义 scope 能力与 schema 版本，并为 refresh/build/search/export 各自接入。

## 必须继续读取
- [`storage.md`](./storage.md)、[`internal/vector/index.go`](../../internal/vector/index.go)
- [`internal/vector/mirror.go`](../../internal/vector/mirror.go)、[`build.go`](../../internal/vector/build.go)、[`manager.go`](../../internal/vector/manager.go)
- [`internal/vector/search.go`](../../internal/vector/search.go)、[`encoder.go`](../../internal/vector/encoder.go)、[`export.go`](../../internal/vector/export.go)
- `internal/postgres/vector_push.go` 与 `vector_schema.go`

## 验证方式
运行针对性 `go test ./internal/vector -run <TestName>`；重点覆盖临时 vectors.db 的 schema/version mismatch、refresh/build generation 生命周期、encoder response 校验、搜索与 export readiness。不要用生产 vectors.db 做 reset 测试。
