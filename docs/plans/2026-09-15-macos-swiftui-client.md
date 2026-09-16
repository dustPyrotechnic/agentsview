# macOS SwiftUI Client Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use subagent-driven-development to implement this plan task-by-task.

**Goal:** Build a native macOS SwiftUI client backed by the existing Go sidecar, with native Token/cost charts and a menu-bar usage summary.

**Architecture:** Add an independent `macos/` SwiftUI target. Swift owns app lifecycle, sidecar process management, API decoding, view models, native charts, and `MenuBarExtra`; Go remains the single source of truth for SQLite, parsing, synchronization, pricing, and aggregation. Reuse `/api/v1/usage/summary` before adding any compatible Go fields.

**Tech Stack:** Swift 6, SwiftUI, Observation (`@Observable`), Foundation `URLSession`/`Process`, macOS `MenuBarExtra`, Go/Huma HTTP API, existing SQLite archive.

---

### Task 1: Establish macOS project and shared build contract

**Files:**
- Create: `macos/AgentsViewMac/AgentsViewMac.xcodeproj`
- Create: `macos/AgentsViewMac/AgentsViewMac/App/AgentsViewMacApp.swift`
- Create: `macos/AgentsViewMac/AgentsViewMac/Resources/Info.plist`
- Create: `macos/README.md`
- Test: macOS build target

**Steps:**
1. Create a macOS SwiftUI application target with a `WindowGroup` and a placeholder dashboard root.
2. Configure minimum supported macOS version from repository/release constraints; keep bundle identifier and signing values configurable.
3. Add app resources and development sidecar path configuration without embedding secrets.
4. Document local build/run commands and the sidecar binary expectation.
5. Build the target with `xcodebuild -project ... -scheme ... build` and confirm the app target compiles.
6. Commit as `build: add native macOS SwiftUI target`.

### Task 2: Define API models and client against usage summary

**Files:**
- Create: `macos/AgentsViewMac/AgentsViewMac/Core/API/APIClient.swift`
- Create: `macos/AgentsViewMac/AgentsViewMac/Core/API/UsageModels.swift`
- Create: `macos/AgentsViewMac/AgentsViewMac/Core/API/APIError.swift`
- Create: `macos/AgentsViewMac/AgentsViewMacTests/APIClientTests.swift`
- Reference: `internal/server/usage.go`, existing server API tests

**Steps:**
1. Write tests for successful `{code,message,data}` decoding, non-zero API code, malformed payload, microdollar cost, and unknown optional fields.
2. Run the focused Swift tests and confirm the new tests fail before implementation.
3. Implement Codable models only for the fields needed by Dashboard/menu/chart layers: range, totals, daily entries, model/project totals, comparison, pricing and unsupported usage.
4. Implement URL construction for date range/timezone and a single `APIClient` request path that validates the response envelope.
5. Run the focused tests and confirm they pass.
6. Commit as `feat: add Swift usage API client`.

### Task 3: Implement Go-side contract additions only if required

**Files:**
- Modify: `internal/server/usage.go`
- Modify: `internal/server/huma_routes_usage.go`
- Test: `internal/server/usage_internal_test.go`, `internal/server/server_test.go`

**Steps:**
1. Compare Task 2 models with the existing OpenAPI response; do not add a new endpoint if existing fields express actual cost, estimated cost, and unpriced usage safely.
2. If an estimated-cost field is missing, write a failing HTTP/OpenAPI test defining its exact backward-compatible semantics and field type.
3. Implement the smallest service-to-response mapping; keep Go as the only cost calculator and preserve `{code,message,data}`.
4. Update OpenAPI assertions and focused server tests.
5. Run `go test ./internal/server -run 'Usage|Analytics|OpenAPI'`.
6. Run `go fmt ./...` and `go vet ./...` before committing as `feat: expose usage estimate for native client`.

### Task 4: Implement sidecar lifecycle manager

**Files:**
- Create: `macos/AgentsViewMac/AgentsViewMac/Core/Sidecar/SidecarManager.swift`
- Create: `macos/AgentsViewMac/AgentsViewMac/Core/Sidecar/SidecarState.swift`
- Create: `macos/AgentsViewMac/AgentsViewMacTests/SidecarManagerTests.swift`

**Steps:**
1. Write tests for stopped → starting → ready, early process exit, health-check timeout, and graceful stop timeout using injected process/probe seams.
2. Run the focused tests and confirm they fail.
3. Implement an actor or `@MainActor`-safe manager around `Process`, local port discovery, health probing, cancellation, and graceful termination.
4. Preserve sidecar arguments `serve --background --host 127.0.0.1`; keep executable lookup bundle-first with a development override.
5. Run the focused tests and confirm state transitions pass.
6. Commit as `feat: manage Go sidecar lifecycle`.

