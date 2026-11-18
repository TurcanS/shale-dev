import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Pipewire
import "../core"
import "../core/barItems.js" as BarItems
import "../services"
import "../components" as C

BarKey {
    id: bell
    // The bar this item is on: its screen, layout, weather and helpers.
    required property var bar
    readonly property int count: Services.notifications.length
    readonly property bool dnd: ShellState.setting("dnd", false) || ShellState.quietNow
    implicitWidth: 32
    // Do not disturb swaps the bell so suppressed popups are never a surprise.
    glyph: dnd ? "bell-off" : "bell"
    selected: ShellState.panel === "notifications" && ShellState.screenName === bar.outputName
    hint: "Notifications"
    tooltip: bar.tooltip
    Accessible.name: "Notifications" + (dnd ? ", do not disturb" : "") + (count ? ", " + count + " waiting" : "")
    onClicked: ShellState.toggle("notifications", bar.outputName)
    // The count the badge shows; it keeps the last one while the badge shrinks away.
    property int shownCount: 0
    property int lastCount: 0
    onCountChanged: {
        if (count > 0)
            shownCount = count;
        // Something new: the badge swells and a ring spreads from the bell, once.
        if (count > lastCount && lastCount >= 0) {
            badgePop.bump();
            if (Theme.lively && !Theme.lowPower)
                ringSpread.restart();
        }
        lastCount = count;
    }
    Component.onCompleted: {
        shownCount = count;
        lastCount = count;
    }
    Rectangle {
        id: ring
        property real spread: 1
        anchors.centerIn: parent
        width: 18 + 18 * spread
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1.5
        border.color: Theme.accent
        opacity: 0.55 * (1 - spread)
        visible: spread < 1
        NumberAnimation {
            id: ringSpread
            target: ring
            property: "spread"
            from: 0
            to: 1
            duration: Theme.ms(650)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeOut
        }
    }
    C.Pop {
        id: badgePop
        shown: bell.count > 0
        z: 2
        x: parent.width - width - 4
        y: 1
        width: Math.max(14, badge.implicitWidth + 6)
        height: 14
        Rectangle {
            radius: 7
            color: Theme.accent
            C.RollNumber {
                id: badge
                anchors.centerIn: parent
                text: bell.shownCount > 99 ? "99+" : String(bell.shownCount)
                color: Theme.accentInk
                font: Qt.font({family: Theme.font, pixelSize: 10, weight: Font.Bold})
            }
        }
    }
}
