import ActivityKit
import Combine
import Foundation

@MainActor
final class SessionManager: ObservableObject {
    static let duration: TimeInterval = 2 * 60 * 60

    @Published private(set) var endsAt: Date?
    @Published private(set) var sessionKickCount = 0
    @Published private(set) var lastError: String?

    var isActive: Bool {
        guard let endsAt else { return false }
        return endsAt > .now
    }

    init() {
        if let saved = UserDefaults.standard.object(forKey: "activeSessionEndsAt") as? Date, saved > .now {
            endsAt = saved
        }
    }

    func start() {
        let now = Date()
        let end = now.addingTimeInterval(Self.duration)
        endsAt = end
        sessionKickCount = 0
        UserDefaults.standard.set(end, forKey: "activeSessionEndsAt")

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            let attributes = KickActivityAttributes(startedAt: now, endsAt: end)
            let state = KickActivityAttributes.ContentState(kickCount: 0, lastKickAt: nil)
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: end),
                pushType: nil
            )
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stop() {
        endsAt = nil
        UserDefaults.standard.removeObject(forKey: "activeSessionEndsAt")
        let finalState = KickActivityAttributes.ContentState(
            kickCount: sessionKickCount,
            lastKickAt: nil
        )
        Task {
            for activity in Activity<KickActivityAttributes>.activities {
                await activity.end(
                    ActivityContent(state: finalState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
        }
    }

    func registerKick() {
        let activities = Activity<KickActivityAttributes>.activities.filter {
            $0.attributes.endsAt > .now
        }
        guard !activities.isEmpty else { return }

        Task {
            for activity in activities {
                do {
                    let count = try KickDatabase.shared.count(
                        from: activity.attributes.startedAt,
                        through: .now
                    )
                    sessionKickCount = count
                    let state = KickActivityAttributes.ContentState(
                        kickCount: count,
                        lastKickAt: .now
                    )
                    await activity.update(
                        ActivityContent(state: state, staleDate: activity.attributes.endsAt)
                    )
                    lastError = nil
                } catch {
                    lastError = error.localizedDescription
                }
            }
        }
    }

    func refreshFromLiveActivity() {
        guard let activity = Activity<KickActivityAttributes>.activities.first else {
            if !isActive {
                endsAt = nil
            }
            return
        }
        endsAt = activity.attributes.endsAt
        sessionKickCount = (try? KickDatabase.shared.count(
            from: activity.attributes.startedAt,
            through: .now
        )) ?? activity.content.state.kickCount
        UserDefaults.standard.set(activity.attributes.endsAt, forKey: "activeSessionEndsAt")

        let state = KickActivityAttributes.ContentState(
            kickCount: sessionKickCount,
            lastKickAt: activity.content.state.lastKickAt
        )
        Task {
            await activity.update(
                ActivityContent(state: state, staleDate: activity.attributes.endsAt)
            )
        }
    }
}
