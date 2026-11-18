import QtQuick
import "../core"

// A soft light that follows the pointer across a card, tinted with the accent and added to the card's colour. It
// fades in while the pointer is over the card and out when it leaves, staying where the pointer left. Put it first
// inside the card, under the card's content, and give it the card's corner radius; it never takes clicks. Off with
// calm motion and trimmed effects. Drawn by assets/shaders/pointerlight.frag.
Item {
    id: root
    property real radius: Theme.radiusModule
    property color color: Theme.accent
    property real strength: 0.10
    // How far the light spreads: most of a small card, a pool on a large one.
    property real reach: Math.min(260, Math.max(120, Math.max(width, height) * 0.8))
    readonly property bool live: Theme.lively && !Theme.lowPower && enabled
    property point at: Qt.point(width / 2, height / 2)
    property real glow: hover.hovered ? 1 : 0
    anchors.fill: parent
    Behavior on glow {
        NumberAnimation {
            duration: root.glow < 0.5 ? Theme.enter : Theme.ms(420)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeOut
        }
    }
    HoverHandler {
        id: hover
        enabled: root.live
        onPointChanged: if (hovered)
            root.at = point.position
    }
    ShaderEffect {
        anchors.fill: parent
        visible: root.live && root.glow > 0
        opacity: root.glow
        property size box: Qt.size(width, height)
        property point spot: root.at
        property real corner: root.radius
        property real spread: root.reach
        property color tint: Theme.tint(root.color, root.strength)
        fragmentShader: "../assets/shaders/pointerlight.frag.qsb"
    }
}
