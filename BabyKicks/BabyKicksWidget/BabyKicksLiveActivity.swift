import ActivityKit
import SwiftUI
import WidgetKit

struct BabyKicksLiveActivity: Widget {
    private let berry = Color(red: 0.67, green: 0.25, blue: 0.43)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: KickActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "waveform.path")
                    .font(.title2.bold())
                    .foregroundStyle(berry)
                    .frame(width: 46, height: 46)
                    .background(berry.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Counting movements")
                        .font(.headline)
                    Text(
                        timerInterval: context.attributes.startedAt...context.attributes.endsAt,
                        countsDown: true
                    )
                        .font(.system(.title3, design: .monospaced, weight: .semibold))
                        .foregroundStyle(berry)
                }

                Spacer()

                VStack(spacing: 1) {
                    Text("\(context.state.kickCount)")
                        .font(.title.bold())
                    Text("moves")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .activityBackgroundTint(Color(red: 1, green: 0.96, blue: 0.95))
            .activitySystemActionForegroundColor(berry)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("\(context.state.kickCount) moves", systemImage: "waveform.path")
                        .font(.headline)
                        .foregroundStyle(berry)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(
                        timerInterval: context.attributes.startedAt...context.attributes.endsAt,
                        countsDown: true
                    )
                        .font(.system(.headline, design: .monospaced))
                        .monospacedDigit()
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Group {
                        if context.isStale {
                            Button(intent: EndSessionIntent()) {
                                Label("End completed session", systemImage: "xmark.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(.white)
                                    .background(berry, in: Capsule())
                            }
                        } else {
                            Button(intent: RecordKickIntent()) {
                                Label("Record movement", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(.white)
                                .background(berry, in: Capsule())
                            }
                        }
                    }
                    .padding(.top, 6)
                }
            } compactLeading: {
                Image(systemName: "waveform.path")
                    .foregroundStyle(berry)
            } compactTrailing: {
                Text(
                    timerInterval: context.attributes.startedAt...context.attributes.endsAt,
                    countsDown: true
                )
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .frame(width: 44)
            } minimal: {
                Image(systemName: "waveform.path")
                    .foregroundStyle(berry)
            }
            .keylineTint(berry)
        }
    }
}
