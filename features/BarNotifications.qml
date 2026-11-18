import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Pipewire
import "../core"
import "../core/barItems.js" as BarItems
import "../services"
import "../components" as C

BarKey {
    id: bell
    // The bar this item is on: its screen, layout, weather and helpers.
    required property var bar
    readonly property int count: Services.notifications.length
    readonly property bool dnd: ShellState.setting("dnd", false) || ShellState.quietNow
    implicitWidth: 32
    // Do not disturb swaps the bell so suppressed popups are never a surprise.
    glyph: dnd ? "bell-off" : "bell"
    selected: ShellState.panel === "notifications" && ShellState.screenName === bar.outputName
    hint: "Notifications"
    tooltip: bar.tooltip
    Accessible.name: "Notifications" + (dnd ? ", do not disturb" : "") + (count ? ", " + count + " waiting" : "")
    onClicked: ShellState.toggle("notifications", bar.outputName)
    Rectangle {
        visible: bell.count > 0
        z: 2
        x: parent.width - width - 4
        y: 1
        width: Math.max(14, badge.implicitWidth + 6)
        height: 14
        radius: 7
        color: Theme.accent
        C.Label {
            id: badge
            anchors.centerIn: parent
            text: bell.count > 99 ? "99+" : String(bell.count)
            color: Theme.accentInk
            font.pixelSize: 10
            font.weight: Font.Bold
            font.features: ({"tnum": 1})
            elide: Text.ElideNone
        }
    }
}
