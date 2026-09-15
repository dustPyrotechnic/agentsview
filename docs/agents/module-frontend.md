# Frontend 模块

## 职责

`frontend` 是 Svelte 单页应用：通过生成的 API client/runtime 读取后端数据，将会话、活动、分析、设置、搜索和管理页面组织成响应式 stores 与组件，并负责本地化、URL 状态和 kit-ui 设计系统集成。

## 边界

- [`src/main.ts`](../../frontend/src/main.ts) 只负责安装性能 instrumentation、初始化 Paraglide i18n 并挂载 `App.svelte`；页面路由和全局布局在 [`src/App.svelte`](../../frontend/src/App.svelte)。
- 后端数据访问走 `src/lib/api/generated` 与 `callGenerated` 等 runtime；不要在组件中复制 API 请求或直接重造数据缓存。
- `src/lib/stores` 持有跨页面状态和 URL/事件同步；组件负责呈现和用户交互。页面专属派生逻辑可留在页面/组件附近。
- UI 控件优先使用 `@kenn-io/kit-ui`；根 [`DESIGN.md`](../../DESIGN.md) 和 [`frontend/AGENTS.md`](../../frontend/AGENTS.md) 是控件、CSS、i18n 的约束来源。
- 用户可见文案必须进入 `frontend/messages/*.json` 并保持每个 locale key 集合一致；`src/lib/paraglide` 是生成物，不手改。

## 关键入口 / 数据流

1. `main.ts` 初始化 i18n/perf 后挂载 `App.svelte`。
2. `App.svelte` 根据 `router.route` 选择 Usage、Activity、Trends、Recall、Quality、Pinned、Trash、Recent Edits、Data、Settings 或三栏会话布局，并挂载全局 header/status/modal。
3. `router.svelte.ts` 负责路由和 query；`sessions.svelte.ts` 将 API sidebar/index/metadata 结果转成过滤器、会话组、状态和分页缓存。URL 默认值应保持省略以避免脏链接。
4. 各领域 store（`activity`、`analytics`、`messages`、`search`、`settings`、`sync` 等）通过 generated services/runtime 拉取数据，使用 Svelte 5 `$state`/派生状态驱动组件；同步完成事件会刷新依赖数据。
5. 共享组件从 `@kenn-io/kit-ui` 接收已翻译字符串；应用级 wrapper（如 `RangePicker`、`RefreshControl`、`ProjectTypeahead`）只注入 locale、适配 API 或补充业务语义。

## 常见修改路径

- 新页面：先确认 `router` 的 route/query 约定和 App 分支，再在对应 `components/<domain>` 建页面与测试；跨页面数据放领域 store，不在 App 堆业务状态。
- 新交互控件：先搜索 `src/lib/components` 和 kit-ui 现有控件；复用共享组件和 token，避免新增 native select 或局部 control chrome。
- API 字段/端点变化：从 generated service/types 入手，更新调用方 store 的映射与 loading/error/cancel 行为，再更新组件及 fixture；不要手改生成目录。
- 新文案：在所有 `messages/*.json` 增加相同 key，组件从相对路径导入 `m`，动态句子使用参数化/复数 message。
- URL 可分享状态：在 store 中实现 `parse...FromParams`、`...ToParams`、hydrate/write 双向转换，省略默认值并处理未知参数回退。
- 性能或并发读：沿用 `LatestRead`、abort/error 处理和现有 debounce；先确认 store 的 attach/detach 生命周期，避免页面卸载后继续更新状态。

## 必须继续读取的资料

- [`frontend/AGENTS.md`](../../frontend/AGENTS.md) 与 [`DESIGN.md`](../../DESIGN.md)：Vite+、kit-ui、控件和本地化规则。
- [`frontend/src/App.svelte`](../../frontend/src/App.svelte)：全局布局、路由分支和 modal 生命周期。
- [`frontend/src/lib/stores/sessions.svelte.ts`](../../frontend/src/lib/stores/sessions.svelte.ts)：会话过滤、分页、分组、状态与 URL 约定。
- 目标页面的 store、组件及相邻 `*.test.ts`；API 调用则继续读 `src/lib/api/generated` 与 `src/lib/api/runtime.js`。

## 验证方式

局部逻辑优先运行对应 Vitest 文件；组件/页面变更运行其 Svelte 测试并用 `npm run check` 检查类型和生成 i18n。涉及视觉布局或交互时，在 dev server 中打开实际路由核对 loading、empty、error、窄窗口和键盘路径。不要把 `src/lib/paraglide` 生成文件作为手工修改目标。