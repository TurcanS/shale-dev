# Redesign plan

One stage per web session. Each stage ends with the shell still starting and every panel still working; the owner
tests it locally before the next stage starts. Work on branch `redesign` (create it from `main` in stage 1).

Each stage lists its files and what "done" means. Copy the prompt into a new session on claude.ai/code with this repo
selected. After testing, start the next session with the `scripts/dev errors` output if anything broke.

---

## Stage 1: tokens and fonts
Files: `core/Theme.qml`, `assets/fonts/` (new), `shell.qml` (FontLoader), `helpers/backend.py` only if a setting is
needed.
Done: the new tokens from `docs/design/README.md` exist on `Theme`; Hanken Grotesk and Martian Mono are bundled with
OFL.txt and used by `Theme.font` / `Theme.mono` with the Adwaita fallback; old token names still resolve so nothing
breaks; the shell looks mostly the same but with the new colours and fonts.

Prompt:
> Do stage 1 of docs/PLAN.md on a new branch `redesign` from main. Read CLAUDE.md, docs/design/README.md and
> core/Theme.qml first. Download the OFL fonts from the google/fonts GitHub repo (ofl/hankengrotesk, ofl/martianmono).
> Keep old Theme property names working as aliases. Push the branch and give me the testing summary.

## Stage 2: shared controls
Files: `components/*.qml` (Button, Toggle, SliderRow, Segmented, ListRow, Group, QuickTile, Field, SectionHeader,
Tooltip, Card, Stat, StatusCard, GlyphTile, ChoiceRow, HoldButton, EmptyState, ScrollBar), `core/icons.js`.
Done: every control matches the Controls section of README.md and `previews/Language.png`; same public properties
and signals as before; panels pick up the new look without being edited.

Prompt:
> Do stage 2 of docs/PLAN.md on branch `redesign`. Restyle the components in components/ to the Controls section of
> docs/design/README.md, keeping their properties and signals. Add any missing line icons used by the mockups to
> core/icons.js. Push and summarise what to test.

## Stage 3: bar
Files: `features/Bar.qml`, `features/BarContent.qml`, `core/barItems.js`, `features/TrayMenu*.qml`.
Done: matches `previews/Bar.png` and the Bar entry in PANELS.md; floating 8 px from edges; all items, tray, bar
settings and multi-monitor still work.

Prompt:
> Do stage 3 of docs/PLAN.md on branch `redesign`: the bar, per docs/design/PANELS.md and previews/Bar.png. Keep every
> item's actions and the bar settings. Push and summarise what to test.

## Stage 4: Control, Network, Mixer, Session
Files: `features/ControlCenter.qml`, `core/controlItems.js`, `features/BluetoothDeviceRow.qml`,
`features/Equalizer.qml`, `features/StayAwake.qml`, `features/Power.qml`, `features/PanelHost.qml` /
`PanelContent.qml` (case styling and entrance motion for all panels).
Done: Control, its wifi / bluetooth / audio details and the session menu match their mockups; panel entrance motion
(rise 8 px + fade 180 ms) applies to every panel.

Prompt:
> Do stage 4 of docs/PLAN.md on branch `redesign`: PanelHost/PanelContent case and motion, then Control with its
> Network and Mixer details, then the session menu, per PANELS.md and the Control, Network, Mixer and Session
> mockups. Push and summarise what to test.

## Stage 5: Find, Notifications, toasts and OSD
Files: `features/Launcher.qml`, `core/search.js` (only if the grouping needs it), `features/Notifications.qml`,
`features/NotificationCard.qml`, `features/Toasts.qml`.

Prompt:
> Do stage 5 of docs/PLAN.md on branch `redesign`: Find, Notifications, toasts and the OSD, per PANELS.md and the
> Launcher, Inbox, Osd and Main mockups. Keep every search provider and keyboard path. Push and summarise.

## Stage 6: Clock and sky, Player, Wallpapers
Files: `features/Calendar.qml`, `features/WeatherCard.qml`, `features/Media.qml`, `features/MediaHoverCard.qml`,
`components/CoverArt.qml`, `features/Wallpaper.qml`.

Prompt:
> Do stage 6 of docs/PLAN.md on branch `redesign`: Clock and sky, Player and Wallpapers per PANELS.md and the
> Almanac, Media and Wallpapers mockups. Push and summarise.

## Stage 7: Lock screen
Files: `features/Lock*.qml`.
Done: matches `previews/Lock.png`; unlock, wrong password, Caps Lock, media, power and the transition all work;
nothing on the lock screen can be reached without unlocking.

Prompt:
> Do stage 7 of docs/PLAN.md on branch `redesign`: the lock screen per PANELS.md and previews/Lock.png. Don't change
> the PAM flow or the security behaviour. Push and summarise.

## Stage 8: Clipboard, Capture, Overview
Files: `features/Clipboard.qml`, `features/Capture.qml`, `features/Overview.qml`.

Prompt:
> Do stage 8 of docs/PLAN.md on branch `redesign`: Clipboard, Capture and Overview per PANELS.md and their mockups.
> Push and summarise.

## Stage 9: System monitor and Activity
Files: `features/System.qml`, `features/Activity.qml`, `components/Sparkline.qml`.

Prompt:
> Do stage 9 of docs/PLAN.md on branch `redesign`: System monitor and Activity per PANELS.md and their mockups. Keep
> every stat and the Activity consent and history behaviour. Push and summarise.

## Stage 10: Settings
Files: `features/Settings.qml`, `features/*Settings.qml`, `features/UpdatePage.qml`.

Prompt:
> Do stage 10 of docs/PLAN.md on branch `redesign`: Settings and all settings pages per PANELS.md and
> previews/Settings.png. Push and summarise.

## Stage 11 (optional): Widgets and Focus view
Files: `shell.qml` (bottom-layer window per output), new `features/Widgets*.qml`, a Focus view, `helpers/backend.py`
(settings), `features/Settings.qml` (Desktop page).

Prompt:
> Do stage 11 of docs/PLAN.md on branch `redesign`: desktop widgets and the Focus view per PANELS.md and the Main and
> Focus mockups. Widgets are opt-in (default off). Add settings defaults and validation in helpers/backend.py.
> Push and summarise.

## Stage 12: polish
A pass over everything the owner flagged while testing: spacing, contrast, keyboard focus rings, reduced motion,
fractional scaling. Then `scripts/dev promote` on the owner's machine moves the result to the public repo.
