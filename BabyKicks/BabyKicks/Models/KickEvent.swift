import Foundation

struct KickEvent: Identifiable, Hashable, Sendable {
    let id: Int64
    let timestamp: Date
}

struct KickSession: Identifiable, Hashable {
    let id: Date
    let start: Date
    let end: Date
    let events: [KickEvent]

    var duration: TimeInterval { end.timeIntervalSince(start) }
}
