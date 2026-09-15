import SwiftUI
import AppKit

@main
struct AgentsViewMacApp: App {
    @State private var dashboardModel = DashboardModel(apiClient: APIClient(baseURL: URL(string: "http://127.0.0.1:8080")!))
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup(id: "dashboard") {
            DashboardView(model: dashboardModel)
        }
        MenuBarExtra("AgentsView", systemImage: "chart.bar.xaxis") {
            UsageMenuBarView(model: dashboardModel, openWindow: { openWindow(id: "dashboard") }, quit: { NSApp.terminate(nil) })
        }
    }
}
