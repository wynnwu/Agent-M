import SwiftUI
import AgentMCore

struct SessionListView: View {
    let groups: SessionGroups
    let lastPrompts: [String: String]
    let lastActivity: [String: Date]
    var gitBranches: [String: String] = [:]
    var models: [String: String] = [:]
    let errorMessage: String?
    let onOpen: (AgentSession) -> Void
    /// ScrollView doesn't render offscreen (ImageRenderer); snapshot mode renders flat.
    var scrollable: Bool = true

    private let columnWidth: CGFloat = 300
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
                column("Idle", groups.idle, .idle)
                Divider()
                column("Waiting for you", groups.waitingForYou, .waitingForYou)
                Divider()
                column("Working", groups.working, .working)
            }
            .frame(width: totalWidth)
        }
    }

    @ViewBuilder
    private func column(_ title: String, _ items: [AgentSession], _ bucket: StatusBucket) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(title.uppercased()).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.tint(bucket))
                Text("\(items.count)").font(.system(size: 13)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 5)

            if items.isEmpty {
                Text("Nothing here")
                    .font(.system(size: 15)).foregroundStyle(.quaternary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: listHeight)
            } else if scrollable {
                OverlayScrollView { rows(items, bucket) }
                    .frame(height: listHeight)
            } else {
                // Flat render (ImageRenderer): clip to the same viewport so snapshots match
                // the live, scrollable panel — natural rows, ~3.5 peeking through.
                rows(items, bucket)
                    .frame(height: listHeight, alignment: .top)
                    .clipped()
            }
        }
        .frame(width: columnWidth, alignment: .leading)
    }

    @ViewBuilder
    private func rows(_ items: [AgentSession], _ bucket: StatusBucket) -> some View {
        VStack(spacing: 0) {
            ForEach(items) { s in
                SessionRowView(session: s,
                               lastPrompt: lastPrompts[s.sessionId],
                               lastActivity: lastActivity[s.sessionId],
                               branch: gitBranches[s.sessionId],
                               model: models[s.sessionId],
                               bucket: bucket) { onOpen(s) }
            }
        }
    }
}
