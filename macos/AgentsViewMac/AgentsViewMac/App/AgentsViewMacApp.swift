import SwiftUI
import AppKit

@main
struct AgentsViewMacApp: App {
    @State private var dashboardModel = DashboardModel { _, _ in
        throw NSError(domain: "AgentsView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Usage service unavailable"])
    }
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
