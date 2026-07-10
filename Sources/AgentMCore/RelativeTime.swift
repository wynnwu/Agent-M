import Foundation

public func relativeTime(from date: Date, now: Date) -> String {
    let s = now.timeIntervalSince(date)
    if s < 60 { return "now" }
    if s < 3600 { return "\(Int(s / 60))m" }
    if s < 86400 { return "\(Int(s / 3600))h" }
    return "\(Int(s / 86400))d"
}

/// A running stopwatch: how long a turn is taking / took. `45s`, `1m 20s`, `1h 05m`.
public func turnElapsed(_ seconds: TimeInterval) -> String {
    let t = Int(max(0, seconds))
    if t < 60 { return "\(t)s" }
    if t < 3600 { return "\(t / 60)m \(String(format: "%02d", t % 60))s" }
    return "\(t / 3600)h \(String(format: "%02d", (t % 3600) / 60))m"
}

/// Clock-style elapsed for the "Refreshed … ago" indicator: `0:34`, `1:05`, `10:09`
/// (m:ss, zero-padded seconds, no unit letters). Negatives clamp to `0:00`.
public func minutesSeconds(_ seconds: TimeInterval) -> String {
    let t = Int(max(0, seconds))
    return "\(t / 60):\(String(format: "%02d", t % 60))"
}
