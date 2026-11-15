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

BarStatusPart {
    // The bar this item is on: its screen, layout, weather and helpers.
    required property var bar
    shown: !!ShellState.activeVpn
    glyph: "shield"
    foreground: Theme.accentText
    hint: ShellState.activeVpn ? "VPN · " + ShellState.activeVpn.name : ""
    tooltip: bar.tooltip
    selected: bar.controlActive("wifi")
    onClicked: bar.toggleControl("wifi")
}
