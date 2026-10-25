import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../core"
// Qualified: QtQuick.Controls has its own Label, which would ignore the shell font and text size.
import "." as C

// Secondary keys by default; accent is the primary action (accent fill, dark ink), danger is destructive (danger
// edge, wash and text), selected is "on" (accent wash, accent edge and text), flat has no key until hovered.
AbstractButton {
    id: root
    property string glyph: ""
    property string hint: ""
    // A Tooltip that shows `hint` while the pointer rests here; for icon-only controls outside panels.
    property var tooltip: null
    property bool selected: false
    property bool danger: false
    property bool flat: false
    property bool accent: false
    // Optional status tint for the label: "warning" or "danger".
    property string tone: ""
    property int labelSize: Theme.label
    property real cornerRadius: height > 40 ? Theme.radiusCard : Theme.radiusKey
    readonly property bool iconOnly: text === "" && glyph !== ""
    // Label and glyph share one colour so state reads the same on both. Controls built on Button may set their own.
    property color foreground: !enabled ? Theme.textFaint : danger || tone === "danger" ? Theme.dangerText : tone === "warning" ? Theme.warning : accent ? Theme.accentInk : selected ? Theme.accentText : Theme.text
    // Hover and press tints for keys without a fill of their own; translucent so they work on any surface.
    readonly property color wash: Qt.rgba(1, 1, 1, down ? 0.1 : 0.06)
    implicitWidth: iconOnly ? Math.max(implicitHeight, contentItem.implicitWidth + leftPadding + rightPadding)
                            : Math.max(28, contentItem.implicitWidth + leftPadding + rightPadding)
    implicitHeight: Theme.controlHeight
    Layout.minimumWidth: 0
    padding: iconOnly ? 8 : height > 32 ? 16 : 12
    topPadding: 4
    bottomPadding: 4
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: text || hint
    Accessible.role: Accessible.Button
    onHoveredChanged: if (tooltip) hovered ? tooltip.show(root) : tooltip.hide(root, false)
    onPressedChanged: if (tooltip && pressed) tooltip.hide(root, true)
    scale: down && !Theme.reduced ? Theme.pressScale : 1
    Behavior on scale {
        NumberAnimation {
            duration: Theme.press
            easing.type: Easing.OutCubic
        }
    }
    background: Rectangle {
        readonly property bool lit: root.hovered || root.down || root.visualFocus
        radius: root.cornerRadius
        color: !root.enabled ? (root.flat ? "transparent" : Theme.module)
             : root.accent ? (lit ? Theme.accentHover : Theme.accent)
             : root.danger && !root.flat ? (lit ? Theme.dangerSoft : Theme.dangerWash)
             : root.danger ? (lit ? Theme.dangerWash : "transparent")
             : root.selected ? Theme.accentSoft
             : root.flat ? (lit ? root.wash : "transparent")
             : lit ? Theme.keyHover : Theme.key
        border.width: root.enabled && !root.flat && (root.selected && !root.accent || root.danger) ? 1 : 0
        border.color: root.danger ? Theme.dangerLine : Theme.accentLine
        Behavior on color {
            ColorAnimation {
                duration: Theme.fast
            }
        }
        // The "on" wash stays translucent; hovering it lays a light wash on top instead of swapping colours.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: root.enabled && root.selected && !root.accent && !root.danger
            color: root.wash
            opacity: parent.lit ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.fast
                }
            }
        }
    }
    // Keyboard focus only (visualFocus is false for mouse clicks), so there are still no click outlines.
    Rectangle {
        anchors.fill: parent
        z: 10
        visible: root.visualFocus
        color: "transparent"
        radius: root.background && root.background.radius !== undefined ? root.background.radius : root.cornerRadius
        border.width: 2
        border.color: root.accent ? Theme.accentInk : Theme.text
        opacity: 0.85
    }
    contentItem: Item {
        implicitWidth: contents.implicitWidth
        implicitHeight: contents.implicitHeight
        RowLayout {
            id: contents
            anchors.centerIn: parent
            width: Math.min(parent.width, implicitWidth)
            spacing: Theme.gapS
            C.Icon {
                visible: root.glyph !== ""
                name: root.glyph
                color: root.foreground
                Layout.alignment: Qt.AlignVCenter
            }
            C.Label {
                visible: root.text !== ""
                text: root.text
                font.pixelSize: root.labelSize
                font.weight: root.accent ? 650 : Font.DemiBold
                color: root.foreground
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
    }
}
