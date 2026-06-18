import SwiftUI
import UniformTypeIdentifiers

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var content: String

    init(events: [KickEvent]) {
        let formatter = ISO8601DateFormatter()
        let rows = events.sorted { $0.timestamp < $1.timestamp }.map {
            "\($0.id),\(formatter.string(from: $0.timestamp))"
        }
        content = (["id,timestamp"] + rows).joined(separator: "\n")
    }

    init(configuration: ReadConfiguration) throws {
        content = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(content.utf8))
    }
}
