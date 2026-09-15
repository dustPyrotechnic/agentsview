# Agent 模块记忆

本目录是 agentsview 的按需记忆层。根目录 `AGENTS.md` 只保留路由；处理具体模块时，先读取对应模块记忆，再按其中的“继续阅读”指针深入源码和专题指南。

## 使用顺序

1. 先确认任务涉及的模块边界。
2. 读取对应 `module-*.md`，只加载当前任务需要的深入资料。
3. 涉及专题规则时，再读取 `testing.md`、`storage.md`、`background-work.md` 或 `build.md`。
4. 修改完成后，按模块记忆中的验证路径验证，不把本索引当作命令清单。

## 模块路由

| 模块 | 记忆文件 | 主要边界 |
| --- | --- | --- |
| CLI 与进程入口 | [`module-cmd.md`](module-cmd.md) | 命令解析、服务启动、CLI 编排 |
| HTTP 服务 | [`module-server.md`](module-server.md) | API、SSE、HTTP 层与客户端契约 |
| 同步与发现 | [`module-sync.md`](module-sync.md) | 会话发现、文件监听、同步调度 |
| SQLite 存储 | [`module-db.md`](module-db.md) | 本地归档、迁移、查询 |
| PostgreSQL | [`module-postgres.md`](module-postgres.md) | PostgreSQL 镜像与读写路径 |
| DuckDB | [`module-duckdb.md`](module-duckdb.md) | DuckDB 镜像与 Quack 读取 |
| 向量搜索 | [`module-vector.md`](module-vector.md) | 语义、混合搜索与索引 |
| 会话解析 | [`module-parser.md`](module-parser.md) | Agent 文件格式与统一会话模型 |
| Web 前端 | [`module-frontend.md`](module-frontend.md) | Svelte 应用、状态、API 展示 |
| 桌面应用 | [`module-desktop.md`](module-desktop.md) | 桌面壳、sidecar、打包分发 |

记忆文件描述代码边界和导航，不替代源码、测试或 `README.md` / `Makefile` 等事实来源。模块结构变化时，同步更新对应记忆文件和本索引。
