import Foundation

/// Pure logic for "jump to the terminal tab running a session": decide, from the agent
/// process's environment + controlling tty, which terminal hosts it and how to focus the
/// exact tab. IO (running `ps`, opening the URL / AppleScript) lives in `TerminalJumpIO`.
///
/// Read-only navigation: nothing here mutates the agent or writes to `~/.claude/`.
public enum TerminalJump {
    public enum Target: Equatable, Sendable {
        case warp(url: String)        // `open` this warp://session/<uuid> focus URL
        case appleTerminal(tty: String)
        case unsupported              // caller falls back to the in-app transcript
    }

    /// Pull `KEY=VALUE` environment pairs out of `ps eww -p <pid>` output. Tolerant of the
    /// `PID TT STAT TIME COMMAND` header and the command line: only whitespace tokens whose
    /// key is a valid env identifier (starts with a letter/underscore) count, so `--model=x`
    /// flags and `path=like` args are ignored.
    public static func parseEnv(fromPsOutput output: String) -> [String: String] {
        var env: [String: String] = [:]
        for token in output.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }) {
            guard let eq = token.firstIndex(of: "=") else { continue }
            let key = token[..<eq]
            guard let first = key.first, first.isLetter || first == "_",
                  key.dropFirst().allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" })
            else { continue }
            env[String(key)] = String(token[token.index(after: eq)...])
        }
        return env
    }

    /// Decide how to focus the session's tab. Warp's focus URL wins when present (it's the
    /// most precise signal); otherwise Apple Terminal is focusable by tty; else unsupported.
    public static func resolveJump(env: [String: String], tty: String?) -> Target {
        if let url = env["WARP_FOCUS_URL"], !url.isEmpty { return .warp(url: url) }
        if env["TERM_PROGRAM"] == "Apple_Terminal", let tty, !tty.isEmpty {
            return .appleTerminal(tty: tty)
        }
        return .unsupported
    }

    /// AppleScript that finds the Terminal tab whose device matches `tty` and brings it to the
    /// front. `tty` may be bare (`ttys009`) or already `/dev/…`.
    public static func appleTerminalFocusScript(tty: String) -> String {
        let dev = tty.hasPrefix("/dev/") ? tty : "/dev/\(tty)"
        return """
        tell application "Terminal"
        \tactivate
        \trepeat with w in windows
        \t\trepeat with t in tabs of w
        \t\t\tif tty of t is "\(dev)" then
        \t\t\t\tset selected of t to true
        \t\t\t\tset frontmost of w to true
        \t\t\t\treturn
        \t\t\tend if
        \t\tend repeat
        \tend repeat
        end tell
        """
    }
}
