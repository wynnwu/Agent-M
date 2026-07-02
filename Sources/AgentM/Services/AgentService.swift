import Foundation
import Observation
import AgentMCore

struct CachedInfo: Sendable {
    let size: UInt64
    let prompt: String?
    let branch: String?
    let asks: Bool
    let model: String?
}

@MainActor
@Observable
final class AgentService {
    private(set) var groups = SessionGroups(idle: [], waitingForYou: [], working: [], activeBadge: 0)
    private(set) var lastPrompts: [String: String] = [:]
    private(set) var lastActivity: [String: Date] = [:]
    private(set) var gitBranches: [String: String] = [:]
    private(set) var models: [String: String] = [:]
    /// sessionId → when the current status began (registry `statusUpdatedAt`). On a working
    /// row, `now − turnStart` is how long the current turn has been running.
    private(set) var turnStarts: [String: Date] = [:]
    var errorMessage: String?

    /// Set by the UI: poll fast while the user is looking at the popover.
    var popoverOpen = false

    private let cli = ClaudeCLI()
    private var task: Task<Void, Never>?
    /// Per-session extracted info, keyed so we only re-read a transcript when it grows.
    private var infoCache: [String: CachedInfo] = [:]

    private let minInterval: Double = 10
    private let maxInterval: Double = 30
    private var changedLastPoll = false
    private var lastSignature = ""
    private var isRefreshing = false

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            var interval = 10.0
            while !Task.isCancelled {
                guard let self else { return }
                await self.refreshNow()
                // Fast while active / changing / being watched; otherwise back off.
                let fast = self.popoverOpen || self.groups.activeBadge > 0 || self.changedLastPoll
                interval = nextPollInterval(current: interval, fast: fast,
                                            minInterval: self.minInterval, maxInterval: self.maxInterval)
                // Sleep in min-interval steps so opening the popover wakes us promptly.
                var slept = 0.0
                while slept < interval && !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(self.minInterval))
                    slept += self.minInterval
                    if self.popoverOpen && interval > self.minInterval { break }
                }
            }
        }
    }

    func stop() { task?.cancel(); task = nil }

    func refreshNow() async {
        if isRefreshing { return } // avoid overlapping fetches (loop + on-open)
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let sessions = try await cli.fetchSessions()
            errorMessage = nil
            // Off-main IO for mtimes + last prompts.
            let ids = sessions.map(\.sessionId)
            // sessionId → pid for live interactive sessions, used to consult the per-PID
            // registry for a finer status than `claude agents --json` reports.
            let interactivePIDs: [String: Int] = Dictionary(uniqueKeysWithValues:
                sessions.compactMap { s in
                    (s.kind == .interactive) ? s.pid.map { (s.sessionId, $0) } : nil
                })
            let cacheIn = self.infoCache
            let io = await Task.detached { () -> (act: [String: Date], prompts: [String: String], branches: [String: String], asks: [String: Bool], models: [String: String], registry: [String: String], turnStarts: [String: Date], cache: [String: CachedInfo]) in
                var act: [String: Date] = [:]
                var prompts: [String: String] = [:]
                var branches: [String: String] = [:]
                var asks: [String: Bool] = [:]
                var models: [String: String] = [:]
                var registry: [String: String] = [:]
                var turnStarts: [String: Date] = [:]
                var cache = cacheIn
                for (id, pid) in interactivePIDs {
                    guard let info = SessionRegistryIO.info(forPID: pid, expectedSessionID: id) else { continue }
                    registry[id] = info.status
                    if let ms = info.statusUpdatedAt { turnStarts[id] = Date(timeIntervalSince1970: ms / 1000) }
                }
                for id in ids {
                    guard let path = TranscriptIO.transcriptPath(forSessionID: id) else { continue }
                    if let m = TranscriptIO.lastModified(path) { act[id] = m }
                    let size = TranscriptIO.fileSize(path)
                    let info: CachedInfo
                    if let cached = cache[id], cached.size == size {
                        info = cached // unchanged file → reuse (avoids re-reading huge transcripts)
                    } else {
                        let e = TranscriptIO.tailInfo(atPath: path)
                        info = CachedInfo(size: size, prompt: e.prompt, branch: e.branch, asks: e.asksQuestion, model: e.model)
                        cache[id] = info
                    }
                    if let p = info.prompt { prompts[id] = p }
                    if let b = info.branch { branches[id] = b }
                    if let m = info.model { models[id] = m }
                    asks[id] = info.asks
                }
                cache = cache.filter { ids.contains($0.key) } // drop sessions that went away
                return (act, prompts, branches, asks, models, registry, turnStarts, cache)
            }.value
            self.infoCache = io.cache
            self.lastActivity = io.act
            self.lastPrompts = io.prompts
            self.gitBranches = io.branches
            self.models = io.models
            self.turnStarts = io.turnStarts
            self.groups = groupSessions(sessions, lastActivity: io.act, asksQuestion: io.asks,
                                        registryStatus: io.registry, now: Date())

            // Did membership / status / state change since last poll? (drives fast vs backoff)
            // Include the registry status so a `busy`→`shell` transition still counts as a change.
            let sig = sessions
                .map { "\($0.sessionId)|\($0.status?.rawValue ?? "-")|\($0.state?.rawValue ?? "-")|\(io.registry[$0.sessionId] ?? "-")" }
                .sorted().joined(separator: ";")
            self.changedLastPoll = (sig != self.lastSignature)
            self.lastSignature = sig
        } catch {
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            self.groups = SessionGroups(idle: [], waitingForYou: [], working: [], activeBadge: 0)
            self.changedLastPoll = false
        }
    }
}
