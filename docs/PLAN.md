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

Carry-over from stage 10: settings rows are `components/SettingRow.qml` (label and description on the left, the control
on the right, or under the label with `stacked`; `descriptionColor` for a row's own error or "Saved") on a `C.Group`,
with `C.Toggle { flat: true }` for switches; `ChoiceRow` is now a SettingRow with a Segmented. Settings draws its own
header (the sidebar title) and is 1060×680. Motion is part of Appearance (its Behaviour group), Audio is now Sound and
Control center is now Control; the old names still open their page (`shale settings motion`, `audio`,
`control-center`, Find's "settings:Control center"). Find a setting reads the rows from the pages themselves: every
item with a `description` and a `label` or `text` is found, under the page whose `objectName` is the category name, so
the stage 11 Desktop page needs a `categories` entry and that `objectName`, and nothing else, for its rows to be found.
Sound's equalizer button now opens Control → Sound (it opened the Player, which lost its equalizer in stage 6). Not
built for lack of settings: the preview's wallpaper tint slider, start-up and lock animations, soft clicks and the
wallpaper name on the desktop, and its Power page. For stage 12: `SectionHeader` keeps a 28 px minimum height, so the
gaps around section titles are a few pixels larger than in the preview.

Carry-over from stage 9: the helper now lists processes (`system.sample` takes `processes: "cpu" | "memory"` and returns
the top 30 with pid, start, name, CPU share of the whole processor, resident memory, `own` and `protected`) and ends one
with `system.end {pid, start}` (SIGTERM through `quit_process`, only the user's own, never the shell, its ancestors,
Hyprland, systemd or D-Bus; the start time guards against a reused pid). `activity.overview` insights gained `hours`
(active seconds per hour over the last 30 days). `Stat` takes `valueSize`, `noteSize`, `noteColor` and `inset`;
`Sparkline` draws its second line in `Theme.second` and has `filled`. `Button` rounds its content width up, which fixes
labels eliding by a fraction of a pixel (it showed in `Segmented` with `fill: false`); check other panels' segmented
controls still look right. System and Activity are both 960×660 (Activity's Clear history sits in a footer row under the
views). Activity's Day view no longer has the month calendar or the Day/Week toggle with its hour grid: days are picked
from the year grid or with ‹ › and Left/Right. Not built for lack of data: memory type and speed, a disk's full size and
kind (NVMe/SATA), Wi-Fi network name, data used today and signal in System's tiles, a GPU's driver and memory while
asleep, and which GPU is drawing the screen.

## Stage 11 (optional): Widgets and Focus view
Files: `shell.qml` (bottom-layer window per output), new `features/Widgets*.qml`, a Focus view, `helpers/backend.py`
(settings), `features/Settings.qml` (Desktop page).

Prompt:
> Do stage 11 of docs/PLAN.md on branch `redesign`: desktop widgets and the Focus view per PANELS.md and the Main and
> Focus mockups. Widgets are opt-in (default off). Add settings defaults and validation in helpers/backend.py.
> Push and summarise.

Carry-over from the second Settings pass: ordered lists in Settings use `components/OrderRow.qml` (grip handle,
optional glyph, name, description, earlier/later keys, show `Switch`; dragging the handle lifts the row) with
`components/DropLine.qml` (the accent line where it lands, across one or more groups; it sits last in the page with a
negative top margin of the layout's spacing). Reuse both for the Desktop page's widget order. Bar settings lost the
Left / Center / Right / Hide picker: items are dragged between the Left, Center and Right groups, the arrows step past
the end of a side into the next one, and the switch hides an item (shown again, it goes to the end of its default
side). Control's tiles and buttons use the same rows. The mini bar preview draws pages, clock and status key as the
bar does and follows the pages style and clock settings; items that only show while something happens stay out of
it. `KeyHint` takes `textSize` (Shortcuts uses 12). Dragging doesn't scroll the Settings page, so a long drag needs the
arrows. `core/icons.js` gained `grip` (rebuilt with `scripts/build-icons.py`).

## Stage 12: polish
A pass over everything the owner flagged while testing: spacing, contrast, keyboard focus rings, reduced motion,
fractional scaling. Then `scripts/dev promote` on the owner's machine moves the result to the public repo.

Carry-over from stage 11: widgets are `features/Widgets.qml` (one bottom-layer window per output, created by a
`LazyLoader` in `shell.qml` only while `widgets` is on; namespace `shale-widgets`, never takes the keyboard, an input
mask of the cards only, unmapped while that output's page has a fullscreen window and while locked) with the cards
`WidgetsCard` (the translucent case), `WidgetsClock`, `WidgetsSky`, `WidgetsNote` and `WidgetsSystem`, drawn at
design pixels (Panel size doesn't scale them). Settings: `widgets` (off), `widgetCards` (order of the shown cards, up
to six), `widgetCorner`; Settings → Desktop (`features/DesktopSettings.qml`, OrderRow and DropLine). The sun
calculation moved from `WeatherCard.qml` to `core/sky.js`, shared with the Sky card. The note is
`~/.local/state/shale/note.json` (`note.get`, `note.set`, `note.add`) behind the `services/Note.qml` singleton; Find's
`note …` appends a line (footer hint `note …` while the Note card is shown). The desktop never takes the keyboard, so
the Note card's add field opens Find with `note ` typed. The System card samples `system.sample` every 5 s (10 s with
effects trimmed) while it is on screen. The Focus page is Control's detail `focus` (`features/FocusView.qml`, 440 px,
opened from the Focus module's name); PanelContent gained `headerChip` ({text, on}) for its state chip.
`services/Focus.qml` gained pause and resume (`pause()`, `unpause()`, `paused`, and `paused` / `pausedFor` in
`focusSession`; the `focus` IPC target has `pause`): a paused session stays active, so notifications stay held exactly
as before. `shale page focus` and `shale focus pause` exist (`scripts/shale`). Not built for lack of data: the Clock
card's next event (no calendar events). Not built: the blur behind the cards, which needs a Hyprland layer rule for
`shale-widgets` in `integration/shale.lua` (left out because the Lua field names couldn't be checked here). For
stage 12: check clicks between and around the cards reach the desktop, the top corners sit under the bar, and the
Focus ring's halo (two wider translucent rings, hidden with effects trimmed).

Carry-over from stage 12 (passes A and B): `.claude/tools/shots.py OUT_DIR [panel ...]` opens each panel and Control
page in the running shell, screenshots it and prints the shell's warnings; use it to compare with `previews/` before
calling a panel done. `Theme.small` never goes under 12 px and `Theme.caption` under 11. With effects trimmed, the case
gets a dark 1 px ring instead of its shadow. Still to do in this stage (pass C): content-sized panels (Notifications,
Wallpapers ending on whole rows), a one-sink Output row in Control, Mixer strips across the module, Activity's year grid
from the first tracked week, idle processes as "—" in System, clearer empty pages in Overview, and a fade under the
Settings page. Then the parts system (one `core/parts.js` registry for desktop and bar, layouts) and the split of
ControlCenter, Activity, BarContent and Launcher with a `docs/ARCHITECTURE.md`.

Carry-over from stage 12 (passes C to E): Notifications sizes to its cards; `components/EdgeFade.qml` fades the bottom
of a scrolling view while more lies below (Wallpapers grid, Settings page); Control's Output shows one device as its
note; mixer strips share the module (72–120 px, centred); Activity draws the days before tracking as faint squares;
Overview's empty pages sit darker with a chip. Desktop cards come from `core/parts.js` (file, width, matching bar item,
layouts Work / Play / Evening, Mine saved in `widgetSaved`); new cards `WidgetsPlayer` and `WidgetsTimers`; Find's
`layout <name>` switches them. Control's Bluetooth, Power and Sound views and its small parts are their own
`Control*.qml` files (views get the page as `control`). `docs/ARCHITECTURE.md` maps the code. Not done: Control's
Wi-Fi and home views and the splits of Activity, BarContent and Launcher (same method: move a block, rename `root.`
to the page property, check ids used outside), the Builder board's bar row and room meters, and Settings' sidebar
footer.

Carry-over from the wallpaper crate: Wallpapers has no case any more (`chromeless`, 1440×600). The wallpapers are
leaning slices (`lean` 0.12) around the chosen 16:10 card, narrowing by 0.82 per step and dealt out from the centre on
opening; the chosen card is ringed and lit in the accent that wallpaper would give (`previewAccent`), which also lights
the transport's position line. Left/Right step, Up/Down jump five, Home/End, wheel, Enter or double-click applies;
online sources load the next page within four of the end. The thumbnail caching, sources, search and the
`wallpaper-picker` IPC are unchanged. Not drawn any more: the per-tile accent dots and the "Add wallpapers" tile (the
folder key in the transport opens the folder).

Carry-over from the improvement pass (settings safety, helper, fixes, features): `ShellState.setSetting` sends only the
keys changed here (`unsaved`) and keeps them across a helper restart; `settings.set` saves what it can and returns
`rejected: [{key, message}]`, which the shell toasts and puts back. `config.previous.json` is written only before a
reset or an import; `settings.restore` swaps it with today's settings (`ShellState.restoreSettings()`, the Undo on a
page reset, Backup's "Put back"); `settings.backup {path}` tells the Backup page when both were written. An export
never replaces a file that isn't a Shale export. `activityTracking` and `hiddenOutputs` are private keys. Helper:
`hypr_json()` for `hyprctl -j`, `probe()` for disk checks that may hang, `interface(..., alike=)` reuses one
introspection for look-alike objects, quick requests (`settings.*`, `note.*`, `notifications.*`) skip the 32-request
queue, clipboard pins carry `sha` and are matched by contents. `Backend.request` takes `{owner, silent}` (owner is
not used by any page yet and is unverified); a callback's error is logged as the caller's. `Services.failed(message)`
replaces `lastError`. `core/format.js` (`bytes`, `known`, `clock`, `span`, `shortSpan`) holds sizes and times; Power, Activity, Focus and
Updates still keep their own. IPC `shell` gained `open(panel)` (`shale open PANEL`) and `status` reports `detail` and
`screen`. `wifi.list` networks carry `band` and, connected, `speed`; `wifi.hidden {ssid, password}` joins a hidden
network; the forecast carries `wind`, `windFrom`, `humidity`. New settings: `wallpaperFit` (hyprpaper's cover,
contain, fill, tile; awww/swww only fit with contain), `activityKeep` (0, 30, 90, 365 days; trimmed once a day by
`ActivityStore.trim`), `quietHours` ([from, to] hours; `ShellState.quietNow` holds popups like Do not disturb).
Settings has a Power page; each page is its own `*Settings.qml`; rows take `settingKey` and show a `RowReset` key
while the setting differs from `settings.defaults`; `SettingToggle`, `FolderField`, `OpenRow`, `ValueRow` are
components; the sidebar takes Home/End/arrows and Right/Enter into the page. Backup has profiles
(`settings.profile.save/load/delete`, files in `~/.config/shale/profiles/`). The helper reports Caps Lock from the
keyboards' lights (`capslock` event, read 2.5 times a second) for an OSD; unverified with a real key press here.
`services/Weather.qml` keeps the one forecast. Split into files: `ControlWifi.qml`, the toast windows (`Toast*.qml`),
the bar items (`Bar*.qml` with `required property var bar`, passed as `bar: content`: `bar: bar` would bind to the
item's own property). Theme has `keyWash()`, `rowWash()` and `rowPressScale`. Still to do: `PanelHeader`, the splits
of Control's home view, Activity and Launcher and the helper's modules, one focus ring and row heights across
controls, a keyed model for Wi-Fi rows (rows are only rebuilt when the list changes), snippets (the design's are
typed into apps, which Shale doesn't do), calendar events, widget blur. The `Services.qml` "Unable to assign
[undefined]" warning shows only while the shell reloads, from the copy being torn down.

## Stage 13: Live
The owner asked for the whole shell to look more modern and, above all, feel alive: motion that is nice to watch,
useful and impressive. Their choices: evolve the look too (not only motion), every surface, the design and animation
skills plus the owner's own eye on the key visual choices, and any GPU cost while power saver is off (power saver and
Reduce effects keep today's cheap path). One pass per session; the owner tests between passes.

- Pass 0, motion foundation: lively/calm motion tokens and springs on `Theme`, `shale slowmo N`, the shared motion
  components, the Motion setting, and a look board of the frosted materials for the owner to pick from.
- Pass 1, material: frosted cases (`assets/shaders/frost.frag`: the blurred wallpaper under the case, the case colour
  over it, a lit 1 px edge), a contact shadow under the long one, translucent modules; panels, bar, toasts, tray menu
  and widgets; a Glass setting; contrast checked on bright wallpapers.
- Pass 2, bar: one travelling page pill on a spring, items that arrive and leave without moving the bar in a jump,
  rolling window title and track, badge pop and rolling count, a keyed tray model, breathing live indicators, tray
  menus that grow from their icon.
- Pass 3, panels: panels grow from the bar key that opened them, panel-to-panel morphs, directional navigation in
  Control and Settings, staggered content, sliding selection highlights, Clipboard list motion, rolling live numbers.
- Pass 4, notifications: toasts on a spring, swipe to dismiss, the stack closing up while a card leaves, a paused
  timeout line on hover, a calmer OSD bump and morphing OSD kinds.
- Pass 5, lock, wallpaper, widgets: a shader wallpaper reveal, the lock zooming and blurring in and coming back into
  focus on unlock, a decaying shake, widget cards that stagger in and slide.
- Pass 6, consistency: Theme curves everywhere instead of hand-typed ones, the remaining snaps (ListRow press,
  HoldButton drain, Tooltip glide, focus rings), reduced motion keeping short fades, a profile of Control and the bar.

Carry-over from pass 0: `Theme.easeOut` is now the strong cubic-bezier(.23, 1, .32, 1) with lively motion (Rack's
first curve with calm); `easeInOut` is for movement across the screen, `easeDrawer` for sheets, `easeHover` for
colour. `Theme.ms(duration)` applies `shale slowmo`; wrap any new literal duration in it. `Theme.springs` (off when
calm, trimmed or slowed down) gates SpringAnimation; use `springSnappy` (pills, badges: settles in 320 ms with about
7% overshoot), `springCrisp` (highlights, knobs: 225 ms, none) or `springGentle` (cases: 400 ms, none), measured
with Qt's SpringAnimation, and give every spring Behavior a timed fallback. `Theme.reveal`, `stagger` (35 ms) and
`staggerMax` (6) drive `components/Reveal.qml` (`order` sets the place in a stagger; it fills itself with its one
child; `replay()`). `Pop` (badges: `shown` and `bump()`), `RollText` (`maximumWidth` to elide; the width eases),
`RollNumber` (columns counted from the right, rolling forward when the number grows) and `PointerLight` (put first
inside a card, under its content; drawn additively by `assets/shaders/pointerlight.frag`) are not used by any panel
yet. Shaders are compiled with `/usr/lib/qt6/bin/qsb --qt6` and the `.qsb` is committed beside the source.
Offscreen previews draw ShaderEffect only on the GPU backend (`QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl` with
the offscreen platform; the software backend draws nothing for it). The look board's frost prototype lives in the
session scratchpad, not the repo; Pass 1 builds it as a component, with `glass` added then (Pass 0 added only
`motionStyle`).

Carry-over from pass 1: cases are studio glass (`components/Frost.qml` with one `FrostSource` per window; see the
Live section of `docs/design/README.md` for the values). A Frost needs `area`, where it lies on its screen in
pixels as drawn: PanelHost works it out from the case, the bar from its margins, each toast window from its anchors
(centred windows: half the spare width; bottom right: the screen size less the window). Transforms during an
entrance (a few px) are not followed. While glass is on, `PanelContent`, the bar's case and the toast cards draw no
fill of their own, so a new floating surface must add a Frost or use `Theme.moduleSolid` / `caseColor`:
`Theme.module`, `moduleAlt`, `group` and `well` are see-through then, and `Theme.mix` mixes with opacity
(premultiplied), so `mix(module, text, f)` hovers stay see-through. Not on glass yet: the tray menu and the media
hover card (popup windows whose screen position is harder to know; they keep the solid case), and the desktop
widgets (their window's place depends on the bar's reserved space; Pass 5). The Settings page's bottom fade is
weaker on glass (it fades to see-through moduleAlt). Glass shows the wallpaper, not the windows behind a panel, by
design. Offscreen previews of the glass need the GPU backend (see pass 0).
