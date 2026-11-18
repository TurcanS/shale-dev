# Rack, studio edition: design language

Panels are dark cases holding modules, like a modern music app (FL Studio 2024, Ableton 12, Bitwig). One flat
backdrop, one module surface, soft corners, line icons and plain words. The accent comes from the wallpaper and marks
what is **on, live or chosen**. Everything else stays quiet.

Design files (live canvas, owner only: https://claude.ai/artifact/A2obyYkUzXVFqbwkWbBs9F):
- `previews/<Board>.png`: what every board looks like, at 1×. **Look at these first.**
- `previews/<Board>.html`: the same boards as static HTML; read it for exact sizes, colours, radii and text.
- `mockups/<Board>.dc.html`: the source templates (inline styles plus a small JS class with the demo state and
  behaviour). Read these for interactions; don't port the JS.
- `tools/build-previews.sh`: rebuilds `previews/` after a mockup changes (node + headless Chrome).

`previews/Language.png` is this page as a board.

## Colour tokens

| Token | Value | Use |
|---|---|---|
| backdrop | `#0e0f11` | behind panels, lock dimming |
| case | `#121316` | every panel (the outer box) |
| module | `#1c1e22` | cards and groups inside a panel, bar keys at rest |
| moduleAlt | `#17191c` | strips, stat tiles, zebra rows, settings content area |
| group | `#1f2125` | grouped settings rows (inside `moduleAlt`) |
| well | `#141518` | slider/graph backgrounds, fields, segmented track inside a module |
| key | `#2a2d33` | secondary buttons, empty tracks, icon tiles at rest (`#24272c` for list tiles) |
| keySelected | `#2c2f35` | the selected option of a segmented control |
| hairline | `rgba(255,255,255,0.06)` | case edge (as a 1 px inset shadow), separators (`0.05`) |
| text | `#efece6` | primary text |
| textSecondary | `#c9c6bf` | values, secondary labels |
| textMuted | `#a7a9ad` | unselected segment text |
| textDim | `#8c8f95` | metadata, captions, hints |
| textFaint | `#6b6f76` | placeholders, off items |
| knob | `#f4f2ee` | slider and switch thumbs |
| accent | from wallpaper | night-ridge `#ff8a3d`, aurora `#4fd1c5`, ember-city `#ff6b6b` in the mockups |
| accentSoft | accent at 14% | "on" background (tiles, rows, chips) |
| accentLine | accent at 40% | 1 px edge on "on" things |
| accentGlow | accent at 45% | `0 0 12px` glow on live meters and the volume fill |
| second | from wallpaper | night-ridge `#7fb2c4`, aurora `#d9b26a`, ember-city `#8fb8a8`; **only** a second chart line |
| onAccent | `#17181a` | text/icons on a filled accent |
| danger | `#ff6b5b` | power off, destructive; text `#ffb4a8`; background `rgba(255,107,91,0.07–0.2)` |

Rules:
- "On" = `accentSoft` background + `accentLine` edge + accent icon/text, or a filled accent icon tile with `onAccent`
  icon. Never the old cream key.
- The accent appears only for on / live / chosen / primary action / today / now. Charts are accent plus `second`.
- Body text 10:1 or better on its surface, secondary text 5:1 or better.

Existing code to reuse: `services/WallpaperAccent.qml` and `core/palette.js` (`accentFrom`, `oklch`, `tone`) for the
accent; `Theme.mix` / `Theme.contrast` for derived colours.

## Shape and spacing

| Thing | Radius | Notes |
|---|---|---|
| Case (panel) | 22 | padding 14, `0 0 0 1px hairline` + `0 30px 60px rgba(0,0,0,.35)` |
| Module | 16 | padding 12–14 |
| Inner card / row group | 12–14 | |
| Key / button / field | 10 | heights 28 / 32 / 36 / 44 |
| Segment option | 7 | inside a 10-radius track, padding 3, gap 2 |
| Icon tile | 8–11 | 28–36 px square |
| Chip / switch / OSD pill | fully round | |
| Bar | 14 | floats 8 px from the screen edges, 44 px tall |

Gaps 8–12 px between modules; list rows 42–48 px; panel header 32 px.

## Type

Hanken Grotesk for everything. Martian Mono only for rates, signal strength, hex values and commands. Sentence case
everywhere; no spaced-out capitals. Numbers use tabular figures.

| Role | Size / weight |
|---|---|
| Display (lock clock) | 168 / 600, tracking −0.04em |
| Widget clock | 64 / 600 |
| Big stat | 22–28 / 650 |
| Panel title | 17 / 650 |
| Section title in a panel | 20–22 / 650 (detail views), 14–15 / 600 (module titles) |
| Row / body | 14 / 400–600 |
| Secondary | 12–13 / 400 |
| Key hint chip | 11–12 on `module`, radius 5–6 |

Bundle `HankenGrotesk[wght].ttf` and `MartianMono[wdth,wght].ttf` (Google Fonts, OFL) in `assets/fonts` with
`OFL.txt`, load with `FontLoader`, and fall back to the current Adwaita fonts.

## Icons

Line icons on a 24 grid, stroke 1.8–2, round caps and joins, `currentColor`. Every action and every quick tile has
one. The mockups carry the exact paths; add missing ones to `core/icons.js` and draw them with `components/Icon.qml`.

## Controls (see `previews/Language.png` and `previews/Control.png`)

- **Primary button**: accent fill, `onAccent` text, 650. **Secondary**: `key` fill. **Danger**: danger edge at 45%,
  danger text, danger background at 7%; destructive power actions are hold-to-confirm (1 s, a fill or ring shows
  progress).
- **Switch**: 40×22 track (`key` off, accent on), 16 px `knob`, slides in 160 ms.
- **Segmented**: track `module` (or `well` inside a module), radius 10, padding 3; selected option `keySelected`
  with `0 1px 3px rgba(0,0,0,.4)`, white text; others `textMuted`.
- **Slider**: 6 px track `key`, fill accent (volume: gradient accentSoft→accent plus accentGlow), 16 px `knob`
  with `0 1px 5px rgba(0,0,0,.55)`; an icon button on the left mutes (danger soft when muted); value at the right.
- **Chip**: 28 px, fully round, 1 px `rgba(255,255,255,.08)` edge; on = accentSoft + accentLine + accent text.
- **Quick tile**: 60 px, radius 14; 36 px icon tile (`key` → accent when on), title 14/600, subtitle 12.
- **List row**: 42–48 px, radius 10–12; selected = accentSoft background, icon tile turns accent, hint text accent.
- **Undo bar**: floats 14 px from the bottom of the panel, `keySelected` background, accent "Undo" text.
- **Meters**: bars with `linear-gradient(to top, accentSoft, accent)`; rings (36 px, stroke 4) for shares.
- **Key hints**: small `module` chips in footers ("↑↓ Move", "↵ Open", "Esc").

## Motion

- Panels: rise 8 px and fade in 180 ms (`cubic-bezier(.2,.8,.2,1)`); leave 110–160 ms.
- Switch knobs 160 ms; hover colour 120–140 ms; press scales to 0.97–0.98 in 80 ms.
- Workspace pill stretches 220 ms. Meters update about every 120 ms; graphs once a second.
- Map to `Theme.fast` / `Theme.enter` / `Theme.leave`; `Theme.reduced` or `Theme.lowPower` → instant or shorter.

## Words

Control center → **Control** · Launcher → **Find** · Workspaces → **Pages** · Desktop widgets → **Widgets** ·
Calendar and weather → **Clock and sky** · Media → **Player** · Notifications stay **Notifications**.

## Proposed Theme.qml tokens

Keep existing names where the meaning is the same, add the new ones, and drop `surfacePalettes` tones only if
nothing else reads them:

```
backdrop case module moduleAlt group well key keySelected hairline
text textSecondary textMuted textDim textFaint knob
accent accentSoft accentLine accentGlow second onAccent danger dangerText dangerSoft
radiusCase 22  radiusModule 16  radiusCard 12  radiusKey 10  radiusSegment 7
caseShadow, panel enter/leave durations (existing fast/enter/leave)
font "Hanken Grotesk"  mono "Martian Mono"
```

## Live (stage 13)

The Rack language, evolved: the owner chose a material of its own instead of plain frosted glass, and motion with
physics. Power saver and Reduce effects keep everything above (solid cases, no pointer effects).

**Reeded glass** (`components/Frost.qml`, `assets/shaders/reeds.frag`, Settings → Appearance → Glass, on by default).
The owner turned down a refracting, glowing bevel as a Liquid Glass copy; the material is quiet, precise hardware:
- Body: the screen's wallpaper, blurred, through vertical reeds 16 px apart, under the case colour tinted 5% toward
  the accent at 80% (`glassCover`), saturation 1.15, never brighter than relative luminance 0.22 (`glassCeiling`).
- Each reed is lighter over its crown, softly creased where two meet, and carries a thin white glint; a fine grain
  (±0.9%) gives an etched finish and keeps the blur from banding. A touch darker toward the bottom.
- Edge: a 1 px chamfer that catches light at the top (white 17%, 4.5% at the bottom) and a dark line just inside it
  at the bottom. No glow, no refraction, no colour split.
- Under the pointer (lively motion only): the reeds near the pointer glint brighter, in white, as reeded glass does
  under a lamp; in over 220 ms, out over 520 ms. The bar's reeds and glint are at 60%.
- Surfaces inside glass are see-through: module white 5.5%, moduleAlt black 14%, group white 4%, well black 22%;
  `moduleSolid` is the solid module colour for backings that must hide what is under them. textDim is 12% lighter.
- A contact shadow (y 2, blur 6, black 30%) sits under the case's long shadow.
- Contrast on the owner's wallpaper (90th-percentile background): body text 11 to 13.5:1, secondary 7.9:1 or better,
  dim 5:1 or better at rest (about 4.3:1 on a tile right under the pointer).

**Motion**: entering and leaving on cubic-bezier(.23, 1, .32, 1), moving across the screen on (.77, 0, .175, 1),
colour on CSS ease; springs for things that follow a value or the pointer (`Theme.springSnappy`, `springCrisp`,
`springGentle`); content coming in 35 ms apart, at most six steps. Motion: Calm in Settings goes back to the first
Rack curves without springs, stagger or pointer effects.
