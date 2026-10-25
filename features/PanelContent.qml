import QtQuick
import QtQuick.Layouts
import "../core"
import "../components" as C

// The panel case. The page decides its size and header: title, headerNote (a short status beside the title;
// a page with noteClicked() makes it a button), panelWidth, panelHeight, showHeader, chromeless, canGoBack/back()
// and headerTools (a Component shown beside the close button).
Rectangle {
    id: root
    property string panel: "launcher"
    property bool active: true
    // True while the host itself fades the case in; the page then skips its own entrance.
    property bool entering: false
    readonly property var pageItem: loader.item
    function page(name, fallback) {
        return pageItem && pageItem[name] !== undefined && pageItem[name] !== null ? pageItem[name] : fallback;
    }
    readonly property bool chromeless: page("chromeless", false)
    readonly property bool canGoBack: page("canGoBack", false)
    objectName: "panel-" + panel
    readonly property int preferredWidth: page("panelWidth", 580)
    readonly property int preferredHeight: page("panelHeight", 520)
    color: chromeless ? "transparent" : Theme.caseColor
    radius: Theme.radiusCase
    // A hairline edge keeps the case apart from dark wallpapers.
    border.width: chromeless ? 0 : 1
    border.color: Theme.hairline
    clip: true
    // Consume pointer presses inside the surface instead of dismissing its backdrop.
    MouseArea {
        anchors.fill: parent
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.chromeless ? 0 : Theme.casePadding
        spacing: 10
        // Title 17/650, a short status in textDim, then the page's tools and close.
        RowLayout {
            visible: !root.chromeless && root.page("showHeader", true)
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 10
            C.Button {
                visible: root.canGoBack
                glyph: "back"
                flat: true
                hint: "Back"
                implicitWidth: 32
                implicitHeight: 32
                onClicked: root.pageItem.back()
            }
            C.Label {
                text: root.page("title", "Shale")
                font.pixelSize: 17
                font.weight: 650
                elide: Text.ElideNone
                Layout.leftMargin: root.canGoBack ? -2 : 2
                Layout.preferredHeight: 32
            }
            C.Label {
                readonly property string note: root.page("headerNote", "")
                visible: note !== "" && typeof root.page("noteClicked", null) !== "function"
                text: note
                color: Theme.textDim
                font.pixelSize: 13
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }
            C.Button {
                id: noteButton
                visible: root.page("headerNote", "") !== "" && typeof root.page("noteClicked", null) === "function"
                text: root.page("headerNote", "")
                hint: root.page("noteHint", "")
                flat: true
                labelSize: 13
                foreground: hovered || visualFocus ? Theme.textSecondary : Theme.textDim
                implicitHeight: 28
                leftPadding: 6
                rightPadding: 6
                Layout.leftMargin: -6
                Layout.minimumWidth: 0
                onClicked: root.pageItem.noteClicked()
            }
            Item {
                visible: root.page("headerNote", "") === "" || noteButton.visible
                Layout.fillWidth: true
            }
            Loader {
                sourceComponent: root.page("headerTools", null)
                visible: !!item
            }
            C.Button {
                glyph: "close"
                implicitWidth: 32
                implicitHeight: 32
                flat: true
                hint: "Close · Escape"
                onClicked: ShellState.close()
            }
        }
        Loader {
            id: loader
            property real entrance: 1
            opacity: entrance
            // Switching pages in an open case: the new page rises and fades in like the case itself.
            transform: Translate {
                y: (1 - loader.entrance) * Theme.panelRise
            }
            NumberAnimation {
                id: pageEntrance
                target: loader
                property: "entrance"
                from: 0
                to: 1
                duration: Theme.panelEnter
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easeOut
            }
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: root.active
            source: ({
                    launcher: "Launcher.qml",
                    clipboard: "Clipboard.qml",
                    control: "ControlCenter.qml",
                    notifications: "Notifications.qml",
                    calendar: "Calendar.qml",
                    overview: "Overview.qml",
                    capture: "Capture.qml",
                    settings: "Settings.qml",
                    power: "Power.qml",
                    wallpaper: "Wallpaper.qml",
                    activity: "Activity.qml",
                    system: "System.qml"
                })[root.panel] || "Launcher.qml"
            onLoaded: {
                if (root.entering) {
                    pageEntrance.stop();
                    entrance = 1;
                } else {
                    pageEntrance.restart();
                }
                const loaded = item as Item;
                if (loaded)
                    loaded.forceActiveFocus();
            }
        }
    }
    Keys.onEscapePressed: {
        if (canGoBack)
            pageItem.back();
        else
            ShellState.close();
    }
}
