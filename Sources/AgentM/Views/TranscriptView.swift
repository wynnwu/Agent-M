import SwiftUI
import AppKit
import UniformTypeIdentifiers
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
    var exportScope: TranscriptExport.Scope {
        switch self {
        case .all: return .all
        case .prompts: return .prompts
        case .responses: return .responses
        }
    }
}

struct TranscriptView: View {
    let target: TranscriptTarget
    /// The live session source, so the window shows the SAME status as the menu-bar panel
    /// (working / waiting / idle) instead of re-deriving it from the transcript tail.
    let service: AgentService
    @State private var store: TranscriptStore
    @State private var exportConfirmation: ExportConfirmation?

    init(target: TranscriptTarget, service: AgentService) {
        self.target = target
        self.service = service
        _store = State(initialValue: TranscriptStore(sessionID: target.sessionId))
    }

    var body: some View {
        // Reading these @Observable properties makes the window refresh live on each poll.
        let status = service.statusBucket(forSessionID: target.sessionId)
        TranscriptWindowBody(target: target, records: store.records, notFound: store.notFound,
                             status: status, liveTurnStart: service.turnStarts[target.sessionId],
                             onExport: exportSession)
            .overlay(alignment: .bottom) {
                if let c = exportConfirmation { ExportToast(confirmation: c) }
            }
            .onAppear { store.load(); store.startWatching() }
            .onDisappear { store.stopWatching() }
    }

    /// Build a Markdown log of the WHOLE session for the chosen scope, offer to save it, and
    /// confirm with a transient toast when it lands.
    private func exportSession(_ filter: TranscriptFilter) {
        let records = store.fullRecords()
        let meta = TranscriptExport.Meta(
            folder: target.folder, path: "\(target.parent)/\(target.folder)", sessionId: target.sessionId,
            model: records.last(where: { $0.role == .assistant })?.model,
            branch: target.branch, kind: target.kind)
        let md = TranscriptExport.markdown(records: records, scope: filter.exportScope,
                                           meta: meta, now: Date())
        guard let url = TranscriptExporter.save(markdown: md, folder: target.folder,
                                                scope: filter.exportScope) else { return }
        let token = UUID()
        withAnimation(.spring(duration: 0.3)) {
            exportConfirmation = ExportConfirmation(id: token, url: url, count: records.filter { filter.includes($0.role) }.count)
        }
        // Auto-dismiss ~3.5s later, unless a newer export replaced it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            if exportConfirmation?.id == token { withAnimation(.easeOut) { exportConfirmation = nil } }
        }
    }
}

/// A successful export, surfaced as a toast.
struct ExportConfirmation: Equatable {
    let id: UUID
    let url: URL
    let count: Int
}

/// A transient "exported" confirmation pinned to the bottom of the window. Click to reveal in Finder.
struct ExportToast: View {
    let confirmation: ExportConfirmation
    @State private var hovering = false

