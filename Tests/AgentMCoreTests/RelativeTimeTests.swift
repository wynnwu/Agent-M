import XCTest
@testable import AgentMCore

final class RelativeTimeTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_780_000_000)
    func t(_ secondsAgo: TimeInterval) -> String { relativeTime(from: now.addingTimeInterval(-secondsAgo), now: now) }
    func test_now_under_60s()    { XCTAssertEqual(t(30), "now") }
    func test_minutes()          { XCTAssertEqual(t(38*60), "38m") }
    func test_hours()            { XCTAssertEqual(t(3*3600), "3h") }
    func test_days()             { XCTAssertEqual(t(8*86400), "8d") }
    func test_future_clamps_now(){ XCTAssertEqual(relativeTime(from: now.addingTimeInterval(120), now: now), "now") }

    // turnElapsed: a running stopwatch for how long a turn is taking / took.
    func test_turnElapsed_seconds()          { XCTAssertEqual(turnElapsed(45), "45s") }
    func test_turnElapsed_small()            { XCTAssertEqual(turnElapsed(5), "5s") }
    func test_turnElapsed_zero_and_negative(){ XCTAssertEqual(turnElapsed(0), "0s"); XCTAssertEqual(turnElapsed(-5), "0s") }
    func test_turnElapsed_minutes_seconds()  { XCTAssertEqual(turnElapsed(80), "1m 20s"); XCTAssertEqual(turnElapsed(65), "1m 05s") }
    func test_turnElapsed_minute_boundary()  { XCTAssertEqual(turnElapsed(120), "2m 00s") }
    func test_turnElapsed_hours_minutes()    { XCTAssertEqual(turnElapsed(3660), "1h 01m"); XCTAssertEqual(turnElapsed(7200), "2h 00m") }

    // minutesSeconds: m:ss clock for the "Refreshed … ago" indicator.
    func test_minutesSeconds_zero_and_negative(){ XCTAssertEqual(minutesSeconds(0), "0:00"); XCTAssertEqual(minutesSeconds(-5), "0:00") }
    func test_minutesSeconds_seconds()          { XCTAssertEqual(minutesSeconds(34), "0:34") }
    func test_minutesSeconds_minute()           { XCTAssertEqual(minutesSeconds(65), "1:05") }
    func test_minutesSeconds_ten_minutes()      { XCTAssertEqual(minutesSeconds(609), "10:09") }
}
