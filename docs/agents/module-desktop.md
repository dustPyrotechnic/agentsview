# Desktop 模块

## 职责

`desktop` 是 Tauri 2 原生包装器。它构建并携带现有 Go `agentsview` binary 作为 sidecar，启动 `serve --background --host 127.0.0.1`，等待本地 HTTP 服务就绪后在 WebView 加载 UI；它还提供桌面菜单、macOS 菜单栏状态项、日志、更新和窗口生命周期管理。

## 边界

- Desktop 不重新实现 web app；UI 由 `ui/`（构建产物）提供，业务 API/数据仍由 Go sidecar 提供。
- Rust 入口与绝大多数行为在 [`src-tauri/src/lib.rs`](../../desktop/src-tauri/src/lib.rs)；Tauri 窗口、CSP、sidecar、更新器配置在 [`src-tauri/tauri.conf.json`](../../desktop/src-tauri/tauri.conf.json)。
- sidecar 环境是桌面启动的兼容层：Unix 默认读取 login-shell `env -0`，再合并 `~/.agentsview/desktop.env`；Windows 支持 WSL 路径转换。不要把 shell 探测逻辑迁移到 Go backend。
- 网络边界是 loopback backend；navigation guard 只允许后端/受控外部 URL。更新安装必须先停止后台 sidecar，再安装并恢复 backend。

## 关键入口 / 数据流

1. `run()` 构建 Tauri app、插件、窗口 close 行为和菜单；启动阶段执行数据版本 preflight，再调用 `launch_backend`。
2. `spawn_sidecar` 以 `serve --background --host 127.0.0.1` 启动 binary；stdout/stderr 被转成启动状态、日志记录和错误详情。
3. 监听输出解析端口后，`redirect_when_ready` 导航到 `http://127.0.0.1:<port>?desktop=1`；`wait_for_server`/status probe 维持启动和后台运行状态。
4. sidecar 状态、generation、停止/重启等待器存放在 `SidecarState`；launcher 退出后继续轮询 detached backend，避免把短暂 launcher 退出误报为服务死亡。
5. WebView focus/recovery 处理内容进程死亡或 backend 断连；Linux WebKitGTK 渲染失败时可降级到系统浏览器。
6. 菜单事件连接显示主窗口、打开日志、检查更新和退出；自动/手动 updater 在 `check_for_updates` 中确认、停止 backend、安装并重启。

## 常见修改路径

- 启动/停止行为：从 `sidecar_args`、`spawn_sidecar_with_args`、`handle_sidecar_terminated`、`wait_for_server` 和 generation 状态一起修改，保留启动中、健康、停止超时和重启竞态的语义。
- 环境变量：修改 `sidecar_env`、`read_login_shell_env`、`parse_desktop_env_content` 或 Windows 翻译时，保持父环境、login shell、desktop.env、强制 PATH 的优先级和失败回退。
- WebView 导航/恢复：先检查 `is_allowed_navigation_url`、`recover_webview`、`redirect_when_ready`；只扩大必要的 loopback/受控 URL 范围。
- 菜单栏/macOS：通过 `DesktopMenuAction` 和 `setup_macos_status_item` 接入，窗口关闭应隐藏而非无条件退出；跨平台代码保持 cfg 边界。
- 日志：沿用有界 `SyncSender` 队列和敏感值 redaction；日志文件权限在 Unix 上保持目录 0700、文件 0600。
- 更新器：扩展 updater 前先读停止等待与安装错误类型，确保 backend 停止失败不会安装后遗留两个 sidecar。

## 必须继续读取的资料

- [`desktop/README.md`](../../desktop/README.md)：构建、sidecar 准备、Finder/Explorer 环境说明和可选 overrides。
- [`desktop/src-tauri/src/lib.rs`](../../desktop/src-tauri/src/lib.rs)：状态机、启动、WebView、菜单、日志和更新的实际实现。
- [`desktop/src-tauri/tauri.conf.json`](../../desktop/src-tauri/tauri.conf.json)：窗口尺寸、CSP、externalBin、updater 和平台打包设置。
- [`desktop/scripts/prepare-sidecar.sh`](../../desktop/scripts/prepare-sidecar.sh) 与 `package.json`：sidecar 构建/复制链路；改 binary 名称或 target triple 时必须同步。

## 验证方式

局部 Rust 改动运行 `cargo test --manifest-path desktop/src-tauri/Cargo.toml`（必要时限定测试名），并用 `npm run tauri:dev` 烟测启动、窗口关闭、日志菜单和 sidecar 重启。打包/sidecar 改动再运行对应 `tauri:build:*` 脚本；涉及 WebView 导航或更新时验证实际平台行为和失败路径。