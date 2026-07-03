# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.6] - 2026-07-03

### Added
- **Jump to a session's terminal tab.** Click any row to bring the exact terminal tab the
  agent is running in to the front — **Warp** (via its `warp://session` focus URL) and
  **Apple Terminal** (via AppleScript, matched by tty). The terminal is read from the
  session's own environment; no hooks, no setup, and it never writes to `~/.claude/`.
  ⌘-click a row — or click the new transcript bubble at its bottom-right — to open the
  in-app transcript instead.

### Changed
- The dropdown is **~20% wider**, so more of each prompt and directory path is visible.
- The **column headings** (Idle / Waiting for you / Working) are larger.
- **Hovering a row** now shows the pointer (link) cursor and a subtle orange glow that
  spills in from the top-left, matching the row's new click-to-jump behavior.

### Fixed
- Row hover (cursor + highlight) now works in **every** column, not just the leftmost. The
  columns used a custom `NSScrollView`; with several side by side, only the first received
  mouse tracking. Replaced it with a native SwiftUI scroll view. (Scroll bars now follow
  your macOS "Show scroll bars" setting.)

## [0.1.5] - 2026-07-03

### Added
- A **live turn timer**. Interactive sessions in the **Working** column now show a
  once-per-second ticking elapsed (`⏱ 1m 20s`) of how long the current turn has been
  running, from the per-PID registry's `statusUpdatedAt`. It replaces the uninformative
  "now" on active rows; background jobs (no per-turn timing) keep the relative time.
- The **transcript window** header shows the same live elapsed while a turn is running, and
  `last turn 13s` once the session hands back — derived from the transcript's own timestamps
  (last `end_turn` minus the prompt that started it).

## [0.1.4] - 2026-07-03

### Added
- Each session row now shows the **model** it's running (e.g. `claude-opus-4-8`) in
  monospace, on its own line under the prompt. It's read from the session's most recent
  assistant turn; a session that hasn't replied yet simply omits it.

### Changed
- Rows now size to their **natural height** instead of a fixed height, so a short session
  takes less vertical space than a busy one with a two-line prompt.
- The **directory** moved off the title line onto its own line (the parent path, since the
  folder name is already the title), giving each row a compact stack under the prompt:
  model → path → branch. The dropdown shows about 3.5 rows before scrolling.

## [0.1.3] - 2026-06-28

### Fixed
- A session that finished its turn awaiting your reply now shows under **Waiting for
  you** — even when it ends with a statement ("I'll wait for your word…") rather than a
  literal "?", and even when `claude agents --json` still reports it as `busy`. Detection
  keys off the transcript's completed `end_turn` turn plus its closing text, so it
  overrides a stale `busy` without mislabeling a session that's actively working.

## [0.1.2] - 2026-06-28

### Fixed
- Sessions sitting at a shell — or blocked on a permission prompt — no longer show as
  **Working**. `claude agents --json` collapses the finer `shell`/`waiting` states into
  `busy`; Agent M now reads the per-PID session registry (`~/.claude/sessions/<pid>.json`)
  and prefers its un-collapsed status (guarded against PID reuse).
- The status poll can no longer hang indefinitely. Spawned `claude` calls now have a
  15-second watchdog that terminates a stuck process instead of wedging the poller.

### Changed
- The full session status vocabulary is recognized and mapped: interactive
  `busy` / `shell` / `idle` / `waiting`, and background
  `working` / `blocked` / `done` / `failed` / `stopped`. A `waiting` interactive session
  (permission prompt / input request) and a `blocked` background job now land in
  **Waiting for you**. See `docs/DISCOVERY.md` for the authoritative mapping.

## [0.1.1] - 2026-06-26

### Added
- An app icon, shown in Finder and on the `.dmg`.
- List rows: the prompt now wraps to two lines, and the git-branch pill is larger.

### Changed
- Renamed the app and bundle to **Agent M** (bundle id `xyz.joystudios.agent-m`).
- Detail window: the git branch moved to a top-right pill (matching the list), and the
  metadata line (model · kind · pid · uptime · id) is larger.
- The default global shortcut is now **⌥M** (still opt-in / disabled by default).

## [0.1.0] - 2026-06-26

First release.

### Added
- Menu-bar status item with a badge of how many agents are active.
- A centered, glass (vibrancy) dropdown that slides down from behind the menu bar, with
  three columns — **Idle**, **Waiting for you**, **Working** — showing up to five rows each
  before fading overlay scrollbars kick in; empty columns stay visible.
- Each row shows the folder, last prompt, directory path, git branch, a status dot, and the
  relative last-active time.
- A live transcript window per session: renders user/assistant turns, follows new turns,
  flags when a session is waiting for your reply, shows a header with model · branch · kind ·
  pid · uptime · session id, and filters to All / Prompts / Responses.
- Adaptive status polling (~10s while active, backing off to 30s when idle) plus live
  `DispatchSource` transcript watching, with reads cached per file size.
- An optional, opt-in global shortcut (Settings → enable and record a combo) to toggle the
  dropdown from anywhere; Esc, click-away, and the icon also dismiss it.
- `AgentMCore` library (models, JSONL parser, status grouping, formatting) with unit tests.
- `scripts/make-app.sh` to package a double-clickable, menu-bar-only `.app`.

[0.1.6]: https://github.com/wynnwu/agent-m/releases/tag/v0.1.6
[0.1.5]: https://github.com/wynnwu/agent-m/releases/tag/v0.1.5
[0.1.4]: https://github.com/wynnwu/agent-m/releases/tag/v0.1.4
[0.1.3]: https://github.com/wynnwu/agent-m/releases/tag/v0.1.3
[0.1.2]: https://github.com/wynnwu/agent-m/releases/tag/v0.1.2
[0.1.1]: https://github.com/wynnwu/agent-m/releases/tag/v0.1.1
[0.1.0]: https://github.com/wynnwu/agent-m/releases/tag/v0.1.0
