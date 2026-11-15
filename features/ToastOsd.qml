import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../core"
import "../services"
import "../components" as C

// Levels (volume, brightness) as a round pill with a slim bar and the value; everything else (microphone,
// keyboard layout, Do not disturb, countdowns) as a small card with a title and what it is about.
PanelWindow {
    id: osdWindow
    // Whether this window's screen is the one toasts show on now.
    property bool target: false
    readonly property bool level: ShellState.osdValue >= 0
    readonly property bool volume: ShellState.osdGlyph === "volume" || ShellState.osdGlyph === "mute"
    // "Muted · Microphone" → Muted over Microphone; the older one-line labels get the same shape.
    readonly property var card: {
        const label = ShellState.osdLabel;
        const dnd = /^Do not disturb (on|off)$/.exec(label);
        if (dnd)
            return {title: dnd[1] === "on" ? "On" : "Off", subtitle: "Do not disturb"};
        const countdown = /^Screenshot in (\d+)$/.exec(label);
        if (countdown)
            return {title: "In " + countdown[1], subtitle: "Screenshot"};
        const parts = label.split(" · ");
        return {title: parts[0], subtitle: parts.slice(1).join(" · ")};
    }
    // Something switched on (Do not disturb): a light tile with dark ink.
    readonly property bool lit: ShellState.osdGlyph === "bell-off"
    // Transparent room for the shadow; nothing here takes clicks.
    readonly property int room: 40
    property real reveal: osdWindow.target && ShellState.osdVisible && !ShellState.locked ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
    anchors {
        bottom: true
    }
    margins.bottom: (ShellState.toast !== "" ? 92 : 64) - room
    implicitWidth: (level ? 320 : 196) + 2 * room
    implicitHeight: (level ? 56 : 124) + 2 * room
    visible: osdWindow.target && !ShellState.locked && reveal > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "shale-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    // Nothing here is clickable, so clicks reach the windows underneath.
    mask: Region {}
    Item {
        id: osd
        anchors.fill: parent
        anchors.margins: osdWindow.room
        opacity: osdWindow.reveal
        transform: [
            Scale {
                origin.x: osd.width / 2
                origin.y: osd.height / 2
                xScale: Theme.reduced ? 1 : 0.94 + 0.06 * osdWindow.reveal
                yScale: xScale
            },
            Translate { y: Theme.reduced ? 0 : (1 - osdWindow.reveal) * 6 }
        ]
        RectangularShadow {
            anchors.fill: osdCase
            visible: !Theme.lowPower
            radius: osdCase.radius
            blur: 30
            offset.y: 14
            color: Qt.rgba(0, 0, 0, 0.45)
        }
        Rectangle {
            id: osdCase
            anchors.fill: parent
            radius: osdWindow.level ? height / 2 : 24
            color: Theme.tint(Theme.module, 0.92)
            border.width: 1
            border.color: Theme.cardEdge
        }
        // The level pill: icon disc, slim bar, value.
        RowLayout {
            visible: osdWindow.level
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 16
            spacing: Theme.gapM
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: ShellState.osdMuted ? Theme.dangerSoft : osdWindow.volume ? Theme.tint(Theme.accent, 0.16) : Theme.key
                Behavior on color { ColorAnimation { duration: Theme.fast } }
                C.Icon {
                    id: osdIcon
                    anchors.centerIn: parent
                    name: ShellState.osdGlyph
                    color: ShellState.osdMuted ? Theme.dangerText : osdWindow.volume ? Theme.accent : Theme.text
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 3
                color: Theme.key
                RectangularShadow {
                    anchors.fill: levelFill
                    visible: osdWindow.volume && !ShellState.osdMuted && !Theme.lowPower && levelFill.width > 0
                    radius: levelFill.radius
                    blur: 12
                    color: Theme.accentGlow
                }
                Rectangle {
                    id: levelFill
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * Math.max(0, Math.min(1, ShellState.osdValue))
                    radius: 3
                    // Volume runs from the accent wash to the accent; brightness is light; muted keeps the real
                    // level visible, just quieter.
                    color: ShellState.osdMuted ? Theme.textFaint : Theme.text
                    gradient: osdWindow.volume && !ShellState.osdMuted ? volumeGradient : undefined
                    Behavior on width { NumberAnimation { duration: Theme.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
                    Gradient {
                        id: volumeGradient
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.tint(Theme.accent, 0.16) }
                        GradientStop { position: 1; color: Theme.accent }
                    }
                }
            }
            C.Label {
                text: Math.round(ShellState.osdValue * 100)
                color: ShellState.osdMuted ? Theme.textDim : Theme.text
                font.pixelSize: 14
                font.weight: 650
                font.features: ({"tnum": 1})
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 30
            }
        }
        // The card: tile, then the title and what it is about at the bottom.
        ColumnLayout {
            visible: !osdWindow.level
            anchors.fill: parent
            anchors.margins: 16
            spacing: 6
            Rectangle {
                id: cardTile
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 13
                color: ShellState.osdMuted ? Theme.dangerSoft : osdWindow.lit ? Theme.mix(Theme.knob, Theme.textSecondary, 0.35) : Theme.key
                C.Icon {
                    id: cardIcon
                    anchors.centerIn: parent
                    name: ShellState.osdGlyph
                    color: ShellState.osdMuted ? Theme.dangerText : osdWindow.lit ? Theme.accentInk : Theme.text
                }
            }
            Item {
                Layout.fillHeight: true
            }
            C.Label {
                text: osdWindow.card.title
                font.pixelSize: 16
                font.weight: 650
                Layout.fillWidth: true
            }
            C.Label {
                visible: text !== ""
                text: osdWindow.card.subtitle
                color: Theme.textDim
                font.pixelSize: 12
                Layout.fillWidth: true
            }
        }
        // A small bump on every change confirms the key press even at 0% or 100%.
        SequentialAnimation {
            id: bump
            property Item icon: osdWindow.level ? osdIcon : cardIcon
            NumberAnimation { target: bump.icon; property: "scale"; to: 1.2; duration: 70; easing.type: Easing.OutQuad }
            NumberAnimation { target: bump.icon; property: "scale"; to: 1; duration: 160; easing.type: Easing.OutBack }
        }
        Connections {
            target: ShellState
            function onOsdSerialChanged() {
                if (!Theme.reduced && !Theme.lowPower && osdWindow.reveal > 0)
                    bump.restart();
            }
        }
    }
}
