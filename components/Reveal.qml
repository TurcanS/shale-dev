import QtQuick
import "../core"

// Brings one item in: a fade, a short rise and a slight grow. Items of a group come one after another by `order`
// (Theme.stagger per step, for at most Theme.staggerMax steps), and nothing waits for them: they take the pointer
// at once. Put a single item inside; it is made to fill the Reveal, which keeps the item's place in a layout while
// it moves. `shown` false takes it out again, and `collapse` then hides it so a layout closes the gap. replay()
// runs the entrance once more.
Item {
    id: root
    property bool shown: true
    property int order: 0
    property real rise: 6
    property real fromScale: 0.98
    property bool collapse: false
    // A multiplier on the scale for a short emphasis (Pop's bump).
    property real boost: 1
    default property alias content: holder.data
    readonly property Item item: holder.children.length > 0 ? holder.children[0] : null
    property bool started: false
    property bool instant: false
    property real progress: shown && started ? 1 : 0
    implicitWidth: item ? item.implicitWidth : 0
    implicitHeight: item ? item.implicitHeight : 0
    visible: !collapse || shown || progress > 0
    function replay() {
        instant = true;
        started = false;
        instant = false;
        wait.restart();
    }
    onItemChanged: {
        if (item)
            item.anchors.fill = holder;
    }
    Behavior on progress {
        enabled: !root.instant
        NumberAnimation {
            duration: root.shown ? Theme.reveal : Theme.leave
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeOut
        }
    }
    Timer {
        id: wait
        interval: Math.min(root.order, Theme.staggerMax) * Theme.stagger
        onTriggered: root.started = true
    }
    Component.onCompleted: wait.start()
    Item {
        id: holder
        anchors.fill: parent
        opacity: root.progress
        readonly property real grow: Theme.reduced ? 1 : root.fromScale + (1 - root.fromScale) * root.progress
        transform: [
            Scale {
                origin.x: holder.width / 2
                origin.y: holder.height / 2
                xScale: holder.grow * root.boost
                yScale: holder.grow * root.boost
            },
            Translate {
                y: Theme.reduced ? 0 : (1 - root.progress) * root.rise
            }
        ]
    }
}
