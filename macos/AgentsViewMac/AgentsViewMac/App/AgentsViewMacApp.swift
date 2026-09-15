import SwiftUI

@main
struct AgentsViewMacApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardPlaceholderView()
        }
    }
}

struct DashboardPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("AgentsView Dashboard")
                .font(.title)
            
            Text("Native macOS client loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 800, minHeight: 600)
        .padding()
    }
}
