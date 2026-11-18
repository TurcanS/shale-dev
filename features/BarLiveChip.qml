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

// Something live or on (listening, recording, a focus session): a round accentSoft chip with accent text. When it
// appears its wash breathes three times, so it reads as happening now, then rests (a long call doesn't keep the bar
// drawing).
BarKey {
    id: chip
    property real breath: 0
    implicitHeight: 24
    cornerRadius: 12
    rest: Theme.tint(Theme.accent, 0.14 + 0.1 * breath)
    onVisibleChanged: if (visible)
        breathing.restart()
    Component.onCompleted: if (visible)
        breathing.restart()
    SequentialAnimation {
        id: breathing
        loops: 3
        running: false
        NumberAnimation { target: chip; property: "breath"; to: 1; duration: Theme.lively && !Theme.lowPower ? Theme.ms(900) : 0; easing.type: Easing.InOutSine }
        NumberAnimation { target: chip; property: "breath"; to: 0; duration: Theme.lively && !Theme.lowPower ? Theme.ms(1100) : 0; easing.type: Easing.InOutSine }
    }
    leftPadding: 10
    rightPadding: 10
    foreground: Theme.accentText
}
