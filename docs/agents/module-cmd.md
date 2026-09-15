# CLI 与进程入口

## 职责
`cmd/agentsview` 是 Cobra 命令树和进程生命周期编排层：把 flags/config 转成服务、同步、查询、导入导出等调用，并统一退出码与用户输出。业务规则主要在 `internal/*`；这里负责选择后端、daemon transport 和命令级错误呈现。

## 边界
- 根命令在 [`cli.go`](../../cmd/agentsview/cli.go) 的 `newRootCommand` 注册命令、分组和 `--version`；无参数只显示帮助。
- `serve`/`daemon` 负责前台或后台 writable SQLite server 生命周期；`sync` 负责本地/远端刷新及 artifact exchange。只读查询通常走 daemon 或只读 SQLite，需新鲜数据/写入的命令会启动 daemon（详见 [`commands.md`](../commands.md)）。
- 退出码由 `cliExitError` 包装，默认失败码为 1；不要在命令内部直接 `os.Exit`。

## 关键入口与数据流
1. `newRootCommand` 注册各命令。
2. `newServeCommandWithDaemonDeps` 根据 flags 选择版本检查、后台启动或 `runServe`。
3. `newSyncCommandWithRunner` 收集 `SyncConfig`；`runSync`/artifact sync 选择 daemon transport、直接本地 DB 或远端路径。
4. daemon runtime 记录由 `daemon_runtime.go` 的 `FindDaemonRuntime`/`FindWritableDaemonRuntime` 发现，写入与启动协调在 `daemon.go`、`serve_lifecycle.go`。

## 常见修改路径
- 新命令：在独立文件提供 `new<Name>Command` 与 `run<Name>`，在 `newRootCommand` 注册，补充该命令 focused tests。
- 新 serve/sync flag：先更新命令绑定与 `config.Config`/transport 选择，再更新 `docs/commands.md`；检查 daemon 与 offline (`AGENTSVIEW_NO_DAEMON=1`) 两条路径。
- 新 daemon 生命周期行为：沿 `daemonCommandDeps` 注入 seam，保持 runtime 身份校验和单写者规则，不绕过锁。

## 必须继续读取
- [CLI Reference](../commands.md)：命令、flag、daemon/offline/remote-sync 契约。
- [Remote Access](../remote-access.md)：HTTP/SSH 远端同步与认证。
- [Artifact Sync](../artifact-sync.md)：`sync --target` 的信任边界。
- [Testing Rules](testing.md)：命令测试与最小验证集。
- 源码：[`cli.go`](../../cmd/agentsview/cli.go)、[`daemon.go`](../../cmd/agentsview/daemon.go)、[`daemon_runtime.go`](../../cmd/agentsview/daemon_runtime.go)、[`artifact_sync.go`](../../cmd/agentsview/artifact_sync.go)。

## 验证方式
优先运行 `cmd/agentsview` 的 focused tests（命令 help、flag、daemon/backend 选择），再用 `agentsview <command> --help` 或隔离数据目录做 CLI smoke test。不要把项目级测试当作单个命令行为的证据。
