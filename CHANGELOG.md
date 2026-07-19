# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.3] - 2026-07-19

### Fixed
- **Hover tooltips now actually appear** on the "Export all" button and the pid/id copy chips.
  SwiftUI's `.help()` doesn't reliably show tooltips in an accessory (menu-bar) app, so these now
  use an AppKit-backed tooltip (a transparent backing view's `toolTip`) that shows dependably and
  never intercepts clicks.

## [0.3.2] - 2026-07-19

### Changed
- **Clearer that Export saves the whole session.** The transcript filter tabs (All / Prompts /
  Responses) are now sized to their labels instead of stretching full-width, and the button reads
  **Export all** — pushed to the right of the row. Its tooltip spells out the scope, e.g. "Export
  all prompts from the whole session as Markdown — not just the turns shown."

## [0.3.1] - 2026-07-17

### Changed
- **The detail window now shows the same live status as the menu-bar panel** — Working (with a
  running timer), Waiting for your reply, or nothing when idle — read straight from the session
  service. Previously it guessed from the visible turns, which broke on long working turns whose
  opening prompt had scrolled out of view (it wrongly showed "Waiting" while the agent was busy).
- **Export now defaults to your Downloads folder** and shows a **confirmation toast** when it lands
  ("Exported N turns" + filename); click it to reveal the file in Finder.
- **Clearer empty state:** "Nothing to Show — No <prompts/responses> in the last few turns. Export
  will show entire history." — a nudge that Export isn't limited to what's on screen.

## [0.3.0] - 2026-07-17

### Added
- **Export a session to Markdown.** An **Export** button next to the transcript filter writes the
  **whole session** (not just the ~12 turns on screen) to a nice `.md` file via a native Save
  dialog. It respects the filter — **All**, **Prompts** only, or **Responses** only — so you can
  keep a clean log of just your prompting or the full conversation. Each turn is stamped with its
  full local date-time (`yyyy-MM-dd HH:mm:ss`), assistant turns note the tools they used
  (`_used: Bash, Edit_`), and user slash-command invocations render as **`/goal` …**. The document
  opens with a header of session id, model, branch, kind and export time.

### Changed
- **The single-conversation window opens ~50% wider** by default, so more of each turn is visible
  without resizing.

### Fixed
- **Detail window no longer says "Waiting for your reply" while an agent is working.** It used a
  naive "last turn was the assistant's" check, which is true mid-turn too (before `end_turn`). It
  now suppresses the banner whenever a turn is in progress, so the window agrees with the menu-bar
  panel's Working status.

## [0.2.2] - 2026-07-17

### Changed
- **The pid / id copy chips moved to their own line** in the transcript header. At narrow
  window widths the chips were crowding out the info above them (model, kind and uptime got
  truncated to `Opu…` / `inter…` / `up 4…`). They now sit on a dedicated row under
  `model · kind · up-time`, which stays fully visible.

## [0.2.1] - 2026-07-17

### Added
- **Copy a session's pid or id from the detail header.** The `pid` and `id` pieces of the
  transcript window's header are now click-to-copy chips, each with a small copy icon so it's
  clear they're interactive: they highlight on hover, the cursor becomes a pointing hand, and
  clicking flashes a checkmark. Copying **id** puts the **full** session id on the clipboard
  (not the 8-char prefix shown), so it's ready for `claude --resume` or log grepping.

## [0.2.0] - 2026-07-11

### Added
- **Idle agents are numbered too.** The `1`–`9` jump shortcuts now continue past Working and
  Waiting-for-you into the **Idle** column, so any of your first nine agents is a single
  keypress away. Numbering still starts at the top of Working.
- **Esc returns you to where you were.** Opening the panel remembers the app that was frontmost;
  pressing **Esc** hands focus back to it, so you land right back in your terminal (or wherever
  you came from) instead of nowhere.

### Changed
- **Working agents now glow instead of blinking.** The pulsing status dot is replaced by a soft,
  gently breathing glow that spills from the dot toward the right, under the card — green for
  interactive agents, blue for background jobs (matching each row's dot). A calmer, prettier
  "this one's alive" cue.

## [0.1.7] - 2026-07-11

### Added
- **Jump to an agent by number.** With the panel open, press **1–9** to bring the Nth agent's
  terminal tab to the front — numbered top-to-bottom down **Working**, then continuing into
  **Waiting for you**. Each numbered row shows its digit as a badge at the bottom-right. Turn it
  off under Settings → Jump Shortcuts.
- **Refresh shortcut.** Press **⌘R** while the panel is open to reload the session list.
  Re-bindable and toggle-able under Settings → Refresh Shortcut.
- **"Refreshed m:ss ago"** in the toolbar — a live count of how long since the last poll, which
  resets whenever the list refreshes (manually, by shortcut, or on the next poll).

### Changed
- **Toolbar redesign.** The settings gear, the refresh button with its `⌘R` hint, and the
  "Refreshed …" indicator now sit together on the **left**; **Agent M** is centered; the
  global-shortcut hint and Quit are on the right.
- The global-shortcut hint now reads **"⌥M Open from anywhere."** — the "· esc" note moved into
  Settings, which now spells out that **Esc** dismisses the panel.
- **Settings text is larger** and easier to read, with bigger section headings, and the row
  shortcut badges are more legible.

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

[0.3.3]: https://github.com/wynnwu/agent-m/releases/tag/v0.3.3
[0.3.2]: https://github.com/wynnwu/agent-m/releases/tag/v0.3.2
[0.3.1]: https://github.com/wynnwu/agent-m/releases/tag/v0.3.1
[0.3.0]: https://github.com/wynnwu/agent-m/releases/tag/v0.3.0
[0.2.2]: https://github.com/wynnwu/agent-m/releases/tag/v0.2.2
[0.2.1]: https://github.com/wynnwu/agent-m/releases/tag/v0.2.1
[0.2.0]: https://github.com/wynnwu/agent-m/releases/tag/v0.2.0
[0.1.7]: https://github.com/wynnwu/agent-m/releases/tag/v0.1.7
[0.1.6]: https://github.com/wynnwu/agent-m/releases/tag/v0.1.6
[0.1.5]: https://github.com/wynnwu/agent-m/releases/tag/v0.1.5
[0.1.4]: https://github.com/wynnwu/agent-m/releases/tag/v0.1.4
[0.1.3]: https://github.com/wynnwu/agent-m/releases/tag/v0.1.3
[0.1.2]: https://github.com/wynnwu/agent-m/releases/tag/v0.1.2
[0.1.1]: https://github.com/wynnwu/agent-m/releases/tag/v0.1.1
[0.1.0]: https://github.com/wynnwu/agent-m/releases/tag/v0.1.0
