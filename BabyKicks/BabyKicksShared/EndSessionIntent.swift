import ActivityKit
import AppIntents

struct EndSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "End session"
    static var description = IntentDescription("Ends the completed counting session.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        for activity in Activity<KickActivityAttributes>.activities {
            await activity.end(
                ActivityContent(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        return .result()
    }
}
