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

// A key on the bar, 28 px tall. Flat keys show a light wash on hover; the status key rests on
// `module`. A key whose panel is open on this screen turns keySelected.
C.Button {
    id: key
    // Whether the item has something to show; the zone hides its slot otherwise.
    property bool shown: true
    property color rest: "transparent"
    labelSize: 13
    implicitHeight: 28
    topPadding: 0
    bottomPadding: 0
    cornerRadius: Theme.radiusKey
    foreground: !enabled ? Theme.textFaint : tone === "danger" ? Theme.dangerText : tone === "warning" ? Theme.warning : Theme.text
    background: Rectangle {
        radius: key.cornerRadius
        color: key.selected ? Theme.keySelected : key.rest
        Behavior on color {
            ColorAnimation {
                duration: Theme.fast
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: key.wash
            opacity: key.hovered || key.down || key.visualFocus ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.fast
                }
            }
        }
    }
}
