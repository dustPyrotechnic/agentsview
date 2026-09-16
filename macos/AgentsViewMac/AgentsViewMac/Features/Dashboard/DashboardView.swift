import SwiftUI

struct DashboardView: View {
    let model: DashboardModel
    let sidecar: SidecarManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch model.state {
            case .loading: ProgressView("Loading usage…").controlSize(.small)
            case .error(let message): ContentUnavailableView("Usage unavailable", systemImage: "exclamationmark.triangle", description: Text(message))
            case .empty: ContentUnavailableView("No usage yet", systemImage: "chart.bar.xaxis", description: Text("Usage will appear after your first session."))
            case .success:
                if let summary = model.summary { dashboard(summary) }
                else { ContentUnavailableView("No usage yet", systemImage: "chart.bar.xaxis") }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .padding(24)
        .task {
            do {
                try await sidecar.start()
            } catch {
                // Refresh presents the actionable backend error in the view.
            }
            await model.refresh()
        }
    }

    @ViewBuilder private func dashboard(_ summary: UsageSummaryResponse) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Usage overview").font(.largeTitle.bold())
                        Text("\(summary.from) – \(summary.to)").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { Task { await model.refresh() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }.help("Refresh usage")
                }
                summaryCards(summary)
                HStack(alignment: .top, spacing: 16) {
                    chartCard(summary)
                    rankingCard(title: "Top models", icon: "cpu", rows: summary.modelTotals.map { ($0.model, $0.cost.microdollars, $0.inputTokens + $0.outputTokens) })
                }
                rankingCard(title: "Top projects", icon: "folder", rows: summary.projectTotals.map { ($0.project, $0.cost.microdollars, $0.inputTokens + $0.outputTokens) })
                if summary.unsupportedUsage != nil { Label("Some usage is unpriced", systemImage: "questionmark.circle").foregroundStyle(.orange) }
            }
        }
    }
    private func summaryCards(_ summary: UsageSummaryResponse) -> some View {
        let tokens = summary.totals.inputTokens + summary.totals.outputTokens + summary.totals.cacheCreationTokens + summary.totals.cacheReadTokens
        return HStack(spacing: 12) {
            metric("Tokens", value: tokens.formatted())
            metric("Actual cost", value: formatMicrodollars(summary.totals.totalCost.microdollars))
            metric("Sessions", value: summary.sessionCounts.total.formatted())
            if let comparison = summary.comparison { metric("vs prior", value: formatComparison(comparison.deltaPct)) }
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.title3.monospacedDigit().bold()) }
            .frame(maxWidth: .infinity, alignment: .leading).padding(14).background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .combine).accessibilityLabel("\(title), \(value)")
    }

    private func chartCard(_ s: UsageSummaryResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Daily cost", systemImage: "chart.xyaxis.line").font(.headline)
            UsageLineChart(series: UsageChartSeries(daily: s.daily), reduceMotion: reduceMotion).frame(height: 170)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }

    private func rankingCard(title: String, icon: String, rows: [(String, Int64, Int)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.headline)
            ForEach(Array(rows.sorted { $0.1 > $1.1 }.prefix(5).enumerated()), id: \.offset) { _, row in
                HStack { Text(row.0).lineLimit(1); Spacer(); Text(formatMicrodollars(row.1)).monospacedDigit().foregroundStyle(.secondary); Text(row.2.formatted()).font(.caption).foregroundStyle(.tertiary) }
            }
            if rows.isEmpty { Text("No data").foregroundStyle(.secondary) }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct UsageLineChart: View {
    let series: UsageChartSeries
    let reduceMotion: Bool
    var body: some View {
        Canvas { context, size in
            guard !series.points.isEmpty else { return }
            let maxValue = max(series.domain.upperBound, 1)
            let step = size.width / CGFloat(max(series.points.count - 1, 1))
            var path = Path()
            for (index, point) in series.points.enumerated() {
                let x = CGFloat(index) * step
                let y = size.height - CGFloat(Double(point.value) / maxValue) * size.height
                index == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
            }
            context.stroke(path, with: .color(.accentColor), lineWidth: 2)
        }.accessibilityElement().accessibilityLabel("Daily cost chart").accessibilityValue("\(series.points.count) days")
    }
}
