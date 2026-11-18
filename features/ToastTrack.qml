import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../core"
import "../services"
import "../components" as C

// Brief "now playing" card when the track changes in the background.
PanelWindow {
    id: trackWindow
    // Whether this window's screen is the one toasts show on now.
    property bool target: false
    property string title: ""
    property string artist: ""
    property bool shown: false
    readonly property var workspace: Services.workspaces.find(w => w.monitor && w.monitor.name === trackWindow.screen.name && w.active)
    readonly property bool allowed: trackWindow.target && !ShellState.locked && ShellState.setting("trackChangeCard", true) && !Focus.digest
        && !(workspace && workspace.hasFullscreen) && !(ShellState.panel === "control" && ShellState.detail === "media")
    property real reveal: shown && allowed ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: trackWindow.shown ? Theme.enter : Theme.leave; easing.type: Easing.OutCubic } }
    Connections {
        target: NowPlaying
        function onTrackChanged() {
            const player = NowPlaying.player;
            if (!trackWindow.allowed || !player)
                return;
            trackWindow.title = player.trackTitle || "";
            trackWindow.artist = player.trackArtist || player.identity || "";
            trackWindow.shown = true;
            if (!trackHover.hovered)
                trackTimer.restart();
        }
    }
    Timer {
        id: trackTimer
        interval: 3500
        onTriggered: trackWindow.shown = false
    }
    anchors {
        top: true
    }
    margins.top: ShellState.barBottomOn(trackWindow.screen ? trackWindow.screen.name : "") + 9
    implicitWidth: 340
    implicitHeight: 64
    visible: reveal > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "shale-track"
    WlrLayershell.layer: WlrLayer.Overlay
    C.FrostSource {
        id: frostSource
        screenName: trackWindow.screen ? trackWindow.screen.name : ""
        screenSize: trackWindow.screen ? Qt.size(trackWindow.screen.width, trackWindow.screen.height) : Qt.size(1920, 1080)
    }
    Rectangle {
        anchors.fill: parent
        radius: 18
        color: Theme.glass ? "transparent" : Theme.module
        border.width: Theme.glass ? 0 : 1
        border.color: Theme.cardEdge
        opacity: trackWindow.reveal
        transform: Translate { y: Theme.reduced ? 0 : (1 - trackWindow.reveal) * -8 }
        // With glass, the case: the window is centred under the bar.
        C.Frost {
            anchors.fill: parent
            visible: Theme.glass
            source: frostSource
            radius: parent.radius
            area: Qt.rect(((trackWindow.screen ? trackWindow.screen.width : 0) - trackWindow.width) / 2, trackWindow.margins.top, width, height)
        }
        HoverHandler {
            id: trackHover
            // Reading the card keeps it open; leaving gives a moment before it goes.
            onHoveredChanged: if (hovered)
                trackTimer.stop();
            else if (trackWindow.shown)
                trackTimer.restart()
        }
        TapHandler {
            onTapped: {
                trackWindow.shown = false;
                ShellState.open("control", trackWindow.screen.name);
                ShellState.detail = "media";
            }
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: Theme.gapM
            C.CoverArt {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: Theme.radiusKey
                source: NowPlaying.artFile
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                C.Label {
                    text: trackWindow.title
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                C.Label {
                    text: trackWindow.artist
                    color: Theme.textMuted
                    font.pixelSize: Theme.small
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
            C.Button {
                glyph: "next"
                flat: true
                implicitWidth: 36
                implicitHeight: Theme.controlHeight
                cornerRadius: 18
                hint: "Next track"
                visible: !!NowPlaying.player && NowPlaying.player.canGoNext
                onClicked: NowPlaying.player.next()
            }
        }
    }
}
