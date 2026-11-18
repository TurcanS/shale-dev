import QtQuick
import "../core"
import "." as C

// A line of text that rolls when it changes: the old line slides up and fades while the new one rises into place,
// and the width eases to the new text, so the things beside it slide instead of jumping. For labels that change
// while you watch (the window title, the track). Give it `maximumWidth` to elide long text. Calm motion swaps at
// once; reduced motion cross-fades without moving.
Item {
    id: root
    property string text: ""
    property color color: Theme.text
    property alias font: current.font
    property real maximumWidth: -1
    // 1 rolls upward (something new), -1 downward (going back).
    property int direction: 1
    property real travel: 6
    readonly property bool animated: Theme.lively && Theme.fast > 0
    property real swap: 1
    readonly property real lineWidth: maximumWidth >= 0 ? Math.min(current.implicitWidth, maximumWidth) : current.implicitWidth
    property real shownWidth: lineWidth
    implicitWidth: shownWidth
    implicitHeight: current.implicitHeight
    clip: swap < 1 || shownWidth !== lineWidth
    Accessible.role: Accessible.StaticText
    Accessible.name: text
    Behavior on shownWidth {
        enabled: root.animated
        NumberAnimation {
            duration: Theme.enter
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeInOut
        }
    }
    onTextChanged: {
        if (!animated || current.text === "") {
            current.text = text;
            return;
        }
        previous.text = current.text;
        current.text = text;
        roll.restart();
    }
    Component.onCompleted: current.text = text
    NumberAnimation {
        id: roll
        target: root
        property: "swap"
        from: 0
        to: 1
        duration: Theme.ms(240)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easeOut
    }
    C.Label {
        id: previous
        visible: root.swap < 1
        width: root.maximumWidth >= 0 ? Math.min(implicitWidth, root.maximumWidth) : implicitWidth
        height: root.height
        font: current.font
        color: root.color
        // The old line is gone by half way and the new one starts a quarter in, so the two barely overlap.
        opacity: Math.max(0, 1 - root.swap * 2)
        y: Theme.reduced ? 0 : -root.swap * root.travel * root.direction
    }
    C.Label {
        id: current
        width: root.lineWidth
        height: root.height
        color: root.color
        opacity: Math.max(0, (root.swap - 0.25) / 0.75)
        y: Theme.reduced ? 0 : (1 - root.swap) * root.travel * root.direction
    }
}
