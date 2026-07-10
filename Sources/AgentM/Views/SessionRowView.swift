import SwiftUI
import AppKit
import AgentMCore

struct SessionRowView: View {
    let session: AgentSession
    let lastPrompt: String?
    let lastActivity: Date?
    let branch: String?
    let model: String?
    let turnStart: Date?
    let bucket: StatusBucket
    /// 1…9 when this row has a number-key jump shortcut (Working, then Waiting-for-you); nil otherwise.
    var shortcutNumber: Int? = nil
    let onJump: () -> Void
    let onTranscript: () -> Void

    @State private var hovering = false
    @State private var pulse = false
    @State private var pillHover = false

    private var isWorking: Bool { bucket == .working }
    private var promptText: String {
        if session.kind == .background { return session.name ?? lastPrompt ?? "—" }
        return lastPrompt ?? "—"
    }

    var body: some View {
        Button(action: { NSApp.currentEvent?.modifierFlags.contains(.command) == true ? onTranscript() : onJump() }) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(Theme.dot(bucket: bucket, session: session))
                    .frame(width: 9, height: 9)
                    .opacity(isWorking && pulse ? 0.35 : 1)
                    .padding(.top, 5)
                    .onAppear {
                        guard isWorking else { return }
                        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
                    }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(session.folder).font(.system(size: 16, weight: .semibold))
                            .lineLimit(1).layoutPriority(1)
                        Spacer(minLength: 4)
                        if isWorking, let turnStart {
                            // How long the current turn has been running — ticks once a second.
                            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                                Label(turnElapsed(ctx.date.timeIntervalSince(turnStart)), systemImage: "timer")
                                    .labelStyle(.titleAndIcon)
                                    .font(.system(size: 13)).foregroundStyle(Theme.tint(.working)).monospacedDigit()
                            }
                        } else if let a = lastActivity {
                            Text(relativeTime(from: a, now: Date()))
                                .font(.system(size: 13)).foregroundStyle(.tertiary).monospacedDigit()
                        }
                    }
                    Text(promptText).font(.system(size: 15)).foregroundStyle(.secondary).lineLimit(2)
                    if let model {
                        Text(model).font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
                    }
                    Text(session.parentPath).font(.system(size: 12)).foregroundStyle(.tertiary)
                        .lineLimit(1).truncationMode(.middle)
                    if let branch { BranchPill(name: branch) }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(RadialGradient(
                        colors: [Color.orange.opacity(hovering ? 0.15 : 0), Color.orange.opacity(0)],
                        center: UnitPoint(x: -0.05, y: -0.1),   // light spills in from just off the top-left
                        startRadius: 0, endRadius: 380))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .animation(.easeOut(duration: 0.15), value: hovering)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerOnHover()
        .help("Click to jump to the terminal tab · ⌘-click (or the bubble) for the transcript")
        // Bottom-right affordances: the number-jump shortcut badge (display-only, clicks fall
        // through to the row's jump) and the transcript pill, overlaid so their clicks don't
        // fall through to the row underneath.
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 6) {
                if let shortcutNumber {
                    Text("\(shortcutNumber)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .frame(minWidth: 15)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                        .allowsHitTesting(false) // a click here still jumps (falls through to the row)
                }
                Button(action: onTranscript) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(pillHover ? 0.95 : 0.6))
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Color.white.opacity(pillHover ? 0.18 : 0.09),
                                    in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { pillHover = $0 }
                .pointerOnHover()
                .help("Open transcript")
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
        }
        .onHover { hovering = $0 }
    }
}

private extension View {
    /// Show the pointer (link) cursor while hovered — the web convention for "clickable".
    /// `.set()` on every continuous-hover tick reliably wins over the system's cursor resets.
    func pointerOnHover() -> some View {
        onContinuousHover { phase in
            if case .active = phase { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        }
    }
}
