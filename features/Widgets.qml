import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../services"

// Desktop widgets on one output: cards on the bottom layer, under every window, in the corner Settings → Desktop
// picks and in its order. The surface never takes the keyboard, and only the cards take the pointer. It is unmapped
// while a window on this output is fullscreen and while the session is locked, and so are the cards' clocks and
// samplers.
PanelWindow {
    id: root
    required property string outputName
    readonly property var widths: ({clock: 250, sky: 290, note: 260, system: 200})
    readonly property var cards: ShellState.setting("widgetCards", ["clock", "sky", "note", "system"]).filter(card => root.widths[card] !== undefined)
    readonly property string corner: ShellState.setting("widgetCorner", "bottom-left")
    readonly property bool atTop: corner.startsWith("top")
    readonly property bool atLeft: corner.endsWith("left")
    readonly property var monitor: Services.workspaces.find(w => w.monitor && w.monitor.name === root.outputName && w.active)
    readonly property bool fullscreen: !!monitor && monitor.hasFullscreen
    readonly property bool showing: cards.length > 0 && !fullscreen && !ShellState.locked
    // 24 px from the screen's edges (from the bar's, at the top), 12 px apart, with room on the open sides for the
    // cards' shadows.
    readonly property int edge: 24
    readonly property int gap: 12
    readonly property int room: 64
    readonly property int rowWidth: cards.reduce((sum, card) => sum + widths[card], 0) + Math.max(0, cards.length - 1) * gap
    function offset(card) {
        let x = 0;
        for (const other of cards) {
            if (other === card)
                return x;
            x += widths[other] + gap;
        }
        return 0;
    }
    function shown(card) {
        return cards.indexOf(card) >= 0;
    }
    visible: showing
    anchors {
        top: root.atTop
        bottom: !root.atTop
        left: root.atLeft
        right: !root.atLeft
    }
    implicitWidth: rowWidth + edge + room
    implicitHeight: 214 + edge + room
    color: "transparent"
    // Kept clear of the bar like a window, without asking windows to keep clear of the cards.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.namespace: "shale-widgets"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Clicks between and around the cards reach the desktop.
    mask: Region {
        Region { item: clockCard.visible ? clockCard : null }
        Region { item: skyCard.visible ? skyCard : null }
        Region { item: noteCard.visible ? noteCard : null }
        Region { item: systemCard.visible ? systemCard : null }
    }
    // Minutes are enough for every card; the clock stops with the surface.
    SystemClock {
        id: clock
        enabled: root.showing
        precision: SystemClock.Minutes
    }
    Item {
        id: row
        x: root.atLeft ? root.edge : root.room
        y: root.atTop ? root.edge : root.room
        width: root.rowWidth
        height: 214
        WidgetsClock {
            id: clockCard
            visible: root.shown("clock")
            x: root.offset("clock")
            width: root.widths.clock
            outputName: root.outputName
            now: clock.date
        }
        WidgetsSky {
            id: skyCard
            visible: root.shown("sky")
            x: root.offset("sky")
            width: root.widths.sky
            outputName: root.outputName
            now: clock.date
            live: root.showing && visible
        }
        WidgetsNote {
            id: noteCard
            visible: root.shown("note")
            x: root.offset("note")
            width: root.widths.note
            outputName: root.outputName
        }
        WidgetsSystem {
            id: systemCard
            visible: root.shown("system")
            x: root.offset("system")
            width: root.widths.system
            outputName: root.outputName
            live: root.showing && visible
        }
    }
}
