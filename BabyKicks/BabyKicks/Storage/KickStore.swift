import Combine
import Foundation
import UIKit

@MainActor
final class KickStore: ObservableObject {
    @Published private(set) var events: [KickEvent] = []
    @Published private(set) var lastError: String?
    @Published private(set) var lastRecordedID: Int64?

    init() {
        reload()
    }

    var todayCount: Int {
        events.filter { Calendar.current.isDateInToday($0.timestamp) }.count
    }

    var latestEvent: KickEvent? { events.first }

    @discardableResult
    func recordKick() -> Bool {
        do {
            let event = try KickDatabase.shared.insert()
            events.insert(event, at: 0)
            lastRecordedID = event.id
            lastError = nil
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func reload() {
        do {
            events = try KickDatabase.shared.fetchAll()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteAll() {
        do {
            try KickDatabase.shared.deleteAll()
            events = []
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func inferredSessions(gap: TimeInterval = 2 * 60 * 60) -> [KickSession] {
        let chronological = events.sorted { $0.timestamp < $1.timestamp }
        guard let first = chronological.first else { return [] }

        var groups: [[KickEvent]] = [[first]]
        for event in chronological.dropFirst() {
            guard let previous = groups.last?.last else { continue }
            if event.timestamp.timeIntervalSince(previous.timestamp) >= gap {
                groups.append([event])
            } else {
                groups[groups.count - 1].append(event)
            }
        }

        return groups.reversed().compactMap { group in
            guard let start = group.first?.timestamp, let end = group.last?.timestamp else { return nil }
            return KickSession(id: start, start: start, end: end, events: group)
        }
    }
}
