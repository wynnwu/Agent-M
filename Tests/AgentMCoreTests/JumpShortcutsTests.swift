import XCTest
import Carbon.HIToolbox
@testable import AgentMCore

final class JumpShortcutsTests: XCTestCase {
    private func s(_ id: String) -> AgentSession {
        AgentSession(sessionId: id, cwd: "/tmp/\(id)", kind: .interactive)
    }

    // MARK: digitKeyCode / shortcutNumber

    func test_digitKeyCode_maps_the_nonsequential_codes() {
        // Guard against a transposition bug: kVK_ANSI_5/6 and 7/8/9 are out of order.
        XCTAssertEqual(digitKeyCode(1), UInt32(kVK_ANSI_1))
        XCTAssertEqual(digitKeyCode(5), UInt32(kVK_ANSI_5))
        XCTAssertEqual(digitKeyCode(6), UInt32(kVK_ANSI_6))
        XCTAssertEqual(digitKeyCode(7), UInt32(kVK_ANSI_7))
        XCTAssertEqual(digitKeyCode(8), UInt32(kVK_ANSI_8))
        XCTAssertEqual(digitKeyCode(9), UInt32(kVK_ANSI_9))
    }

    func test_digitKeyCode_out_of_range_is_nil() {
        XCTAssertNil(digitKeyCode(0))
        XCTAssertNil(digitKeyCode(10))
        XCTAssertNil(digitKeyCode(-1))
    }

    func test_keyCode_roundtrips_through_shortcutNumber() {
        for n in 1...9 {
            XCTAssertEqual(shortcutNumber(forKeyCode: digitKeyCode(n)!), n)
        }
    }

    func test_shortcutNumber_for_non_digit_key_is_nil() {
        XCTAssertNil(shortcutNumber(forKeyCode: UInt32(kVK_ANSI_M)))
        XCTAssertNil(shortcutNumber(forKeyCode: UInt32(kVK_ANSI_0)))
    }

    // MARK: numberedTargets — Working first, then Waiting, capped at 9

    func test_numberedTargets_concatenates_working_then_waiting() {
        let targets = numberedTargets(working: [s("w1"), s("w2")], waiting: [s("q1"), s("q2")])
        XCTAssertEqual(targets.map(\.sessionId), ["w1", "w2", "q1", "q2"])
    }

    func test_numberedTargets_appends_idle_last() {
        let targets = numberedTargets(working: [s("w1")], waiting: [s("q1")], idle: [s("i1"), s("i2")])
        XCTAssertEqual(targets.map(\.sessionId), ["w1", "q1", "i1", "i2"])
    }

    func test_numberedTargets_caps_at_the_limit() {
        let working = (1...10).map { s("w\($0)") }
        let targets = numberedTargets(working: working, waiting: [s("q1")])
        XCTAssertEqual(targets.count, 9)
        XCTAssertEqual(targets.last?.sessionId, "w9") // waiting never reached
    }

    func test_numberedTargets_empty_is_empty() {
        XCTAssertTrue(numberedTargets(working: [], waiting: []).isEmpty)
    }
}
