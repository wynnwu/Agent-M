# Transcript Markdown export (full session) + wider detail window

## Goal

From a transcript detail window, export the **entire session** (not just the
~12 visible turns) to a nice Markdown file — scoped to whatever the filter is
set to: **All**, **Prompts** (user only), or **Responses** (assistant only).
A durable log of what the prompting and conversation were.

Plus: open the single-conversation window ~50% wider by default.

## Data foundation (verified against real transcripts)

- The viewer's `TranscriptStore` only holds the **tail** (~12 turns from the last
  256 KB). Export must read the **whole** `.jsonl`.
- A user **slash command** is a `type: user` record whose `content` string is:
  ```
  <command-message>name</command-message>
  <command-name>/name</command-name>
  <command-args>…</command-args>
  ```
  (not `isMeta`, so already kept by `renderable`).

## Components

### `AgentMCore` — pure, unit-tested

1. **`TranscriptParser.slashCommand(in:) -> SlashCommand?`**
   Extracts `<command-name>` (the `/name`) and optional `<command-args>` from a
   user turn's text. `nil` when the text isn't a command block.
   `struct SlashCommand { let name: String; let args: String? }`.

2. **`TranscriptExport.markdown(records:scope:meta:now:timeZone:) -> String`**
   - `scope`: `.all | .prompts | .responses`.
   - `meta`: folder, cwd, full sessionId, model (raw id), branch, kind.
   - Filters `records` by scope, formats each turn as a section.
   - `timeZone` defaults to `.current`; injectable so tests are deterministic.

### MD format

```markdown
# acme-web — Claude Code session

- **Path:** /Users/dev/Code/acme
- **Session:** a1b2c3d4e5f60718
- **Model:** Opus 4.8
- **Branch:** main · **Kind:** interactive
- **Exported:** 2026-07-17 02:20:31 · **Turns:** 12

---

## You · 2026-07-17 14:32:10
**`/goal`** ship the export feature      ← slash-command user turns

## You · 2026-07-17 14:33:02
Refactor the checkout flow to use the new payment SDK.   ← plain prompt

## Claude · 2026-07-17 14:33:40
On it — replacing the legacy PaymentGateway…

_used: Bash, Edit_
```

- Per-turn timestamp: full **local** `yyyy-MM-dd HH:mm:ss` (omitted if a turn has
  no timestamp).
- `Prompts` scope → only `## You` sections; `Responses` → only `## Claude`.
- Assistant tool notes: `_used: …_` when the turn used tools.
- Empty scope (e.g. Responses but none exist) → header + `_(No responses in this
  session.)_`.

### App target — IO + UI

3. **`TranscriptStore.fullRecords() -> [TranscriptRecord]`** — reads the entire
   file and returns `renderable(allLines)` (whole-session, clean conversation).

4. **Export button** (`square.and.arrow.up`) at the trailing end of the filter
   row in `TranscriptWindowBody`; exports *whatever's selected*. Wired via an
   `onExport: (TranscriptFilter) -> Void` closure (no-op default so snapshots and
   previews don't need a store). Disabled when there is no transcript.

5. **Save**: `TranscriptView` builds the MD, then a native **NSSavePanel**
   (`NSApp.activate` first, since the app is `.accessory`). Default filename
   `<folder>[-prompts|-responses]-yyyy-MM-dd.md`. Written UTF-8.

### Wider window

`AppDelegate.openTranscript` sets content size `480×600`; SwiftUI's `minWidth:520`
clamps it to ~520 visible. Set the default width to **780** (~50% wider); height
unchanged.

## Testing

Unit-test `slashCommand(in:)` and `TranscriptExport.markdown(...)`: all three
scopes, slash-command rendering, tool notes, timestamp formatting (pinned tz),
and the empty-scope note. Save/panel/window sizing verified by building + running.
