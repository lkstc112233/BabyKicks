import SwiftUI

struct TrackView: View {
    @EnvironmentObject private var store: KickStore
    @EnvironmentObject private var session: SessionManager
    @State private var isPressed = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.cream, AppTheme.blush.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer()
                kickButton
                Spacer()
                sessionCard
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 18)
        }
        .navigationBarHidden(true)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Baby Kicks")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                Text("A tiny moment, safely remembered.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("\(store.todayCount)")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                Text("today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))
        }
        .padding(.top, 14)
    }

    private var kickButton: some View {
        Button {
            if store.recordKick() {
                session.registerKick()
            }
            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                isPressed = true
            }
            Task {
                try? await Task.sleep(for: .milliseconds(170))
                withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
                    isPressed = false
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(AppTheme.berry.opacity(0.13))
                    .frame(width: 270, height: 270)
                    .scaleEffect(isPressed ? 1.08 : 1)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.berry, AppTheme.berry.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 220, height: 220)
                    .shadow(color: AppTheme.berry.opacity(0.3), radius: 26, y: 16)
                    .scaleEffect(isPressed ? 0.94 : 1)
                VStack(spacing: 9) {
                    Image(systemName: "waveform.path")
                        .font(.system(size: 38, weight: .semibold))
                    Text("Felt a move")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                    Text("Tap to record")
                        .font(.subheadline.weight(.medium))
                        .opacity(0.78)
                }
                .foregroundStyle(.white)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Record a baby kick")
        .accessibilityHint("Adds the current time to your local kick history")
    }

    private var sessionCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: session.isActive ? "timer.circle.fill" : "timer")
                    .font(.title2)
                    .foregroundStyle(AppTheme.berry)
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.isActive ? "Counting session" : "Start a count")
                        .font(.headline)
                    Text(session.isActive ? "Live on your Lock Screen and Dynamic Island" : "Keep a two-hour timer close at hand")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle(
                    "",
                    isOn: Binding(
                        get: { session.isActive },
                        set: { $0 ? session.start() : session.stop() }
                    )
                )
                .labelsHidden()
            }

            if let endsAt = session.endsAt, session.isActive {
                HStack {
                    Text("Time remaining")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(
                        timerInterval: endsAt.addingTimeInterval(-SessionManager.duration)...endsAt,
                        countsDown: true
                    )
                        .font(.system(.body, design: .monospaced, weight: .semibold))
                        .foregroundStyle(AppTheme.berry)
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.85), lineWidth: 1)
        }
    }
}
