import StatsKit
import Storage
import SwiftUI

/// Side table: today's date, period averages, ao5/ao12/ao100, and all of today's solves.
struct StatsPanel: View {
    let stats: StatsSummary?
    /// Today's solves, newest first.
    let todaysSolves: [Solve]
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

    /// One grid for everything, so today's solves line up with the stats columns.
    private var content: some View {
        Grid(alignment: .trailing, horizontalSpacing: 20, verticalSpacing: 10) {
            Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
            separator

            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                header("avg")
            }
            statRow("today", stats?.today)
            statRow("7 days", stats?.last7Days)
            statRow("30 days", stats?.last30Days)
            Color.clear.frame(height: 14).gridCellUnsizedAxes(.horizontal)
            statRow("ao5", stats?.ao5)
            statRow("ao12", stats?.ao12)
            statRow("ao100", stats?.ao100)

            if !todaysSolves.isEmpty {
                separator
                header("Today's scrambles")
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(todaysSolves) { solve in
                    GridRow {
                        Text(solve.createdAt, format: .dateTime.hour().minute())
                            .foregroundStyle(.tertiary)
                            .gridColumnAlignment(.leading)
                        Text(solve.result.formatted)
                    }
                }
            }
        }
        .font(.system(size: 15, design: .monospaced))
        .monospacedDigit()
        .padding(28)
    }

    /// Thin line spanning the grid, between the date, the stats and the solve list.
    private var separator: some View {
        Divider()
            .gridCellUnsizedAxes(.horizontal)
            .padding(.vertical, 8)
    }

    private func header(_ title: String) -> some View {
        Text(title).foregroundStyle(.tertiary)
    }

    /// The label column takes the spare width, pushing the values to the right edge.
    private func label(_ title: String) -> some View {
        Text(title)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .gridColumnAlignment(.leading)
    }

    private func statRow(_ title: String, _ stat: Stat?) -> some View {
        GridRow {
            label(title)
            Text((stat ?? .none).formatted)
        }
    }
}

#Preview {
    StatsPanel(stats: nil, todaysSolves: [], date: .now)
}
