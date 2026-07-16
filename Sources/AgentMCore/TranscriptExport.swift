import Foundation

/// Renders a whole session's turns to a Markdown document — a durable, readable log of
/// the prompting and conversation. Pure and deterministic (inject `now`/`timeZone`), so
/// it's fully unit-testable; all IO (reading the file, saving) lives in the app target.
public enum TranscriptExport {

    /// What to include, mirroring the detail window's filter.
    public enum Scope: String, Sendable {
        case all, prompts, responses
        func includes(_ role: TranscriptRecord.Role) -> Bool {
            switch self {
            case .all: return role == .user || role == .assistant
            case .prompts: return role == .user
            case .responses: return role == .assistant
            }
        }
        var noun: String {   // for the empty-state line
            switch self {
            case .all: return "turns"
            case .prompts: return "prompts"
            case .responses: return "responses"
            }
        }
    }

    /// Session identity shown in the document header.
    public struct Meta: Sendable {
        public let folder: String
        public let path: String
        public let sessionId: String
        public let model: String?     // raw model id, e.g. "claude-opus-4-8"
        public let branch: String?
        public let kind: String
        public init(folder: String, path: String, sessionId: String,
                    model: String?, branch: String?, kind: String) {
            self.folder = folder; self.path = path; self.sessionId = sessionId
            self.model = model; self.branch = branch; self.kind = kind
        }
    }

    /// Build the Markdown document.
    public static func markdown(records: [TranscriptRecord], scope: Scope, meta: Meta,
                                now: Date, timeZone: TimeZone = .current) -> String {
        let stamp = Self.formatter(timeZone)
        let turns = records.filter { scope.includes($0.role) }

        var out = ""
        out += "# \(meta.folder) — Claude Code session\n\n"
        out += "- **Path:** \(meta.path)\n"
        out += "- **Session:** \(meta.sessionId)\n"
        if let m = meta.model, !m.isEmpty { out += "- **Model:** \(prettyModelName(m))\n" }
        out += "- **Branch:** \(meta.branch ?? "—") · **Kind:** \(meta.kind)\n"
        out += "- **Exported:** \(stamp.string(from: now)) · **\(scopeLabel(scope)):** \(turns.count)\n"
        out += "\n---\n"

        if turns.isEmpty {
            out += "\n_(No \(scope.noun) in this session.)_\n"
            return out
        }

        for rec in turns {
            let who = rec.role == .user ? "You" : "Claude"
            var heading = "\n## \(who)"
            if let ts = rec.timestamp { heading += " · \(stamp.string(from: ts))" }
            out += heading + "\n"

            if rec.role == .user, let cmd = TranscriptParser.slashCommand(in: rec.text) {
                out += "**`\(cmd.name)`**" + (cmd.args.map { " \($0)" } ?? "") + "\n"
            } else {
                let body = rec.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !body.isEmpty { out += body + "\n" }
            }

            if rec.role == .assistant, !rec.toolUses.isEmpty {
                out += "\n_used: \(rec.toolUses.joined(separator: ", "))_\n"
            }
        }
        return out
    }

    private static func scopeLabel(_ scope: Scope) -> String {
        switch scope {
        case .all: return "Turns"
        case .prompts: return "Prompts"
        case .responses: return "Responses"
        }
    }

    private static func formatter(_ tz: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }
}

/// "claude-opus-4-8" → "Opus 4.8"; falls back to the raw id. Mirrors the view's `prettyModel`
/// but lives in Core so the exporter doesn't depend on the app target.
public func prettyModelName(_ raw: String) -> String {
    var s = raw
    if s.hasPrefix("claude-") { s = String(s.dropFirst("claude-".count)) }
    let parts = s.split(separator: "-")
    guard let family = parts.first, family.first?.isLetter == true else { return raw }
    let version = parts.dropFirst().prefix { $0.allSatisfy(\.isNumber) }.joined(separator: ".")
    let fam = family.prefix(1).uppercased() + family.dropFirst()
    return version.isEmpty ? fam : "\(fam) \(version)"
}
