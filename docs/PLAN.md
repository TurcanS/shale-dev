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

Carry-over from stage 2: set `glow: true` on Control's volume slider and `showTitle: false` on its three main
sliders (per-app rows keep their titles). Chip, Undo bar, key-hint and ring-meter components don't exist yet; add
them to `components/` when a panel in this or a later stage first needs one, and reuse them after that. Activity's
Clear history button may sit 2 px high (old bottom padding in Activity.qml); fix it in stage 9.

Carry-over from stage 3: `components/Button.qml` works out its width from its content item in a way that misses
late font loading, so buttons with custom content can clip; fix it at the start of stage 4 (the bar keys work around
it today). The owner chose a 38 px bar with no Search pill and no Wallpapers or Lock items; that overrides
`previews/Bar.png` and the bar in `previews/Main.png`.

## Stage 5: Find, Notifications, toasts and OSD
Files: `features/Launcher.qml`, `core/search.js` (only if the grouping needs it), `features/Notifications.qml`,
`features/NotificationCard.qml`, `features/Toasts.qml`.

Prompt:
> Do stage 5 of docs/PLAN.md on branch `redesign`: Find, Notifications, toasts and the OSD, per PANELS.md and the
> Launcher, Inbox, Osd and Main mockups. Keep every search provider and keyboard path. Push and summarise.

Carry-over from stage 4: new components exist and must be reused: `Chip`, `KeyHint`, `Ring`, `Switch`, and
`Segmented` has a proportional option. Panels already get the case and entrance from PanelContent/PanelHost; don't
add their own. Not built for lack of data, candidates for a later backend stage: Wi-Fi band, link speed and live
↓/↑ rates, a hidden-network action, the "N apps have unsaved work" note, real per-app and mic meters (the mixer
estimates them from cava), and Scenes.

## Stage 6: Clock and sky, Player, Wallpapers
Files: `features/Calendar.qml`, `features/WeatherCard.qml`, `features/Media.qml`, `features/MediaHoverCard.qml`,
`components/CoverArt.qml`, `features/Wallpaper.qml`.

Also decide with the owner whether the Player page keeps its own equalizer (it now lives in the mixer too).

Prompt:
> Do stage 6 of docs/PLAN.md on branch `redesign`: Clock and sky, Player and Wallpapers per PANELS.md and the
> Almanac, Media and Wallpapers mockups. Push and summarise.

Carry-over from stage 5: reuse `components/UndoBar.qml` (Clipboard in stage 8) and the PanelContent header count.
Panels are drawn at the Panel size setting (default 85%); size new panels in design pixels and let that setting
scale them. Still missing data: a Caps Lock state outside the lock screen (no Caps Lock OSD card yet) and calendar
events (Find's glance strip shows the date instead of the next event). Clearing one app's notifications is now
Shift+Delete or Shift-click on ×. Settings has a new Displays page (stage 10 restyles it with the rest).

## Stage 7: Lock screen
Files: `features/Lock*.qml`.
Done: matches `previews/Lock.png`; unlock, wrong password, Caps Lock, media, power and the transition all work;
nothing on the lock screen can be reached without unlocking.

Prompt:
> Do stage 7 of docs/PLAN.md on branch `redesign`: the lock screen per PANELS.md and previews/Lock.png. Don't change
> the PAM flow or the security behaviour. Push and summarise.

Carry-over from stage 6: the Player has no equalizer of its own any more (it lives in Control → Sound; the Player's
"on <output>" opens Sound), and Control is 460 px wide while it shows the Player. Pages can set `titleSize` for the
PanelContent header (Clock and sky uses 22). Sunrise and sunset are worked out in `WeatherCard.qml` from the city's
position and shown in the computer's time zone. Not built for lack of data, candidates for a later backend stage:
calendar events (the agenda shows the picked day with Copy date / Copy time, the month has no event dots), wind,
wallpaper Fill / Fit / Centre and the Caption switch (`wallpaper.apply` always uses cover), the resolution and size of
local wallpapers, and more than one wallpaper folder (the "Add wallpapers" tile opens the folder). In Wallpapers,
Up and Down now move a row of the grid.

## Stage 8: Clipboard, Capture, Overview
Files: `features/Clipboard.qml`, `features/Capture.qml`, `features/Overview.qml`.

Prompt:
> Do stage 8 of docs/PLAN.md on branch `redesign`: Clipboard, Capture and Overview per PANELS.md and their mockups.
> Push and summarise.

Carry-over from stage 7: the lock screen's parts are shared by both styles: `LockPrompt` (picture, "Welcome back",
field, status line and the wrong-password shake), `LockStatus` (now the glance chips under the clock: weather from the
cached forecast, battery, notification count), `LockMedia` and `LockKeyboard` (bottom-left chips; the layout chip only
shows the layout) and `LockPower` (Sleep, and Restart and Shut down on a press and hold; `LockScreen` gained `reboot()`
and `suspend()` beside `shutdown()`). The particle style keeps its clock and motion and wears the same chrome. Not
built for lack of data: the next-event chip. For stage 12: `LockTransition` still closes the classic style's fold on
47% of the height, where its clock used to be; the clock now sits near the top (the particle clock still matches).

## Stage 9: System monitor and Activity
Files: `features/System.qml`, `features/Activity.qml`, `components/Sparkline.qml`.

Prompt:
> Do stage 9 of docs/PLAN.md on branch `redesign`: System monitor and Activity per PANELS.md and their mockups. Keep
> every stat and the Activity consent and history behaviour. Push and summarise.

Carry-over from stage 8: Clipboard has pins now (`clipboard.pin`, `clipboard.unpin` with `forget`, `clipboard.text`,
and `pins` beside `entries` in `clipboard.list`); pinned entries are copied to `~/.local/state/shale/clipboard-pins`
(0600, up to 50) so Clear and cliphist's trimming never take them, and a history entry that matches a pin shows only
as the pin. Removing goes through the undo bar and is sent when it goes or the panel closes. Enter copies (the button
says Copy, not Paste: nothing types into the app), Delete removes while the search is empty (Shift+Delete always),
Ctrl+P pins, Ctrl+Tab steps the filter. Capture and Overview draw their own header (title, tabs or search, close).
Capture reads the hint from the live screenshot shortcuts and lists recent shots with `FolderListModel`; Colour is
the fourth screenshot mode. Overview shows pages 1–8 plus any later or scratch page that has windows, places windows
from Hyprland's `at`/`size`, picks a window on click (double-click or Enter focuses it), and the number keys go to or
move to a page while the search is empty. Not built for lack of data: a source app and copy time per clipboard entry
(cliphist keeps neither), snippets, Save off and Pin above windows for screenshots, the Show the pointer switch for
recordings, and system sound and microphone together (wf-recorder takes one source).

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
