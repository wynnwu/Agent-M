import XCTest
@testable import AgentMCore

/// `isAwaitingReply` must agree with the menu-bar panel: only "waiting for you" when the last
/// turn is a *completed* assistant turn — never while the agent is still mid-turn (working).
final class AwaitingReplyTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_780_000_000)

    private func user(_ text: String, at off: TimeInterval, toolResult: Bool = false) -> TranscriptRecord {
        TranscriptRecord(id: UUID().uuidString, role: .user, text: text, toolUses: [],
                         isToolResult: toolResult, isMeta: false, timestamp: t0.addingTimeInterval(off))
    }
    private func assistant(_ text: String, at off: TimeInterval, stop: String?, tools: [String] = []) -> TranscriptRecord {
        TranscriptRecord(id: UUID().uuidString, role: .assistant, text: text, toolUses: tools,
                         isToolResult: false, isMeta: false, timestamp: t0.addingTimeInterval(off),
                         model: "claude-opus-4-8", stopReason: stop)
    }

    func test_awaiting_when_last_assistant_turn_completed() {
        let recs = [user("do the thing", at: 0),
                    assistant("Done — anything else?", at: 10, stop: "end_turn")]
        XCTAssertTrue(TranscriptParser.isAwaitingReply(records: recs))
    }

    func test_not_awaiting_while_working_after_prompt() {
        // Prompt in, assistant emitted text but the turn hasn't ended → still working.
        let recs = [user("do the thing", at: 0),
                    assistant("On it…", at: 5, stop: nil)]
        XCTAssertFalse(TranscriptParser.isAwaitingReply(records: recs))
    }

    func test_not_awaiting_while_running_a_tool() {
        // stop_reason "tool_use" means the agent paused to run a tool — mid-turn, working.
        let recs = [user("do the thing", at: 0),
                    assistant("", at: 5, stop: "tool_use", tools: ["Bash"])]
        XCTAssertFalse(TranscriptParser.isAwaitingReply(records: recs))
    }

    func test_not_awaiting_when_user_spoke_last() {
        let recs = [assistant("Done.", at: 0, stop: "end_turn"),
                    user("another request", at: 10)]
        XCTAssertFalse(TranscriptParser.isAwaitingReply(records: recs))
    }

    func test_awaiting_after_toolcall_then_completion() {
        // A full turn spanning a tool call, then a completed reply → awaiting again.
        let recs = [user("do the thing", at: 0),
                    assistant("", at: 3, stop: "tool_use", tools: ["Bash"]),
                    assistant("All set.", at: 8, stop: "end_turn")]
        XCTAssertTrue(TranscriptParser.isAwaitingReply(records: recs))
    }
}
