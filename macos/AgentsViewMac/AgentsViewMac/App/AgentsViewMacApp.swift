import SwiftUI
import AppKit

@MainActor
final class AgentsViewMacAppDelegate: NSObject, NSApplicationDelegate {
    let sidecarManager = SidecarManager()

    func applicationWillTerminate(_ notification: Notification) {
        sidecarManager.stopImmediately()
    }
}

@main
struct AgentsViewMacApp: App {
    @NSApplicationDelegateAdaptor(AgentsViewMacAppDelegate.self) private var appDelegate
    @State private var dashboardModel = DashboardModel(apiClient: APIClient(baseURL: URL(string: "http://127.0.0.1:8080")!))
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup(id: "dashboard") {
            DashboardView(model: dashboardModel, sidecar: appDelegate.sidecarManager)
        }
        MenuBarExtra("AgentsView", systemImage: "chart.bar.xaxis") {
            UsageMenuBarView(model: dashboardModel, openWindow: { openWindow(id: "dashboard") }, quit: { NSApp.terminate(nil) })
        }
    }
}
