import StatsKit
import Storage
import SwiftUI

/// Side table: today's date, period averages/means and the current ao5/ao12/ao100.
struct StatsPanel: View {
    let stats: StatsSummary?
    let recentSolves: [Solve]
    let date: Date

    var body: some View {
        // Scrolls when the window is too short; centered vertically when it fits.
        GeometryReader { geo in
            ScrollView(.vertical) {
                content
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
                .foregroundStyle(.secondary)

            Grid(alignment: .trailing, horizontalSpacing: 20, verticalSpacing: 10) {
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    header("avg")
                    header("mean")
                }
                periodRow("today", stats?.today)
                periodRow("7 days", stats?.last7Days)
                periodRow("30 days", stats?.last30Days)
                Color.clear.frame(height: 14).gridCellUnsizedAxes(.horizontal)
                statRow("ao5", stats?.ao5)
                statRow("ao12", stats?.ao12)
                statRow("ao100", stats?.ao100)
            }

            if !recentSolves.isEmpty {
                recentSolvesList
            }
        }
        .font(.system(size: 15, design: .monospaced))
        .monospacedDigit()
        .padding(28)
    }

    /// Today's latest solves, in smaller type.
    private var recentSolvesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("today's last \(recentSolves.count)")
                .foregroundStyle(.tertiary)
            Grid(alignment: .trailing, horizontalSpacing: 20, verticalSpacing: 5) {
                ForEach(recentSolves) { solve in
                    GridRow {
                        Text(solve.createdAt, format: .dateTime.hour().minute())
                            .foregroundStyle(.tertiary)
                            .gridColumnAlignment(.leading)
                        Text(solve.result.formatted)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .font(.system(size: 12, design: .monospaced))
    }

    private func header(_ title: String) -> some View {
        Text(title).foregroundStyle(.tertiary)
    }

    private func label(_ title: String) -> some View {
        Text(title)
            .foregroundStyle(.secondary)
            .gridColumnAlignment(.leading)
    }

    private func periodRow(_ title: String, _ period: PeriodStats?) -> some View {
        GridRow {
            label(title)
            Text((period?.average ?? .none).formatted)
            Text((period?.mean ?? .none).formatted)
        }
    }

    /// Rolling averages go in the "avg" column.
    private func statRow(_ title: String, _ stat: Stat?) -> some View {
        GridRow {
            label(title)
            Text((stat ?? .none).formatted)
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
        }
    }
}

#Preview {
    StatsPanel(stats: nil, recentSolves: [], date: .now)
}
