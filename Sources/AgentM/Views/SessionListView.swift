import SwiftUI
import AgentMCore

struct SessionListView: View {
    let groups: SessionGroups
    let lastPrompts: [String: String]
    let lastActivity: [String: Date]
    var gitBranches: [String: String] = [:]
    var models: [String: String] = [:]
    var turnStarts: [String: Date] = [:]
    let errorMessage: String?
    /// Whether the number-key jump shortcuts (and their row badges) are active.
    var jumpEnabled: Bool = true
    let onJump: (AgentSession) -> Void
    var onTranscript: (AgentSession) -> Void = { _ in }
    /// ScrollView doesn't render offscreen (ImageRenderer); snapshot mode renders flat.
    var scrollable: Bool = true

    private let columnWidth: CGFloat = 360
    /// Viewport height: about 3.5 natural-height rows peek through before scrolling.
    private let listHeight: CGFloat = 460
    private var totalWidth: CGFloat { columnWidth * 3 + 2 }

    var body: some View {
        if let err = errorMessage {
            let parts = err.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text(parts.first.map(String.init) ?? err)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
                .font(.callout)
                if parts.count > 1 {
                    Text(String(parts[1])).font(.caption.monospaced()).foregroundStyle(.tertiary).textSelection(.enabled)
                }
            }
            .frame(width: totalWidth, alignment: .leading)
            .padding(14)
        } else {
            HStack(alignment: .top, spacing: 0) {
                // Numbering runs 1…9 over Working (top→bottom) then Waiting-for-you; Idle is unnumbered.
                column("Idle", groups.idle, .idle, numberOffset: nil)
                Divider()
                column("Waiting for you", groups.waitingForYou, .waitingForYou, numberOffset: groups.working.count)
                Divider()
                column("Working", groups.working, .working, numberOffset: 0)
            }
            .frame(width: totalWidth)
        }
    }

    @ViewBuilder
    private func column(_ title: String, _ items: [AgentSession], _ bucket: StatusBucket, numberOffset: Int?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(title.uppercased()).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.tint(bucket))
                Text("\(items.count)").font(.system(size: 14)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 5)

            if items.isEmpty {
                Text("Nothing here")
                    .font(.system(size: 15)).foregroundStyle(.quaternary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: listHeight)
            } else if scrollable {
                // Native SwiftUI ScrollView: multiple sibling NSScrollViews (the old custom
                // OverlayScrollView) only delivered hover to the first column — SwiftUI's own
                // scroll view handles hover per-row with no such routing bug.
                ScrollView(.vertical) { rows(items, bucket, numberOffset: numberOffset) }
                    .frame(height: listHeight)
            } else {
                // Flat render (ImageRenderer): clip to the same viewport so snapshots match
                // the live, scrollable panel — natural rows, ~3.5 peeking through.
                rows(items, bucket, numberOffset: numberOffset)
                    .frame(height: listHeight, alignment: .top)
                    .clipped()
            }
        }
        .frame(width: columnWidth, alignment: .leading)
    }

    @ViewBuilder
    private func rows(_ items: [AgentSession], _ bucket: StatusBucket, numberOffset: Int?) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, s in
                SessionRowView(session: s,
                               lastPrompt: lastPrompts[s.sessionId],
                               lastActivity: lastActivity[s.sessionId],
                               branch: gitBranches[s.sessionId],
                               model: models[s.sessionId],
                               turnStart: turnStarts[s.sessionId],
                               bucket: bucket,
                               shortcutNumber: shortcutNumber(offset: numberOffset, index: index),
                               onJump: { onJump(s) },
                               onTranscript: { onTranscript(s) })
            }
        }
    }

    /// The 1…9 badge for a row, or nil when the column is unnumbered (Idle) or the running
    /// count has passed 9.
    private func shortcutNumber(offset: Int?, index: Int) -> Int? {
        guard jumpEnabled, let offset else { return nil }
        let n = offset + index + 1
        return n <= 9 ? n : nil
    }
}
