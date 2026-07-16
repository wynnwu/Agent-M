# Copy PID / Session ID from the detail header

## Goal

Let the user copy a session's **pid** or its **full session id** to the clipboard
from the transcript detail window, with one click.

## Motivation

The detail header's `metaLine` shows `pid 1234` and `id a1b2c3d4`, but:
- the session id is displayed **truncated to 8 chars**, so text-selecting it only
  yields the prefix — the full id (needed for `claude --resume`, log grepping, etc.)
  is not otherwise reachable from the UI;
- selecting one value out of a `·`-joined line is fiddly.

## Design

Restructure the header `metaLine` (currently one joined, text-selectable `Text` in
`TranscriptView.swift`) into an `HStack` of pieces:
- static parts — model · kind · up-time — stay plain text with `·` separators;
- **pid** and **id** become interactive **copy tokens**.

### `CopyToken` view (new, local to `TranscriptView.swift`)

Inputs: a `label` string (e.g. `pid 1234`, `id a1b2c3d4`) and the `value` to copy.

- Renders `label` + a trailing `doc.on.doc` SF Symbol (the standard macOS copy glyph).
- **Hover:** subtle rounded background (`Color.white.opacity(~0.08)`); cursor becomes
  `NSCursor.pointingHand` via `.onHover` (`.pointerStyle` is macOS 15+, min target is 14).
- **Click:** writes `value` to `NSPasteboard.general`; the copy glyph flashes to
  `checkmark` for ~1s, then reverts.

### Values

- **pid** → the raw `target.pid` number.
- **id**  → the **full** `target.sessionId` (not the 8-char display prefix).

## Scope / non-goals

- Confined to `TranscriptView.swift`. No model-layer or dependency changes.
- Existing `.textSelection(.enabled)` stays for the non-token parts.

## Testing

Pure AppKit/SwiftUI IO (pasteboard + cursor) — verified by building and running the
app, not unit tests.
