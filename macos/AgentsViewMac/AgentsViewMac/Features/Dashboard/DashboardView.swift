import SwiftUI

struct DashboardView: View {
    let model: DashboardModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch model.state {
            case .idle, .loading: ProgressView("Loading usage…").controlSize(.small)
            case .failed: ContentUnavailableView("Usage unavailable", systemImage: "exclamationmark.triangle", description: Text("Try refreshing the usage data."))
            case .empty: ContentUnavailableView("No usage yet", systemImage: "chart.bar.xaxis", description: Text("Usage will appear after your first session."))
            case .loaded(let summary): dashboard(summary)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .padding(24)
        .task { if case .idle = model.state { await model.load() } }
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
                    Picker("Range", selection: Binding(get: { model.range }, set: { value in Task { await model.changeRange(value) } })) {
                        ForEach(UsageRange.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }.pickerStyle(.segmented).frame(width: 220)
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

    private func summaryCards(_ s: UsageSummaryResponse) -> some View {
        let tokens = s.totals.inputTokens + s.totals.outputTokens + s.totals.cacheCreationTokens + s.totals.cacheReadTokens
        return HStack(spacing: 12) {
            metric("Tokens", value: tokens.formatted())
            metric("Actual cost", value: formatMicrodollars(s.totals.totalCost.microdollars))
            metric("Sessions", value: s.sessionCounts.total.formatted())
            if let comparison = s.comparison { metric("vs prior", value: formatComparison(comparison.deltaPct)) }
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