### Task 5: Build usage view model and native chart model

**Files:**
- Create: `macos/AgentsViewMac/AgentsViewMac/Features/Dashboard/DashboardModel.swift`
- Create: `macos/AgentsViewMac/AgentsViewMac/Features/Usage/ChartModels.swift`
- Create: `macos/AgentsViewMac/AgentsViewMacTests/DashboardModelTests.swift`
- Create: `macos/AgentsViewMac/AgentsViewMacTests/ChartModelsTests.swift`

**Steps:**
1. Write behavior tests for loading/success/empty/error, refresh cancellation, date-range switching, single-point series, all-zero values, equal maxima, and negative comparison.
2. Run focused tests and confirm they fail.
3. Implement `@Observable @MainActor` Dashboard state and chart preparation that consumes API models without recomputing costs.
4. Normalize chart domains and labels deterministically; keep money in microdollars/Decimal until formatting.
5. Run focused tests and confirm they pass.
6. Commit as `feat: model native usage dashboard`.

### Task 6: Implement native SwiftUI dashboard and charts

**Files:**
- Create: `macos/AgentsViewMac/AgentsViewMac/Features/Dashboard/DashboardView.swift`
- Create: `macos/AgentsViewMac/AgentsViewMac/Features/Dashboard/UsageSummaryCards.swift`
- Create: `macos/AgentsViewMac/AgentsViewMac/Features/Usage/NativeUsageChart.swift`
- Create: `macos/AgentsViewMac/AgentsViewMac/Features/Usage/ModelBreakdownView.swift`
- Reference: `skill://swiftui-specialist` references for structure/dataflow/foreach/localization

**Steps:**
1. Implement summary cards for total tokens, actual cost, estimated cost, comparison, and unpriced usage.
2. Implement native `Canvas`/`Path` chart rendering for daily cost/tokens, semantic colors, grid/labels, hover selection and selected-point detail.
3. Add responsive layout for narrow windows, empty/loading/error states, dark mode, Reduce Motion, and accessible labels/values.
4. Add model/project breakdown views with stable IDs and no `AnyView`/third-party chart dependency.
5. Build and run the app target; visually inspect the actual dashboard in macOS.
6. Commit as `feat: add native usage dashboard charts`.

### Task 7: Add menu-bar usage summary and window actions

**Files:**
- Modify: `macos/AgentsViewMac/AgentsViewMac/App/AgentsViewMacApp.swift`
- Create: `macos/AgentsViewMac/AgentsViewMac/Features/MenuBar/MenuBarView.swift`
- Create: `macos/AgentsViewMac/AgentsViewMac/Features/MenuBar/MenuBarModel.swift`
- Create: `macos/AgentsViewMac/AgentsViewMacTests/MenuBarModelTests.swift`

**Steps:**
1. Write tests that menu-bar totals and formatting use the same usage snapshot as Dashboard, including unavailable and unpriced states.
2. Run focused tests and confirm failure.
3. Implement `MenuBarExtra` with Token/cost label, actual/estimated cost, last update, refresh, open window, settings placeholder, and quit actions.
4. Add low-frequency refresh plus cancellation when the app exits; avoid duplicate polling tasks.
5. Run focused tests and build the macOS target.
6. Commit as `feat: add macOS usage menu bar item`.

### Task 8: Integrate, document, and smoke test

**Files:**
- Modify: `macos/README.md`
- Modify: `docs/agents/module-desktop.md` only if durable architecture pointers changed

**Steps:**
1. Integrate the independent worktrees without overwriting unrelated user changes.
2. Run Swift focused tests, Go focused server tests, `go fmt ./...`, and `go vet ./...`.
3. Build a macOS `.app` with the documented `xcodebuild` command.
4. Launch the actual app with a controlled local archive/sidecar, exercise startup, Dashboard load, range refresh, menu-bar display, disconnect/restart, and quit.
5. Verify no secrets appear in sidecar logs and existing Tauri files remain unchanged.
6. Update only the necessary README/build instructions and commit as `feat: ship native macOS client foundation`.

## Parallel execution contract

Tasks 2, 4, and 5 can proceed in separate worktrees after Task 1 establishes the project contract; Task 3 is independent once the required API fields are identified. Task 6 depends on Task 5 models. Task 7 depends on Tasks 2, 4, and 5. Task 8 is serialized integration and verification. Every subagent must use full permissions in its own worktree, skip project-wide formatting/lint/test suites, and commit only its owned files.
