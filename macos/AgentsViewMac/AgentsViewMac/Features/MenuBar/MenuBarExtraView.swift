import SwiftUI

struct UsageMenuBarView: View {
    let model: DashboardModel
    var openWindow: () -> Void
    var quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if case .success = model.state, let summary = model.summary {
                let total = summary.totals.inputTokens + summary.totals.outputTokens + summary.totals.cacheCreationTokens + summary.totals.cacheReadTokens
                Text("\(total.formatted()) tokens").font(.headline)
                LabeledContent("Actual cost", value: formatMicrodollars(summary.totals.totalCost.microdollars))
                LabeledContent("Estimated cost", value: summary.pricing == nil ? "Unpriced" : formatMicrodollars(summary.totals.totalCost.microdollars))
                Text("Updated just now").font(.caption).foregroundStyle(.secondary)
            } else { Text("Loading usage…").foregroundStyle(.secondary) }
            Divider()
            Button { Task { await model.refresh() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
            Button(action: openWindow) { Label("Open Dashboard", systemImage: "macwindow") }
            Button(action: quit) { Label("Quit AgentsView", systemImage: "power") }
        }
        .padding(12)
        .frame(width: 240)
    }
}
