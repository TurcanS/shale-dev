import QtQuick
import QtQuick.Controls
import "../core"
import "../components" as C

// M and S on a channel strip.
C.Button {
    id: stripKey
    property color onColor: Theme.accentSoft
    property color onText: Theme.accentText
    implicitWidth: 26
    implicitHeight: 22
    padding: 0
    labelSize: 11
    cornerRadius: 6
    foreground: selected ? onText : Theme.textMuted
    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: selected
    background: Rectangle {
        radius: stripKey.cornerRadius
        color: stripKey.selected ? stripKey.onColor : stripKey.hovered || stripKey.down || stripKey.visualFocus ? Theme.keyHover : Theme.keyTile
        Behavior on color {
            ColorAnimation {
                duration: Theme.fast
            }
        }
    }
}
