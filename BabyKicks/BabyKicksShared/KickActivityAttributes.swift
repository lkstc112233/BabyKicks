import ActivityKit
import Foundation

struct KickActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var kickCount: Int
        var lastKickAt: Date?
    }

    let startedAt: Date
    let endsAt: Date
}