    var body: some View {
        Button {
            NSWorkspace.shared.activateFileViewerSelecting([confirmation.url])
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.working)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Exported \(confirmation.count) turn\(confirmation.count == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .semibold))
                    Text(confirmation.url.lastPathComponent)
                        .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                }
                Image(systemName: "arrow.up.forward.app").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(hovering ? 0.18 : 0.08)))
            .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .help("Reveal in Finder")
        .onHover { hovering = $0; if $0 { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() } }
        .padding(.bottom, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// The themed window chrome (geeky header, filter, waiting banner, turns).
/// Reusable so it can be rendered for verification with `scrollable: false`.
struct TranscriptWindowBody: View {
    let target: TranscriptTarget
    let records: [TranscriptRecord]
    var notFound: Bool = false
    var scrollable: Bool = true
    /// The authoritative live status from the menu-bar panel (working / waiting / idle). When
    /// nil (snapshots/previews, which have no live service) the banner falls back to a
    /// transcript-derived guess so those still render.
    var status: StatusBucket? = nil
    /// When the current turn started (registry `statusUpdatedAt`) — the panel's timer source.
    var liveTurnStart: Date? = nil
    /// Export the whole session for the given scope. No-op default so snapshots/previews
    /// (which have no store) can render without wiring one up.
    var onExport: (TranscriptFilter) -> Void = { _ in }

    @State private var filter: TranscriptFilter = .all

    /// Is the agent actively working? Authoritative when `status` is present.
    private var isWorking: Bool { status == .working }
    /// Is the conversation handed back to you? Authoritative status wins; else guess from the tail.
    private var waitingForYou: Bool {
        if let status { return status == .waitingForYou }
        return TranscriptParser.isAwaitingReply(records: records)
    }
    private var visibleRecords: [TranscriptRecord] { records.filter { filter.includes($0.role) } }
    /// Noun for the empty state, e.g. "No prompts in the last few turns."
    private var emptyNoun: String { filter == .all ? "turns" : filter.label.lowercased() }

    /// Tooltip for the "Export all" button — makes clear it saves the WHOLE session for the
    /// selected tab, not just the turns currently shown.
    private var exportHelp: String {
        switch filter {
        case .all:       return "Export the whole session as Markdown — every prompt and response, not just the turns shown"
        case .prompts:   return "Export all prompts from the whole session as Markdown — not just the turns shown"
        case .responses: return "Export all responses from the whole session as Markdown — not just the turns shown"
        }
    }

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

    /// Working agents get green (interactive) / blue (background), matching the panel's dot.
    private var workingTint: Color { target.kind == "background" ? Theme.running : Theme.working }

    /// When not working, how long the last completed turn took. (The live "current turn" timer
    /// lives in the Working banner, so it isn't duplicated here.)
    @ViewBuilder private var turnTiming: some View {
        if !isWorking, let d = lastTurnDuration {
            Label("last turn " + turnElapsed(d), systemImage: "timer")
                .font(.system(size: 13)).foregroundStyle(.tertiary).monospacedDigit()
        }
    }

    /// A status strip that mirrors the menu-bar panel: Working (with a live timer) or
    /// Waiting for your reply. Idle shows nothing.
    @ViewBuilder private var statusBanner: some View {
        if isWorking {
            HStack(spacing: 6) {
                Image(systemName: "circle.fill").font(.system(size: 7))
                Text("Working")
                if let start = liveTurnStart ?? currentTurnStart {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Text(turnElapsed(ctx.date.timeIntervalSince(start)))
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(workingTint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(workingTint.opacity(0.12))
        } else if waitingForYou {
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
                HStack(spacing: 8) {
                    HStack(spacing: 0) {
                        ForEach(TranscriptFilter.allCases) { f in
                            Button { filter = f } label: {
                                Text(f.label)
                                    .font(.system(size: 14, weight: .medium))
                                    .padding(.horizontal, 14).padding(.vertical, 4)
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

                    Spacer(minLength: 8)

                    ExportButton(disabled: notFound, help: exportHelp) { onExport(filter) }
                }
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)

            if !notFound { statusBanner }
            Divider().opacity(0.5)

            if notFound {
                ContentUnavailableView("No transcript yet",
                                       systemImage: "doc.text.magnifyingglass",
                                       description: Text("This session hasn't written a transcript file yet."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if visibleRecords.isEmpty {
                ContentUnavailableView("Nothing to Show",
                                       systemImage: "line.3.horizontal.decrease.circle",
                                       description: Text("No \(emptyNoun) in the last few turns.\nExport will show entire history."))
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

/// The toolbar affordance that exports the whole session for the current filter. Reads as a
/// button (hover highlight + pointing-hand cursor) and matches the header's understated style.
struct ExportButton: View {
    let disabled: Bool
    /// Scope-aware tooltip spelling out that it saves the WHOLE session, not the visible turns.
    var help: String = "Export the whole session as Markdown"
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 12))
                Text("Export all").font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(disabled ? Color.secondary.opacity(0.5) : Color.secondary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(hovering && !disabled ? Color.white.opacity(0.12) : Color.black.opacity(0.25),
                        in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(help)
        .onHover { inside in
            hovering = inside
            if inside && !disabled { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        }
    }
}

/// Saves an exported Markdown document via a native Save panel. Kept out of the SwiftUI view so
/// the AppKit save flow (and the `.accessory` activation dance) is in one place.
enum TranscriptExporter {
    /// Present the Save panel and write the file. Returns the saved URL (nil if the user
    /// cancelled or the write failed) so the caller can show a confirmation.
    @MainActor
    static func save(markdown: String, folder: String, scope: TranscriptExport.Scope) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultFilename(folder: folder, scope: scope)
        panel.allowedContentTypes = [.init(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        panel.title = "Export Session"
        // Default to ~/Downloads.
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        // The app is an accessory (no Dock icon); bring it forward so the panel isn't lost behind others.
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do { try markdown.data(using: .utf8)?.write(to: url); return url }
        catch { return nil }
    }

    /// `acme-web-2026-07-17.md`, with a `-prompts` / `-responses` suffix for those scopes.
    static func defaultFilename(folder: String, scope: TranscriptExport.Scope,
                                today: Date = Date(), calendar: Calendar = .current) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.dateFormat = "yyyy-MM-dd"
        let base = folder.isEmpty ? "session" : folder
        let suffix = scope == .all ? "" : "-\(scope.rawValue)"
        return "\(base)\(suffix)-\(df.string(from: today)).md"
    }
}

/// "claude-opus-4-8" → "Opus 4.8". Falls back to the raw id for anything unusual.
/// Thin alias over `AgentMCore.prettyModelName` so the header and the exporter agree.
func prettyModel(_ raw: String) -> String { prettyModelName(raw) }
