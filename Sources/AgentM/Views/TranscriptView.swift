import SwiftUI
import AppKit
import AgentMCore

/// What a transcript window needs to know, captured when it's opened.
struct TranscriptTarget: Codable, Hashable {
    let sessionId: String
    let folder: String
    let parent: String
    let branch: String?
    var kind: String = "interactive"
    var pid: Int? = nil
    var startedAt: Double? = nil   // epoch milliseconds
}

enum TranscriptFilter: String, CaseIterable, Identifiable {
    case all, prompts, responses
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "All"
        case .prompts: return "Prompts"
        case .responses: return "Responses"
        }
    }
    func includes(_ role: TranscriptRecord.Role) -> Bool {
        switch self {
        case .all: return true
        case .prompts: return role == .user
        case .responses: return role == .assistant
        }
    }
}

struct TranscriptView: View {
    let target: TranscriptTarget
    @State private var store: TranscriptStore

    init(target: TranscriptTarget) {
        self.target = target
        _store = State(initialValue: TranscriptStore(sessionID: target.sessionId))
    }

    var body: some View {
        TranscriptWindowBody(target: target, records: store.records, notFound: store.notFound)
            .onAppear { store.load(); store.startWatching() }
            .onDisappear { store.stopWatching() }
    }
}

/// The themed window chrome (geeky header, filter, waiting banner, turns).
/// Reusable so it can be rendered for verification with `scrollable: false`.
struct TranscriptWindowBody: View {
    let target: TranscriptTarget
    let records: [TranscriptRecord]
    var notFound: Bool = false
    var scrollable: Bool = true

    @State private var filter: TranscriptFilter = .all

    private var waitingForYou: Bool { records.last?.role == .assistant }
    private var visibleRecords: [TranscriptRecord] { records.filter { filter.includes($0.role) } }

    /// The static (non-copyable) meta pieces, in order: model · kind · up-time.
    /// The pid and id are rendered separately as interactive copy tokens.
    private var staticMetaParts: [String] {
        var parts: [String] = []
        if let m = records.last(where: { $0.role == .assistant })?.model { parts.append(prettyModel(m)) }
        parts.append(target.kind)
        if let s = target.startedAt { parts.append("up " + relativeTime(from: Date(timeIntervalSince1970: s / 1000), now: Date())) }
        return parts
    }

