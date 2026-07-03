import Foundation
import AgentMCore

/// Focuses the terminal tab hosting a session: reads the agent process's env + tty via `ps`
/// (same-user env is readable — see docs/DISCOVERY.md), decides the target, and focuses it.
/// Read-only navigation; never writes to `~/.claude/` or touches the agent. Blocking — call
/// off the main thread.
enum TerminalJumpIO {
    /// Resolve + focus the tab for `pid`. Returns true if a jump happened, false if the
    /// terminal is unsupported/unknown (caller should fall back to the in-app transcript).
    static func jump(pid: Int) -> Bool {
        let env = TerminalJump.parseEnv(fromPsOutput: run("/bin/ps", ["eww", "-p", "\(pid)"]))
        let tty = run("/bin/ps", ["-o", "tty=", "-p", "\(pid)"]).trimmingCharacters(in: .whitespacesAndNewlines)
        switch TerminalJump.resolveJump(env: env, tty: tty.isEmpty ? nil : tty) {
        case .warp(let url):
            run("/usr/bin/open", [url]); return true
        case .appleTerminal(let tty):
            run("/usr/bin/osascript", ["-e", TerminalJump.appleTerminalFocusScript(tty: tty)]); return true
        case .unsupported:
            return false
        }
    }

    /// Run a tool with an absolute path (PATH-independent, like `ClaudeCLI`) and return stdout.
    @discardableResult
    private static func run(_ path: String, _ args: [String]) -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = args
        let out = Pipe(); proc.standardOutput = out; proc.standardError = Pipe()
        proc.environment = ["HOME": NSHomeDirectory()]
        do { try proc.run() } catch { return "" }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
