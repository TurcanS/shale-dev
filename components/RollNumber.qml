pragma ComponentBehavior: Bound
import QtQuick
import "../core"

// A number whose digits roll to their new value, each column on its own like a counter, with a fixed width per
// digit so the figures don't shift: forward when the number grows (9 rolls on to 0), back when it shrinks. Anything
// that isn't a digit (%, :, a unit) is drawn as it is. A column added in front fades in; the others keep rolling
// from where they are. Calm motion swaps at once.
Item {
    id: root
    property string text: ""
    property color color: Theme.text
    property font font: Qt.font({family: Theme.font, pixelSize: Theme.body})
    readonly property bool animated: Theme.lively && Theme.fast > 0
    implicitWidth: row.implicitWidth
    implicitHeight: metrics.height
    Accessible.role: Accessible.StaticText
    Accessible.name: text
    // One entry per character, counted from the right, so a digit added in front leaves the others in place.
    ListModel {
        id: columns
    }
    // Whether the latest change made the number larger, so the columns roll forward.
    property bool rising: true
    property real lastValue: NaN
    function sync() {
        const value = parseFloat(text.replace(/[^0-9.-]/g, ""));
        rising = isNaN(value) || isNaN(lastValue) || value >= lastValue;
        lastValue = value;
        const count = text.length;
        for (let place = 0; place < count; place++) {
            const glyph = text.charAt(count - 1 - place);
            if (place < columns.count)
                columns.setProperty(place, "glyph", glyph);
            else
                columns.append({glyph: glyph});
        }
        if (columns.count > count)
            columns.remove(count, columns.count - count);
    }
    onTextChanged: sync()
    Component.onCompleted: sync()
    FontMetrics {
        id: metrics
        font: root.font
        // The widest digit, so every column has room for any of them.
        readonly property real digitWidth: Math.ceil(Math.max(...[0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map(digit => advanceWidth(String(digit)))))
    }
    Row {
        id: row
        layoutDirection: Qt.RightToLeft
        Repeater {
            model: columns
            Item {
                id: column
                required property string glyph
                readonly property bool digit: glyph >= "0" && glyph <= "9"
                width: digit ? metrics.digitWidth : other.implicitWidth
                height: metrics.height
                clip: digit
                opacity: 0
                Behavior on opacity {
                    enabled: root.animated
                    NumberAnimation {
                        duration: Theme.enter
                    }
                }
                // Where the column is, in digits: it only ever moves forward or back, so 9 to 0 is one step. Two
                // figures are drawn, the one at the whole part and the next, sliding by the fraction.
                property real goal: digit ? Number(glyph) : 0
                property real at: goal
                property bool settled: false
                Component.onCompleted: {
                    opacity = 1;
                    settled = true;
                }
                onGlyphChanged: {
                    if (!digit)
                        return;
                    const current = ((Math.round(goal) % 10) + 10) % 10;
                    let step = (Number(glyph) - current + 10) % 10;
                    if (!root.rising && step !== 0)
                        step -= 10;
                    goal += step;
                }
                Behavior on at {
                    enabled: root.animated && column.settled
                    NumberAnimation {
                        duration: Theme.ms(320)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.easeOut
                    }
                }
                readonly property int whole: Math.floor(at + 0.0001)
                readonly property real fraction: at - whole
                Repeater {
                    model: column.digit ? 2 : 0
                    Text {
                        required property int index
                        text: String((((column.whole + index) % 10) + 10) % 10)
                        y: (index - column.fraction) * metrics.height
                        // A figure fades as it leaves the middle, so two half figures never read as one.
                        opacity: Math.max(0, 1 - Math.abs(index - column.fraction) * 1.6)
                        width: metrics.digitWidth
                        height: metrics.height
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font: root.font
                        color: root.color
                    }
                }
                Text {
                    id: other
                    visible: !column.digit
                    text: column.digit ? "" : column.glyph
                    height: metrics.height
                    verticalAlignment: Text.AlignVCenter
                    font: root.font
                    color: root.color
                }
            }
        }
    }
}
