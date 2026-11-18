import QtQuick
import "../core"
import "." as C

// A badge, dot or chip that pops into place: it grows from 0.85 while fading in and shrinks away when `shown` goes
// false, and the layout closes the gap behind it. bump() gives it a short swell, for a count that changed.
C.Reveal {
    id: root
    rise: 0
    fromScale: 0.85
    collapse: true
    function bump() {
        if (Theme.lively && !Theme.lowPower && shown)
            swell.restart();
    }
    SequentialAnimation {
        id: swell
        NumberAnimation {
            target: root
            property: "boost"
            to: 1.14
            duration: Theme.ms(90)
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "boost"
            to: 1
            duration: Theme.ms(200)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeOut
        }
    }
}
