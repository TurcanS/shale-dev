import QtQuick
import "../core"

// The 40×22 switch on its own, for module headers: a key-coloured track that turns accent, with a light knob that
// slides across. Name it with `hint`.
Button {
    id: root
    implicitWidth: 40
    implicitHeight: 22
    padding: 0
    cornerRadius: 11
    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: selected
    background: Rectangle {
        radius: 11
        color: root.selected ? Theme.accent : root.hovered || root.visualFocus || root.down ? Theme.keyHover : Theme.key
        opacity: root.enabled ? 1 : Theme.disabledOpacity
        Behavior on color {
            ColorAnimation {
                duration: Theme.slide
            }
        }
        Rectangle {
            x: root.selected ? 21 : 3
            y: 3
            width: 16
            height: 16
            radius: 8
            color: Theme.knob
            Behavior on x {
                NumberAnimation {
                    duration: Theme.slide
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.easeOut
                }
            }
        }
    }
    contentItem: Item {}
}
