# Panels: what each one contains and where it lives

Each entry: preview image (static HTML with the same name next to it, source template in
`mockups/<Board>.dc.html`) → current QML → layout → behaviour to keep or add. Sizes are the mockup sizes at 1× and are a
guide; panels may grow with content but keep the proportions. All panels use the case/module/controls from
`README.md`. Header pattern unless noted: title 17/650, short status in `textDim`, controls on the right, a 32 px close
button where the panel has one today.

## Bar — `previews/Bar.png` → `features/Bar.qml`, `features/BarContent.qml`, `core/barItems.js`
- Floating strip, 44 px tall, radius 14, 8 px from the screen edges (needs the layer-shell margin and exclusive zone
  updated), `case` background with hairline.
- Left: **Search** pill (icon, "Search", `Super Space` hint) → **Pages**: dots in a `module` pill; current page
  stretches to a 26 px accent pill with glow; pages with windows `textDim`, empty `#3a3d42` → app initial tile +
  "App · title".
- Centre (absolute): time 14/650, date, weather icon + temperature; opens Clock and sky.
- Right: live chip (mic / camera / screen share in use: accentSoft + accent text, names the app) → now playing chip
  (cover tile with 3 moving bars, "Track · Artist") → status button (Wi-Fi, volume, battery % — opens Control) →
  bell with accent count badge → wallpapers → lock.
- Keep every item's existing click/scroll actions, tray, the bar settings (order/visibility from `barItems.js`) and the
  per-monitor behaviour.

## Control — `previews/Control.png` → `features/ControlCenter.qml`, `core/controlItems.js`, `components/QuickTile.qml`, `components/SliderRow.qml`
- 560 wide. Header "Control" + battery line + settings button.
- 2×2 quick tiles: Wi-Fi, Bluetooth, Do not disturb, Night light (keep the existing tiles and their detail arrows;
  extra tiles from `controlItems.js` continue the grid).
- Slider module: Volume (accent gradient + glow), Microphone, Brightness. Icon button mutes.
- Output module: three output buttons (speakers, headphones, HDMI — the real sinks), the selected one shows a small
  live meter; per-app volume rows below (existing stream data).
- Focus (Off/25/50/90) and Scene segmented modules side by side (Scene only if scenes exist; otherwise Focus full
  width).
- Power row: Lock, Sleep, Restart + **Hold to power off** (1 s fill).
- Detail views (`ShellState.detail`): `wifi` and `bluetooth` → Network layout below; `audio` → Mixer layout below.

