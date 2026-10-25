import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../core"

PanelWindow {
    id: host
    required property string outputName
    readonly property bool showing: ShellState.panel !== "" && ShellState.screenName === outputName && !ShellState.locked
    property string retainedPanel: "launcher"
    property real progress: showing ? 1 : 0
    // Settings → Appearance → Panel size. Every panel lays out at its own size and is drawn this much smaller or
    // larger, like a zoom; text and icons are vectors, so they stay sharp.
    readonly property real zoom: Theme.panelScale
    IpcHandler {
        target: "surface-" + host.outputName
        function status(): string {
            return JSON.stringify({
                panel: content.panel,
                visible: host.visible,
                content: content.objectName
            });
        }
    }
    function synchronizePanel() {
        if (showing)
            retainedPanel = ShellState.panel;
    }
    Connections {
        target: ShellState
        function onPanelChanged() {
            host.synchronizePanel();
        }
        function onScreenNameChanged() {
            host.synchronizePanel();
        }
    }
    onShowingChanged: {
        synchronizePanel();
    }
    visible: progress > 0 || showing
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "shale-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Every panel rises 8 px and fades in; leaving is quicker. Reduced motion is instant.
    Behavior on progress {
        NumberAnimation {
            duration: host.showing ? Theme.panelEnter : Theme.panelLeave
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easeOut
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.close()
    }
    // The case's long soft shadow; skipped when effects are trimmed.
    RectangularShadow {
        x: content.x
        y: content.y
        width: content.width * host.zoom
        height: content.height * host.zoom
        visible: !content.chromeless && !Theme.lowPower && host.visible
        radius: content.radius * host.zoom
        blur: Theme.caseShadow.blur
        offset.x: Theme.caseShadow.x
        offset.y: Theme.caseShadow.y
        color: Theme.caseShadow.color
        opacity: host.progress
        transform: Translate {
            y: (1 - host.progress) * Theme.panelRise
        }
    }
    PanelContent {
        id: content
        panel: host.retainedPanel
        width: Math.min((parent.width - 24) / host.zoom, preferredWidth)
        height: Math.min((parent.height - 90) / host.zoom, preferredHeight)
        scale: host.zoom
        transformOrigin: Item.TopLeft
        // Panels opened from the bar's right end line up with it, 8 px in from the screen edge.
        x: ["control", "notifications"].indexOf(panel) >= 0 ? parent.width - width * host.zoom - 8 : (parent.width - width * host.zoom) / 2
        y: (["control", "notifications", "calendar"].indexOf(panel) >= 0 ? ShellState.barBottom + 8 : Math.max(ShellState.barBottom + 11, (parent.height - height * host.zoom) * 0.38))
        entering: host.progress < 1
        transform: Translate {
            y: (1 - host.progress) * Theme.panelRise
        }
        Behavior on width {
            enabled: !Theme.reduced && host.showing && host.progress > 0.99
            NumberAnimation {
                duration: Theme.enter
                easing.type: Easing.OutCubic
            }
        }
        Behavior on height {
            enabled: !Theme.reduced && host.showing && host.progress > 0.99
            NumberAnimation {
                duration: Theme.enter
                easing.type: Easing.OutCubic
            }
        }
        Behavior on x {
            enabled: !Theme.reduced && host.showing && host.progress > 0.99
            NumberAnimation {
                duration: Theme.enter
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            enabled: !Theme.reduced && host.showing && host.progress > 0.99
            NumberAnimation {
                duration: Theme.enter
                easing.type: Easing.OutCubic
            }
        }
        opacity: host.progress
        enabled: host.showing
        visible: host.visible
        active: host.visible
    }
}
