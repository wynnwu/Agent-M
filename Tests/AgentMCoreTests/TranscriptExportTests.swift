import XCTest
@testable import AgentMCore

final class TranscriptExportTests: XCTestCase {

    // Fixed instant so timestamps render deterministically (UTC pinned below).
    private let t0 = Date(timeIntervalSince1970: 1_780_000_000)          // 2026-05-28 09:06:40 UTC
    private let exportedAt = Date(timeIntervalSince1970: 1_780_000_500)
    private let utc = TimeZone(identifier: "UTC")!

    private func rec(_ role: TranscriptRecord.Role, _ text: String, tools: [String] = [],
                     at offset: TimeInterval = 0) -> TranscriptRecord {
        TranscriptRecord(id: UUID().uuidString, role: role, text: text, toolUses: tools,
                         isToolResult: false, isMeta: false, timestamp: t0.addingTimeInterval(offset))
    }

    private func meta() -> TranscriptExport.Meta {
        .init(folder: "acme-web", path: "/Users/dev/Code/acme", sessionId: "a1b2c3d4e5f60718",
              model: "claude-opus-4-8", branch: "main", kind: "interactive")
    }

    private var sample: [TranscriptRecord] {
        [
            rec(.user, "<command-name>/goal</command-name>\n<command-args>ship the export</command-args>", at: 0),
            rec(.user, "Refactor the checkout flow.", at: 62),
            rec(.assistant, "On it — swapping the gateway.", tools: ["Bash", "Edit"], at: 100),
        ]
    }

    // MARK: - slash command parsing

    func test_slashCommand_extracts_name_and_args() {
        let cmd = TranscriptParser.slashCommand(in: "<command-name>/goal</command-name>\n<command-args>ship it</command-args>")
        XCTAssertEqual(cmd, .init(name: "/goal", args: "ship it"))
    }

    func test_slashCommand_nil_args_when_empty() {
        let cmd = TranscriptParser.slashCommand(in: "<command-message>model</command-message>\n<command-name>/model</command-name>\n<command-args></command-args>")
        XCTAssertEqual(cmd, .init(name: "/model", args: nil))
    }

    func test_slashCommand_nil_for_plain_prose() {
        XCTAssertNil(TranscriptParser.slashCommand(in: "Just a normal message with <angle> brackets."))
    }

    // MARK: - header

    func test_header_has_identity_and_pretty_model() {
        let md = TranscriptExport.markdown(records: sample, scope: .all, meta: meta(), now: exportedAt, timeZone: utc)
        XCTAssertTrue(md.hasPrefix("# acme-web — Claude Code session"))
        XCTAssertTrue(md.contains("- **Session:** a1b2c3d4e5f60718"))
        XCTAssertTrue(md.contains("- **Model:** Opus 4.8"))
        XCTAssertTrue(md.contains("- **Branch:** main · **Kind:** interactive"))
        XCTAssertTrue(md.contains("**Exported:** 2026-05-28 20:35:00"))   // t0+500s, UTC
    }

    // MARK: - scopes

    func test_all_scope_includes_both_and_slash_command_and_tools() {
        let md = TranscriptExport.markdown(records: sample, scope: .all, meta: meta(), now: exportedAt, timeZone: utc)
        XCTAssertTrue(md.contains("**Turns:** 3"))
        XCTAssertTrue(md.contains("## You · 2026-05-28 20:26:40"))
        XCTAssertTrue(md.contains("**`/goal`** ship the export"))         // slash command rendered
        XCTAssertTrue(md.contains("Refactor the checkout flow."))
        XCTAssertTrue(md.contains("## Claude · 2026-05-28 20:28:20"))
        XCTAssertTrue(md.contains("_used: Bash, Edit_"))
    }

    func test_prompts_scope_excludes_assistant() {
        let md = TranscriptExport.markdown(records: sample, scope: .prompts, meta: meta(), now: exportedAt, timeZone: utc)
        XCTAssertTrue(md.contains("**Prompts:** 2"))
        XCTAssertTrue(md.contains("## You"))
        XCTAssertFalse(md.contains("## Claude"))
        XCTAssertFalse(md.contains("_used:"))
    }

    func test_responses_scope_excludes_user() {
        let md = TranscriptExport.markdown(records: sample, scope: .responses, meta: meta(), now: exportedAt, timeZone: utc)
        XCTAssertTrue(md.contains("**Responses:** 1"))
        XCTAssertTrue(md.contains("## Claude"))
        XCTAssertFalse(md.contains("## You"))
        XCTAssertFalse(md.contains("/goal"))
    }

    func test_empty_scope_notes_absence() {
        let onlyPrompts = [rec(.user, "hi", at: 0)]
        let md = TranscriptExport.markdown(records: onlyPrompts, scope: .responses, meta: meta(), now: exportedAt, timeZone: utc)
        XCTAssertTrue(md.contains("**Responses:** 0"))
        XCTAssertTrue(md.contains("_(No responses in this session.)_"))
    }

    func test_turn_without_timestamp_omits_time() {
        let noTS = [TranscriptRecord(id: "x", role: .user, text: "hi", toolUses: [],
                                     isToolResult: false, isMeta: false, timestamp: nil)]
        let md = TranscriptExport.markdown(records: noTS, scope: .all, meta: meta(), now: exportedAt, timeZone: utc)
        XCTAssertTrue(md.contains("## You\n"))     // no " · <time>" suffix
        XCTAssertFalse(md.contains("## You ·"))
    }
}
