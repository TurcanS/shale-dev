import QtQuick
import QtQuick.Controls
import "../core"

TextField {
    id: root
    color: enabled ? Theme.text : Theme.textFaint
    placeholderTextColor: Theme.textFaint
    font.family: Theme.font
    font.pixelSize: Theme.body
    selectionColor: Theme.accentLine
    selectedTextColor: Theme.text
    implicitHeight: Theme.controlLarge
    leftPadding: Theme.gapM
    rightPadding: Theme.gapM
    selectByMouse: true
    verticalAlignment: TextInput.AlignVCenter
    Accessible.name: placeholderText
    // A module-coloured key; focus lights its edge with the accent.
    background: Rectangle {
        radius: Theme.radiusKey
        color: root.hovered && !root.activeFocus ? Theme.mix(Theme.module, Theme.text, 0.04) : Theme.module
        border.width: 1
        border.color: root.activeFocus ? Theme.accentLine : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: Theme.fast
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: Theme.fast
            }
        }
    }
}
