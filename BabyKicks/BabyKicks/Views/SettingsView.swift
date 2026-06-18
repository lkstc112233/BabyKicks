import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: KickStore
    @EnvironmentObject private var session: SessionManager
    @State private var isExporting = false
    @State private var isChoosingExportRange = false
    @State private var isChoosingCustomRange = false
    @State private var confirmDelete = false
    @State private var exportEvents: [KickEvent] = []
    @State private var exportName = "baby-kicks"
    @State private var customStart = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var customEnd = Date.now

    var body: some View {
        Form {
            Section {
                Button {
                    isChoosingExportRange = true
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                Text("CSV opens directly in Excel, Numbers, and Google Sheets.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Your data")
            } footer: {
                Text("The database stays on this device and is included in normal encrypted device backups. Baby Kicks does not use iCloud database sync.")
            }

            Section("Privacy") {
                LabeledContent("Storage", value: "On this device")
                LabeledContent("Cloud sync", value: "Off")
                LabeledContent("Recorded events", value: "\(store.events.count)")
            }

            Section {
                Button("Delete all data", role: .destructive) {
                    confirmDelete = true
                }
            }
        }
        .navigationTitle("Settings")
        .fileExporter(
            isPresented: $isExporting,
            document: CSVDocument(events: exportEvents),
            contentType: .commaSeparatedText,
            defaultFilename: exportName
        ) { _ in }
        .confirmationDialog(
            "Choose a time range",
            isPresented: $isChoosingExportRange,
            titleVisibility: .visible
        ) {
            Button("All time") {
                beginExport(events: store.events, label: "all-time")
            }
            Button("Last 7 days") {
                beginPresetExport(days: 7)
            }
            Button("Last 30 days") {
                beginPresetExport(days: 30)
            }
            Button("Custom range…") {
                isChoosingCustomRange = true
            }
        } message: {
            Text("Only movements inside the selected range will be included.")
        }
        .sheet(isPresented: $isChoosingCustomRange) {
            NavigationStack {
                Form {
                    DatePicker("From", selection: $customStart, displayedComponents: .date)
                    DatePicker("Through", selection: $customEnd, in: customStart..., displayedComponents: .date)
                    Section {
                        Text("\(customRangeEvents.count) recorded movements")
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Custom Export")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isChoosingCustomRange = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Export") {
                            let events = customRangeEvents
                            isChoosingCustomRange = false
                            beginExport(events: events, label: "custom")
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog(
            "Delete every recorded movement?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete all data", role: .destructive) {
                session.stop()
                store.deleteAll()
            }
        } message: {
            Text("This cannot be undone. Export a copy first if you may need it later.")
        }
    }

    private var customRangeEvents: [KickEvent] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: customStart)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEnd)) ?? customEnd
        return store.events.filter { $0.timestamp >= start && $0.timestamp < end }
    }

    private func beginPresetExport(days: Int) {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .distantPast
        beginExport(
            events: store.events.filter { $0.timestamp >= start },
            label: "last-\(days)-days"
        )
    }

    private func beginExport(events: [KickEvent], label: String) {
        exportEvents = events
        exportName = "baby-kicks-\(label)-\(Date.now.formatted(.iso8601.year().month().day()))"
        isExporting = true
    }
}