## Network (Control detail: wifi / bluetooth) — `previews/Network.png` → `ControlCenter.qml`, `features/BluetoothDeviceRow.qml`
- Wi-Fi module: header with switch; current network as an accentSoft card (filled accent icon tile, "Connected ·
  band · speed", live ↓/↑, Forget); other networks as rows with strength drawn in the Wi-Fi icon arcs, lock icon if
  secured; a password field opens inline under the row; Hidden network… and VPN chips.
- Bluetooth module: Scan button with spinner; device rows with type icon tile (accentSoft when connected), battery
  badge (danger under 15%), Connect/Disconnect.

## Mixer (Control detail: audio) — `previews/Mixer.png` → `ControlCenter.qml`, `features/Equalizer.qml`
- Channel strips (master, each app stream, mic): colour tag, name, pan ring, stereo meters beside the fader, dB,
  M and S chips (solo silences the others).
- Equalizer module: on/off switch, presets segmented, graph with grid, filled curve and draggable band points,
  frequency labels.

## Find — `previews/Launcher.png` → `features/Launcher.qml`, `core/search.js`
- 680×480, no header: 60 px search field row with Esc chip; filter chips All / Apps / Windows / Actions.
- Empty query: at-a-glance strip (next event, weather, battery), then Suggested apps, one open window, one action.
- Results grouped (Apps, Open windows, Actions); selected row accentSoft, tile accent, "Open ↵" hint.
- Calculator result as an accentSoft card; `note …`, `timer …`, emoji, files, web prefixes keep working.
- Footer key hints and result count. Keep all existing search providers and keyboard handling.

## Notifications — `previews/Inbox.png` → `features/Notifications.qml`, `features/NotificationCard.qml`, `features/Toasts.qml`
- Header "Notifications" + count + Clear all. Do not disturb row (tile, subtitle, switch).
- Groups "New" / "Earlier today"; card: app icon tile (accent for urgent), "App · time", dismiss ×, title, body,
  action buttons (first primary) + Later. Undo bar after dismiss / clear all.
- Toast (`previews/Main.png`, bottom right) uses the same card. The OSD in `Toasts.qml` uses `previews/Osd.png`:
  a floating round pill with icon, slim bar and value (volume, brightness), and small round cards for mic, keyboard
  layout and Caps Lock.

## Clock and sky — `previews/Almanac.png` → `features/Calendar.qml`, `features/WeatherCard.qml`
- Header "Saturday 25" + "October 2026 · week 43".
- Month module: title, Today, ‹ ›; weekday row; 6×7 grid, today filled accent, picked day ring, event dots.
- Agenda module for the picked day (time, title, place; first in accent).
- Weather module: icon, temperature, condition, feels/wind, 3-day forecast, sky arc with the sun position, sunrise /
  sunset and "Sets in …". Keep the Open-Meteo data in `WeatherCard.qml`.

## Player — `previews/Media.png` → `features/Media.qml`, `features/MediaHoverCard.qml`, `components/CoverArt.qml`
- 460×260: cover art on the left with a live level strip; source chip ("Spotify · on Headphones"), title, artist ·
  album; seek slider with times; shuffle, previous, big round accent play, next, repeat.

## Wallpapers — `previews/Wallpapers.png` → `features/Wallpaper.qml`
- Header: title, Local / Wallhaven / Wallpapers.com segmented, search, close.
- Left: large preview with a small mock of the shell, name, file and size, colour swatches (accent, second, surface),
  Fill / Fit / Centre, Caption switch, Use wallpaper (In use when applied).
- Right: thumbnail grid (accent ring when selected, "In use" badge, accent dot), Add a folder tile.
- Keep thumbnails in `~/.cache/shale/thumbs`, the online sources and the transition.

## Lock — `previews/Lock.png` → `features/LockScreen.qml`, `LockContent.qml`, `LockClassic.qml`, `LockField.qml`, `LockPower.qml`, `LockStatus.qml`, `LockMedia.qml`, `LockAvatar.qml`, `LockBackdrop.qml`
- Blurred, darkened wallpaper. Date line and a 168 px clock centred near the top; glance chips under it (next event,
  weather, battery, notification count).
- Bottom centre: avatar, "Welcome back", pill password field with round accent arrow button, status line (Caps Lock,
  wrong password shakes the field with a danger edge).
- Bottom left: now playing and keyboard layout chips. Bottom right: round sleep, restart, power-off buttons.
- Keep PAM, the lock transition, the particles option and fractional-scaling fixes.

## Session — `previews/Session.png` → `features/Power.qml`
- Header with uptime and unsaved-work note; four tiles Lock / Sleep / Sign out / Restart (icon tile, label, note,
  key chip); Power off tile with a 1 s hold ring; status line.

## Clipboard — `previews/Clipboard.png` → `features/Clipboard.qml`
- Search row, filter chips (All, Text, Images, Links, Colours, Pinned), list on the left (type icon tile, first line,
  time, pin mark), preview on the right (full text / image / colour with hex and RGB), From / Copied / Type, Paste,
  Pin, Remove; undo bar; footer key hints.

## Capture — `previews/Capture.png` → `features/Capture.qml`
- Screenshot / Record tabs; mode tiles (Region, Window, Screen, Colour); options group (delay segmented; copy, save,
  pin switches — or system sound, mic, pointer when recording); recent shots; one large action button
  (recording shows a blinking dot and the elapsed time).

## Overview — `previews/Overview.png` → `features/Overview.qml`
- Header "Pages" + status + Find a window. 4×2 grid of small desktops (wallpaper gradient, a bar line, windows as
  cards with app tile and title); current page accent ring; matching windows stay bright while searching; click a
  window, then Move here on another page. Footer key hints.

## System monitor — `previews/System.png` → `features/System.qml`
- Header with uptime, process count, 1 min / 5 min, close.
- Left: device list (CPU, Memory, each disk, each network adapter, each GPU) with sparkline and one-line summary;
  selected device accentSoft.
- Right: detail module (name, model, current value, large area graph — network draws receive in accent and send in
  `second` — and four stat tiles) and a Processes module (sort by CPU / Memory, End with a "Sure?" second press).
- A sleeping GPU shows the asleep state and is never woken. Keep the existing stats from `helpers/backend.py`.

## Activity — `previews/Activity.png` → `features/Activity.qml`, `services/ActivityTracker.qml`
- Header with Overview / Day / Apps tabs, phase chip (Active now / Paused), Pause/Resume, close.
- Overview: four stat cards (Today, This week, Daily average, Streak), year heatmap (single-hue ramp from the accent),
  "When you're active" hour bars with the busiest hour in accent, rhythm list (starts, ends, busiest, since), Top
  apps list.
- Day: timeline you can click, breakdown cards (Active, Watching, Idle, First – last).
- Apps: ranked rows with active (accent) and watching (`second`) bars.
- Keep the consent screen, Clear history and all existing data.

## Settings — `previews/Settings.png` → `features/Settings.qml` and the `*Settings.qml` pages
- Sidebar: title, Find a setting, sections with icons (selected accentSoft + accent text).
- Content on `moduleAlt`: title 22/650 + one-line description; settings in `group` cards of rows (label + description
  left, control right, separators between rows).
- Appearance: accent from wallpaper or fixed swatches, wallpaper tint slider, behaviour switches.
- Bar: drag handle, item, description, up/down, show switch. Shortcuts: key caps + Change (records the next keys).

## Focus — `previews/Focus.png` → new view over `services/Focus.qml` (opened from Control's Focus module)
- Ring countdown with glow, "until 22:10", length segmented, held-notification count, Start/Pause + End now, end
  summary of what came in.

## Widgets (new) — `previews/Main.png` → new bottom-layer window per output in `shell.qml`
- Floating cards (radius 22, translucent case with blur): Clock (date, 64 px time, next event, day progress), Sky
  (temperature, condition, sun arc), Note (lines with check circles, add field; `note …` in Find appends), System
  (three rings: CPU, memory, temperature). Opt-in, at most six, settings in Settings → Desktop.

## Concept boards (not scheduled)
`Builder.html` (rearrange bar and widgets as modules), `Rituals.html` (start-up and lock animations),
`Features.html` (feature list). Only build these if the owner asks.