    /// Two rows: the geek data (model · kind · up-time) on top, then the click-to-copy
    /// pid / id tokens below — kept on their own line so the copy chips can't crowd out
    /// or truncate the info above them (pid → raw pid, id → the *full* session id).
    @ViewBuilder private var metaLine: some View {
        let sep = Text("  ·  ").foregroundStyle(.tertiary)
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 0) {
                ForEach(Array(staticMetaParts.enumerated()), id: \.offset) { i, part in
                    if i > 0 { sep }
                    Text(part).textSelection(.enabled)
                }
            }
            .lineLimit(1)
            HStack(spacing: 0) {
                if let pid = target.pid {
                    CopyToken(label: "pid \(pid)", value: "\(pid)")
                    sep
                }
                CopyToken(label: "id \(target.sessionId.prefix(8))", value: target.sessionId)
            }
            .padding(.leading, -5)   // cancel the chip's inner padding so pid aligns with the row above
        }
        .font(.system(size: 14))
        .foregroundStyle(.tertiary)
    }

    private var currentTurnStart: Date? { TranscriptParser.currentTurnStart(records: records) }
    private var lastTurnDuration: TimeInterval? { TranscriptParser.lastCompletedTurnDuration(records: records) }

    /// How long the current turn is taking (live) or how long the last one took.
    @ViewBuilder private var turnTiming: some View {
        if let start = currentTurnStart {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                Label("current turn " + turnElapsed(ctx.date.timeIntervalSince(start)), systemImage: "timer")
                    .font(.system(size: 13)).foregroundStyle(Theme.tint(.working)).monospacedDigit()
            }
        } else if let d = lastTurnDuration {
            Label("last turn " + turnElapsed(d), systemImage: "timer")
                .font(.system(size: 13)).foregroundStyle(.tertiary).monospacedDigit()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(target.folder).font(.system(size: 18, weight: .semibold))
                        Text(target.parent).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
                        metaLine
                        turnTiming
                    }
                    Spacer(minLength: 8)
                    if let b = target.branch { BranchPill(name: b) }
                }
                HStack(spacing: 0) {
                    ForEach(TranscriptFilter.allCases) { f in
                        Button { filter = f } label: {
                            Text(f.label)
                                .font(.system(size: 14, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                                .foregroundStyle(filter == f ? Color.primary : Color.secondary)
                                .background(filter == f ? Color.white.opacity(0.14) : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 6))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)

            if waitingForYou && !notFound {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.down.left")
                    Text("Waiting for your reply")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.yourTurn)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Theme.yourTurn.opacity(0.12))
            }
            Divider().opacity(0.5)

            if notFound {
                ContentUnavailableView("No transcript yet",
                                       systemImage: "doc.text.magnifyingglass",
                                       description: Text("This session hasn't written a transcript file yet."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if visibleRecords.isEmpty {
                ContentUnavailableView("Nothing to show",
                                       systemImage: "line.3.horizontal.decrease.circle",
                                       description: Text("No \(filter.label.lowercased()) in the last turns."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TranscriptContent(records: visibleRecords, scrollable: scrollable)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 580)
        .background(Color(red: 0.12, green: 0.12, blue: 0.13))
        .environment(\.colorScheme, .dark)
        .navigationTitle(target.folder)
    }
}

struct TranscriptContent: View {
    let records: [TranscriptRecord]
    var scrollable: Bool = true

    var body: some View {
        if scrollable {
            ScrollView { turns.padding(14) }
                .defaultScrollAnchor(.bottom)   // open showing the latest turn at the bottom
        } else {
            turns.padding(14)
        }
    }

    @ViewBuilder
    private var turns: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(records) { rec in
                let isUser = rec.role == .user
                VStack(alignment: .leading, spacing: 4) {
                    Text(isUser ? "You" : "Claude")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isUser ? Theme.yourTurn : Color.secondary)
                    if !rec.text.isEmpty {
                        Text(rec.text).font(.system(size: 15)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(rec.toolUses, id: \.self) { tool in
                        Label(tool, systemImage: "wrench.and.screwdriver")
                            .font(.system(size: 13)).foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(isUser ? Theme.yourTurn.opacity(0.10) : Color.white.opacity(0.045),
                            in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

/// A click-to-copy chip: shows `label` + the standard macOS copy glyph, copies
/// `value` to the pasteboard on click, and briefly flashes a checkmark to confirm.
/// Hovering highlights it and switches the cursor to a pointing hand so it reads
/// as clickable.
struct CopyToken: View {
    let label: String
    let value: String

    @State private var hovering = false
    @State private var justCopied = false

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
            Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 11))
                .foregroundStyle(justCopied ? Theme.working : Color.secondary)
        }
        .padding(.horizontal, 5).padding(.vertical, 1)
        .background(hovering ? Color.white.opacity(0.08) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 5))
        .contentShape(RoundedRectangle(cornerRadius: 5))
        .fixedSize()                 // never truncate the pid/id — the whole point is to copy them
        .onHover { inside in
            hovering = inside
            if inside { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        }
        .onTapGesture { copy() }
        .help("Copy \(value)")
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        justCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { justCopied = false }
    }
}

/// "claude-opus-4-8" → "Opus 4.8". Falls back to the raw id for anything unusual.
func prettyModel(_ raw: String) -> String {
    var s = raw
    if s.hasPrefix("claude-") { s = String(s.dropFirst("claude-".count)) }
    let parts = s.split(separator: "-")
    guard let family = parts.first, family.first?.isLetter == true else { return raw }
    let version = parts.dropFirst().prefix { $0.allSatisfy(\.isNumber) }.joined(separator: ".")
    let fam = family.prefix(1).uppercased() + family.dropFirst()
    return version.isEmpty ? fam : "\(fam) \(version)"
}
