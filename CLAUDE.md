# Shale redesign workspace

Shale is a Quickshell (QML) desktop shell for Hyprland with a Python helper (`helpers/backend.py`). This private repo
is where the "Rack, studio edition" redesign is built. The owner tests every change on their own machine; this
environment has no Wayland session, so you cannot run the shell here.

## Read first, every session
1. `docs/PLAN.md`: the stages. Do only the stage the owner names, then stop.
2. `docs/design/README.md`: the design language (tokens, controls, type, motion, words).
3. `docs/design/PANELS.md`: what each panel contains and which QML files it maps to.
4. For each panel you build, look at `docs/design/previews/<Board>.png` (what it must look like) and read
   `docs/design/previews/<Board>.html` for exact sizes, colours and text. `docs/design/mockups/<Board>.dc.html`
   holds the interactions (a small JS class per board); read it for behaviour, don't port the JS.
5. Before calling a panel done, compare it with its preview: same structure, spacing, colours and wording.

## Rules
- Commits: short imperative subject in plain English, like the existing history. Never add `Co-Authored-By`,
  "Generated with", or any mention of Claude, Anthropic or AI in commits, code, comments or docs.
- Work on the branch the owner names (default `redesign`). Push it when the stage is done. Never push to `main`,
  never force-push, never create tags or releases.
- Keep behaviour: every panel keeps its existing data sources, IPC names (`ShellState.panels`, `shell` IPC target),
  settings keys and keyboard handling. This is a visual and layout redesign, not a rewrite of the logic.
- Keep the engine, rebuild the views: `helpers/`, `services/`, `core/ShellState.qml`, `core/Backend.qml`, the lock's
  PAM flow, IPC, install and update scripts stay as they are. A panel's QML view may be rewritten from scratch when
  its layout differs a lot from today's (System, Activity, Clipboard, Overview, Lock, Settings); move its existing
  bindings, models and handlers into the new layout rather than inventing new ones.
- Read a file before changing it. Match the surrounding code style and comment density.
- Every new animation honours `Theme.reduced` and `Theme.lowPower` (duration 0 or shorter).
- New settings: add a default and validation in `helpers/backend.py` (`DEFAULTS`, `check_setting`) and a row in
  the matching settings page.
- No new runtime dependencies. Fonts are bundled under `assets/fonts` with their OFL licence files and loaded with
  `FontLoader`.
- `tests/` is not in this repo (it is local only). Don't create it.
- If `/usr/lib/qt6/bin/qmllint` (or `qmllint6`) exists, lint the QML you changed. If it doesn't, say so in the summary.
- Don't touch `docs/design/`, `docs/PLAN.md`, `docs/DEV.md`, `scripts/dev` or this file unless asked.

## End of a session
Finish with a short summary for the owner: what changed (files), what to look at when testing (which panels, which
interactions), anything unfinished, and lint results. The owner tests with `scripts/dev run` and pastes
`scripts/dev errors` output into the next session.
