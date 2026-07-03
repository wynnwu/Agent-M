import XCTest
@testable import AgentMCore

final class TerminalJumpTests: XCTestCase {
    // MARK: parseEnv — pull KEY=VALUE env pairs out of `ps eww` output

    func test_parseEnv_extracts_env_pairs() {
        let out = """
          PID   TT  STAT      TIME COMMAND
        14531 s009  S+     0:12.34 /x/claude PATH=/usr/bin TERM_PROGRAM=WarpTerminal WARP_FOCUS_URL=warp://session/abc123 __CFBundleIdentifier=dev.warp.Warp-Stable
        """
        let env = TerminalJump.parseEnv(fromPsOutput: out)
        XCTAssertEqual(env["TERM_PROGRAM"], "WarpTerminal")
        XCTAssertEqual(env["WARP_FOCUS_URL"], "warp://session/abc123")
        XCTAssertEqual(env["__CFBundleIdentifier"], "dev.warp.Warp-Stable")
    }

    func test_parseEnv_ignores_command_flags_and_paths() {
        // A `--model=x` flag or a path with `=` must not masquerade as an env var.
        let out = "1 s000 S 0:00 /bin/claude --model=opus /Users/x=y/foo TERM_PROGRAM=Apple_Terminal"
        let env = TerminalJump.parseEnv(fromPsOutput: out)
        XCTAssertEqual(env["TERM_PROGRAM"], "Apple_Terminal")
        XCTAssertNil(env["--model"])
    }

    // MARK: resolveJump — env + tty → what to do

    func test_resolveJump_warp_url_wins() {
        // Even if TERM_PROGRAM claims Apple_Terminal, a present focus URL means Warp.
        let t = TerminalJump.resolveJump(env: ["WARP_FOCUS_URL": "warp://session/xyz",
                                               "TERM_PROGRAM": "Apple_Terminal"], tty: "ttys009")
        XCTAssertEqual(t, .warp(url: "warp://session/xyz"))
    }

    func test_resolveJump_apple_terminal_by_tty() {
        let t = TerminalJump.resolveJump(env: ["TERM_PROGRAM": "Apple_Terminal"], tty: "ttys004")
        XCTAssertEqual(t, .appleTerminal(tty: "ttys004"))
    }

    func test_resolveJump_apple_terminal_without_tty_is_unsupported() {
        XCTAssertEqual(TerminalJump.resolveJump(env: ["TERM_PROGRAM": "Apple_Terminal"], tty: nil), .unsupported)
        XCTAssertEqual(TerminalJump.resolveJump(env: ["TERM_PROGRAM": "Apple_Terminal"], tty: ""), .unsupported)
    }

    func test_resolveJump_empty_warp_url_is_not_warp() {
        XCTAssertEqual(TerminalJump.resolveJump(env: ["WARP_FOCUS_URL": ""], tty: "ttys009"), .unsupported)
    }

    func test_resolveJump_unknown_terminal_is_unsupported() {
        XCTAssertEqual(TerminalJump.resolveJump(env: ["TERM_PROGRAM": "iTerm.app"], tty: "ttys009"), .unsupported)
    }

    // MARK: appleTerminalFocusScript — AppleScript that selects the tab by tty

    func test_appleTerminalFocusScript_targets_dev_tty() {
        let s = TerminalJump.appleTerminalFocusScript(tty: "ttys009")
        XCTAssertTrue(s.contains("/dev/ttys009"))
        XCTAssertTrue(s.contains("tell application \"Terminal\""))
        XCTAssertTrue(s.contains("set selected of t to true"))
    }

    func test_appleTerminalFocusScript_does_not_double_prefix() {
        let s = TerminalJump.appleTerminalFocusScript(tty: "/dev/ttys009")
        XCTAssertTrue(s.contains("/dev/ttys009"))
        XCTAssertFalse(s.contains("/dev//dev/"))
    }
}
