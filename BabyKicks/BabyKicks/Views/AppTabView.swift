import SwiftUI

struct AppTabView: View {
    var body: some View {
        TabView {
            Tab("Track", systemImage: "hand.tap.fill") {
                NavigationStack {
                    TrackView()
                }
            }

            Tab("Insights", systemImage: "chart.xyaxis.line") {
                NavigationStack {
                    InsightsView()
                }
            }

            Tab("Settings", systemImage: "gearshape.fill") {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tint(AppTheme.berry)
    }
}

enum AppTheme {
    static let berry = Color(red: 0.67, green: 0.25, blue: 0.43)
    static let blush = Color(red: 0.98, green: 0.89, blue: 0.91)
    static let cream = Color(red: 1.0, green: 0.98, blue: 0.95)
    static let ink = Color(red: 0.22, green: 0.16, blue: 0.19)
}
