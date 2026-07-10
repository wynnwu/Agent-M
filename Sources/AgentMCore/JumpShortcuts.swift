import Carbon.HIToolbox

/// Number-key shortcuts that jump to a session's terminal while the panel is open.
///
/// Numbering runs 1…9 over the Working column (top→bottom) then the Waiting-for-you
/// column (top→bottom). The pure helpers here map between shortcut numbers, the
/// physical digit-key codes, and the ordered list of target sessions — so the on-row
/// badge and the key handler always agree.

/// Virtual key codes for the top-row number keys, in order 1…9. The Carbon `kVK_ANSI_*`
/// codes are NOT sequential (5/6 and 7/8/9 are transposed), so we list them explicitly
/// rather than deriving one by arithmetic.
private let digitKeyCodes: [UInt32] = [
    UInt32(kVK_ANSI_1), UInt32(kVK_ANSI_2), UInt32(kVK_ANSI_3),
    UInt32(kVK_ANSI_4), UInt32(kVK_ANSI_5), UInt32(kVK_ANSI_6),
    UInt32(kVK_ANSI_7), UInt32(kVK_ANSI_8), UInt32(kVK_ANSI_9),
]

/// The virtual key code for shortcut number `n` (1…9), or nil if out of range.
public func digitKeyCode(_ n: Int) -> UInt32? {
    guard (1...9).contains(n) else { return nil }
    return digitKeyCodes[n - 1]
}

/// Inverse of `digitKeyCode`: the shortcut number (1…9) a virtual key code maps to, or nil.
public func shortcutNumber(forKeyCode k: UInt32) -> Int? {
    digitKeyCodes.firstIndex(of: k).map { $0 + 1 }
}

/// The agents reachable by number shortcut, in order — Working first, then Waiting-for-you,
/// capped at `limit`. Index `i` is shortcut number `i + 1`; both the badges and the key
/// handler derive their mapping from this single list.
public func numberedTargets(working: [AgentSession], waiting: [AgentSession], limit: Int = 9) -> [AgentSession] {
    Array((working + waiting).prefix(limit))
}
