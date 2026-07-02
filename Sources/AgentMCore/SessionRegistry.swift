import Foundation

/// Parse a per-PID session registry file (`~/.claude/sessions/<pid>.json`) for its
/// fine-grained status.
///
/// `claude agents --json` collapses an interactive session's state into `idle`/`busy`,
/// reporting transient states like `shell` as `busy`. The registry keeps the finer truth
/// (e.g. `idle`, `busy`, `shell`), so we prefer it when classifying.
///
/// Guards against PID reuse: returns the status only if the file's recorded `sessionId`
/// matches the session we're asking about. Returns the raw status string (kept as a string
/// on purpose — the vocabulary is undocumented and may drift) or `nil` if the file is
/// malformed, mismatched, or missing the field.
public func registryStatus(fromJSON data: Data, expectedSessionID: String) -> String? {
    registryInfo(fromJSON: data, expectedSessionID: expectedSessionID)?.status
}

/// A registry file's status plus `statusUpdatedAt` (epoch **milliseconds**) — when the status
/// last changed. While `status == "busy"`, `now − statusUpdatedAt` is how long the current turn
/// has been running.
public struct RegistryInfo: Sendable, Equatable {
    public let status: String
    public let statusUpdatedAt: Double?
    public init(status: String, statusUpdatedAt: Double?) {
        self.status = status; self.statusUpdatedAt = statusUpdatedAt
    }
}

/// Parse a per-PID registry file for its status and `statusUpdatedAt`. Guards PID reuse by
/// requiring the recorded `sessionId` to match; `nil` if malformed, mismatched, or no status.
public func registryInfo(fromJSON data: Data, expectedSessionID: String) -> RegistryInfo? {
    guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let sid = obj["sessionId"] as? String, sid == expectedSessionID,
          let status = obj["status"] as? String, !status.isEmpty
    else { return nil }
    return RegistryInfo(status: status, statusUpdatedAt: (obj["statusUpdatedAt"] as? NSNumber)?.doubleValue)
}
