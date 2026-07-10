import SwiftUI
import AgentMCore

/// The dropdown's content: the live session list plus a footer.
/// Reads `service` and `prefs` (@Observable) so it updates as they change.
struct PopoverRootView: View {
    let service: AgentService
    let prefs: HotKeyPreferences
    let onJump: (AgentSession) -> Void
    let onTranscript: (AgentSession) -> Void
    let onSettings: () -> Void
    let onQuit: () -> Void

    private let width: CGFloat = 360 * 3 + 2

    var body: some View {
        VStack(spacing: 0) {
            SessionListView(
                groups: service.groups,
                lastPrompts: service.lastPrompts,
                lastActivity: service.lastActivity,
                gitBranches: service.gitBranches,
                models: service.models,
                turnStarts: service.turnStarts,
                errorMessage: service.errorMessage,
                jumpEnabled: prefs.jumpEnabled,
                onJump: onJump,
                onTranscript: onTranscript
            )
            Divider().opacity(0.4)
            HStack(spacing: 14) {
                // Left: settings, then refresh — the button, its shortcut hint, and how long ago.
                Button { onSettings() } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")

                HStack(spacing: 6) {
                    Button { Task { await service.refreshNow() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh")
                    if prefs.refreshEnabled {
                        Text(prefs.refreshDisplay).foregroundStyle(.tertiary)
                    }
                }
                if let last = service.lastRefreshed {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Text("Refreshed \(minutesSeconds(ctx.date.timeIntervalSince(last))) ago")
                            .foregroundStyle(.tertiary).monospacedDigit()
                    }
                }

                Spacer()

                if prefs.enabled {
                    Text("\(prefs.display) Open from anywhere.").foregroundStyle(.tertiary)
                }
                Button("Quit") { onQuit() }
            }
            .buttonStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .overlay(alignment: .center) {
                Text("Agent M")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: width)
        .environment(\.colorScheme, .dark)
        // Translucent: a touch of alpha for legibility; the NSVisualEffectView behind
        // provides the glass blur, and rounds the bottom corners.
        .background(Color.black.opacity(0.12))
        // Soft shadow along the top edge sells "emerging from behind the menu bar".
        .overlay(alignment: .top) {
            LinearGradient(colors: [.black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 12)
                .allowsHitTesting(false)
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 14,
                                          bottomTrailingRadius: 14, topTrailingRadius: 0))
    }
}
