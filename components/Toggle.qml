import QtQuick
import QtQuick.Layouts
import "../core"

Button {
    id: root
    // Optional second line explaining what the switch does or its current state.
    property string description: ""
    // With a glyph the row becomes a header-style toggle (Wi-Fi, Bluetooth); positive adds a status dot.
    property bool positive: false
    // Flat inside a Group: no card of its own, only a hover highlight.
    implicitHeight: Math.max(glyph !== "" ? 60 : description !== "" ? 58 : Theme.controlLarge + 4, toggleContent.implicitHeight + topPadding + bottomPadding)
    padding: Theme.gapL
    leftPadding: glyph !== "" ? Theme.gapM : Theme.gapL
    topPadding: Theme.gapS + 2
    bottomPadding: Theme.gapS + 2
    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: selected
    Accessible.description: description
    // A whole row only gives a little under the pointer.
    scale: down && !Theme.reduced ? 0.99 : 1
    background: Rectangle {
        radius: root.flat ? Theme.radiusCard + 2 : Theme.radiusCard
        color: root.flat ? (root.hovered || root.visualFocus || root.down ? Qt.rgba(1, 1, 1, root.down ? 0.06 : 0.035) : "transparent")
             : root.hovered || root.visualFocus || root.down ? Theme.mix(Theme.module, Theme.text, 0.05) : Theme.module
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }
    contentItem: RowLayout {
        // Named: contentItem is created late, and a binding through it doesn't see later size changes.
        id: toggleContent
        spacing: Theme.gapL
        GlyphTile {
            visible: root.glyph !== ""
            size: 36
            glyph: root.glyph
            positive: root.positive
            selected: root.selected
            opacity: root.enabled ? 1 : Theme.disabledOpacity
            Layout.rightMargin: -Theme.gapXs
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label {
                text: root.text
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.weight: root.glyph !== "" ? Font.DemiBold : Font.Normal
                color: root.enabled ? Theme.text : Theme.textFaint
            }
            Label {
                visible: root.description !== ""
                text: root.description
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                // Header rows (with a glyph) keep status to one line; setting explanations may wrap.
                maximumLineCount: root.glyph !== "" ? 1 : 3
                elide: Text.ElideRight
                color: Theme.textDim
                font.pixelSize: Theme.small
            }
        }
        // The switch: a key-coloured track that turns accent, with a light knob that slides across.
        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 22
            radius: 11
            color: root.selected ? Theme.accent : root.hovered || root.visualFocus || root.down ? Theme.keyHover : Theme.key
            opacity: root.enabled ? 1 : Theme.disabledOpacity
            Behavior on color { ColorAnimation { duration: Theme.slide } }
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
    }
}
