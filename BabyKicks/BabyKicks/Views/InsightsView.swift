import Charts
import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var store: KickStore

    private var recentDays: [(date: Date, count: Int)] {
        let calendar = Calendar.current
        return (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: .now) else { return nil }
            let count = store.events.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }.count
            return (calendar.startOfDay(for: date), count)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                overview
                weeklyChart
                sessions
                futureAnalysis
            }
            .padding()
        }
        .background(AppTheme.cream.opacity(0.55))
        .navigationTitle("Insights")
    }

    private var overview: some View {
        HStack(spacing: 12) {
            metric(title: "Today", value: "\(store.todayCount)", icon: "sun.max.fill")
            metric(title: "All time", value: "\(store.events.count)", icon: "heart.fill")
        }
    }

    private func metric(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.berry)
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Last 7 days")
                .font(.headline)
            Chart(recentDays, id: \.date) { item in
                BarMark(
                    x: .value("Day", item.date, unit: .day),
                    y: .value("Movements", item.count)
                )
                .foregroundStyle(AppTheme.berry.gradient)
                .cornerRadius(5)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 190)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
    }

    private var sessions: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recent sessions")
                    .font(.headline)
                Spacer()
                Text("2h gap")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.berry)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppTheme.blush, in: Capsule())
            }

            if store.inferredSessions().isEmpty {
                ContentUnavailableView(
                    "No movement yet",
                    systemImage: "chart.bar",
                    description: Text("Your first recorded movement will appear here.")
                )
            } else {
                ForEach(store.inferredSessions().prefix(5)) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.start, format: .dateTime.weekday(.wide).month().day())
                                .font(.subheadline.weight(.semibold))
                            Text(session.start, format: .dateTime.hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(session.events.count)")
                            .font(.title3.bold())
                        Text("moves")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if session.id != store.inferredSessions().prefix(5).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
    }

    private var futureAnalysis: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Built to grow", systemImage: "sparkles")
                .font(.headline)
            Text("This view reads raw events through a separate analysis layer, so trends, usual active hours, session goals, and clinician-friendly summaries can be added without changing the database.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(AppTheme.blush.opacity(0.55), in: RoundedRectangle(cornerRadius: 22))
    }
}
