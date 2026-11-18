import QtQuick
import "../core"
import "." as C

// A glass case (assets/shaders/glass.frag): the wallpaper through a quiet fluted body, a bevelled rim lit by the
// wallpaper's colour past the edge, and, with lively motion, a sheen and a brighter edge where the pointer is. It
// needs a FrostSource in the same window and `area`: where it lies on the screen, in pixels, as drawn. Until the
// picture is ready, a plain case in `color` with a hairline edge. `ring` draws a coloured edge over the glass
// (urgent, error, asking). The bar and small cards turn the bevel, edge light, sheen and reeds down.
Item {
    id: root
    property C.FrostSource source: null
    property rect area: Qt.rect(0, 0, width, height)
    property real radius: Theme.radiusCase
    property color color: Theme.caseColor
    property color ring: "transparent"
    property real rim: 18
    property real edgeGlow: 1
    property real sheen: 1
    property real reeds: 1
    readonly property bool frosted: !!source && source.ready
    // Where the pointer is on the glass, kept where it left so the light fades out in place.
    property point pointer: Qt.point(width / 2, height / 2)
    property real glow: hover.hovered && Theme.lively && !Theme.lowPower ? 1 : 0
    Behavior on glow {
        NumberAnimation {
            duration: root.glow < 0.5 ? Theme.enter : Theme.ms(520)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeOut
        }
    }
    // Lets the pointer through to whatever lies over the glass.
    HoverHandler {
        id: hover
        enabled: root.frosted && Theme.lively
        onPointChanged: if (hovered)
            root.pointer = point.position
    }
    Rectangle {
        anchors.fill: parent
        visible: !root.frosted
        radius: root.radius
        color: root.color
        border.width: 1
        border.color: root.ring.a > 0 ? root.ring : Theme.hairline
    }
    ShaderEffect {
        anchors.fill: parent
        visible: root.frosted
        property var soft: root.source ? root.source.soft : null
        property var frosted: root.source ? root.source.frosted : null
        property size box: Qt.size(width, height)
        property rect area: root.source ? Qt.rect(root.area.x / root.source.screenSize.width, root.area.y / root.source.screenSize.height,
                                                  root.area.width / root.source.screenSize.width, root.area.height / root.source.screenSize.height)
                                        : Qt.rect(0, 0, 1, 1)
        property real corner: root.radius
        property color tint: Theme.glassTint
        property real cover: Theme.glassCover
        property color accent: Theme.accent
        property real vibrance: Theme.glassVibrance
        property real ceiling: Theme.glassCeiling
        property point pointer: root.pointer
        property real glow: root.glow
        property real rim: root.rim
        property real edgeGlow: root.edgeGlow
        property real sheen: root.sheen
        property real reeds: root.reeds
        fragmentShader: "../assets/shaders/glass.frag.qsb"
    }
    Rectangle {
        anchors.fill: parent
        visible: root.frosted && root.ring.a > 0
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: root.ring
    }
}
