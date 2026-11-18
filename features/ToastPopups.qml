import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../core"
import "../services"
import "../components" as C

// Notification toasts: the Notifications card, stacked up from the bottom right corner, newest lowest.
PanelWindow {
    id: popups
    // Whether this window's screen is the one toasts show on now.
    property bool target: false
    // Transparent room around the cards for their shadow; the mask keeps it from taking clicks.
    readonly property int room: 32
    anchors {
        bottom: true
        right: true
    }
    implicitWidth: Math.min(360, screen.width - 48) + room + 24
    implicitHeight: Math.max(1, Math.min(screen.height - ShellState.barBottom - 96, popupList.contentHeight)) + room + 24
    property int retiring: 0
    readonly property bool wanted: popups.target && !ShellState.locked && (Services.popupModel.count > 0 || retiring > 0) && ShellState.panel !== "notifications"
    // Applied after the change settles: mapping the window as the session unlocks updates the focused
    // output (and so `target`) while `visible` is still being set, which Qt reports as a binding loop.
    visible: false
    onWantedChanged: Qt.callLater(() => popups.visible = popups.wanted)
    Component.onCompleted: visible = wanted
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "shale-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region {
        item: popupList
    }
    C.FrostSource {
        id: frostSource
        screenName: popups.screen ? popups.screen.name : ""
        screenSize: popups.screen ? Qt.size(popups.screen.width, popups.screen.height) : Qt.size(1920, 1080)
    }
    ListView {
        id: popupList
        x: popups.room
        y: popups.room
        width: parent.width - popups.room - 24
        height: parent.height - popups.room - 24
        spacing: 10
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        model: Services.popupModel
        delegate: Item {
            id: popupItem
            required property var notificationData
            width: popupList.width
            height: popupCard.implicitHeight
            ListView.onRemove: {
                popups.retiring++;
                removal.start();
            }
            SequentialAnimation {
                id: removal
                PropertyAction { target: popupItem; property: "ListView.delayRemove"; value: true }
                NumberAnimation { target: popupItem; property: "opacity"; to: 0; duration: Theme.leave }
                ScriptAction { script: popups.retiring-- }
                PropertyAction { target: popupItem; property: "ListView.delayRemove"; value: false }
            }
            RectangularShadow {
                anchors.fill: popupCard
                visible: !Theme.lowPower
                radius: popupCard.radius
                blur: 32
                offset.y: 14
                color: Qt.rgba(0, 0, 0, 0.45)
            }
            // With glass, the card's case: the window sits in the screen's bottom right corner.
            C.Frost {
                anchors.fill: popupCard
                visible: Theme.glass
                source: frostSource
                radius: popupCard.radius
                rim: 14
                area: Qt.rect((popups.screen ? popups.screen.width : 0) - popups.width + popupList.x + popupItem.x,
                              (popups.screen ? popups.screen.height : 0) - popups.height + popupList.y + popupItem.y - popupList.contentY,
                              width, height)
            }
            NotificationCard {
                id: popupCard
                notification: popupItem.notificationData
                popup: true
                width: parent.width
                height: implicitHeight
            }
        }
        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.panelEnter }
                NumberAnimation {
                    property: "x"
                    from: Theme.reduced ? 0 : 24
                    to: 0
                    duration: Theme.reduced ? 0 : Theme.lowPower ? 120 : 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.easeOut
                }
            }
        }
        displaced: Transition {
            NumberAnimation { property: "y"; duration: Theme.reduced ? 0 : Theme.enter; easing.type: Easing.OutCubic }
        }
    }
}
