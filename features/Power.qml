import "../components" as C
import "../core"
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// The session menu: Lock, Sleep, Sign out and Restart as keyed tiles (each letter works too; Sign out and Restart
// ask for a second press), and Power off, which needs a one-second hold.
FocusScope {
    id: root
    readonly property string title: "Session"
    readonly property string headerNote: [uptime, ShellState.recording.active ? "recording in progress" : ""].filter(part => part).join(" · ")
    readonly property int panelWidth: 600
    readonly property int panelHeight: Theme.body >= 18 ? 300 : 264

    property bool leaving: false
    // The action waiting for its second press: "logout", "reboot" or none.
    property string picked: ""
    // Session actions only run from the panel in front, never from a covered or locked one.
    readonly property bool ready: !leaving && ShellState.panel === "power" && !ShellState.locked && root.Window.active
    property string uptime: ""

    // ShellState runs the action, so a refusal still shows as a message after this panel closes.
    function endSession(action) {
        if (leaving)
            return;
        leaving = true;
        ShellState.close();
        ShellState.sessionAction(action);
    }
    function choose(action) {
        if (!ready)
            return;
        if (action === "lock") {
            ShellState.action("lock");
        } else if (action === "suspend") {
            endSession("suspend");
        } else if (picked === action) {
            endSession(action);
        } else {
            picked = action;
            pickTimeout.restart();
        }
    }
    function duration(seconds) {
        const days = Math.floor(seconds / 86400), hours = Math.floor(seconds % 86400 / 3600), minutes = Math.floor(seconds % 3600 / 60);
        return days ? "Up " + days + " d " + hours + " h" : hours ? "Up " + hours + " h " + minutes + " min" : "Up " + Math.max(1, minutes) + " min";
    }

    Keys.onPressed: event => {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return;
        const action = ({[Qt.Key_L]: "lock", [Qt.Key_S]: "suspend", [Qt.Key_O]: "logout", [Qt.Key_R]: "reboot"})[event.key];
        if (action) {
            root.choose(action);
            event.accepted = true;
        }
    }
    Process {
        id: uptimeRead
        command: ["cat", "/proc/uptime"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const seconds = parseFloat(text);
                root.uptime = isNaN(seconds) ? "" : root.duration(seconds);
            }
        }
    }
    Timer {
        interval: 60000
        repeat: true
        running: ShellState.panel === "power"
        onTriggered: uptimeRead.running = true
    }
    // An unanswered second press lapses, so a stray key later doesn't end the session.
    Timer {
        id: pickTimeout
        interval: 5000
        onTriggered: root.picked = ""
    }

    // One keyed action: icon tile, name, a short note and its letter. Picked, it takes the accent.
    component SessionTile: C.Button {
        id: tile
        property string note: ""
        property string key: ""
        property string sessionAction: ""
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        Layout.minimumWidth: 0
        topPadding: 12
        leftPadding: 12
        rightPadding: 12
        bottomPadding: 12
        cornerRadius: Theme.radiusModule
        enabled: root.ready
        Accessible.description: note + " Key " + key + "."
        background: Rectangle {
            radius: tile.cornerRadius
            color: tile.selected ? Theme.accentSoft : tile.hovered || tile.down || tile.visualFocus ? Theme.mix(Theme.module, Theme.text, 0.04) : Theme.module
            border.width: 1
            border.color: tile.selected ? Theme.accentLine : "transparent"
            Behavior on color {
                ColorAnimation {
                    duration: Theme.fast
                }
            }
        }
        contentItem: ColumnLayout {
            spacing: 4
            C.GlyphTile {
                size: 36
                glyph: tile.glyph
                selected: tile.selected
            }
            Item {
                Layout.fillHeight: true
            }
            C.Label {
                text: tile.text
                font.pixelSize: 14
                font.weight: 650
                Layout.fillWidth: true
            }
            C.Label {
                text: tile.note
                color: Theme.textMuted
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                Layout.bottomMargin: 2
                Layout.fillWidth: true
            }
            C.KeyHint {
                text: tile.key
                mono: true
                color: Theme.key
            }
        }
        onClicked: root.choose(sessionAction)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.gapS
            SessionTile {
                text: "Lock"
                glyph: "lock"
                key: "L"
                sessionAction: "lock"
                note: "Apps keep running."
            }
            SessionTile {
                text: "Sleep"
                glyph: "moon"
                key: "S"
                sessionAction: "suspend"
                note: "Locks first."
            }
            SessionTile {
                text: root.picked === "logout" ? "Sign out?" : "Sign out"
                glyph: "logout"
                key: "O"
                sessionAction: "logout"
                selected: root.picked === "logout"
                note: root.picked === "logout" ? "Press again to sign out." : "Closes every app."
            }
            SessionTile {
                text: root.picked === "reboot" ? "Restart?" : "Restart"
                glyph: "refresh"
                key: "R"
                sessionAction: "reboot"
                selected: root.picked === "reboot"
                note: root.picked === "reboot" ? "Press again to restart." : "Closes every app."
            }
            // Power off: hold for a second while the ring fills.
            C.HoldButton {
                id: powerOff
                text: "Power off"
                destructive: true
                Layout.preferredWidth: 124
                Layout.fillHeight: true
                implicitHeight: 150
                padding: 12
                armed: root.ready
                onConfirmed: root.endSession("shutdown")
                background: Rectangle {
                    radius: Theme.radiusModule
                    color: powerOff.hovered || powerOff.visualFocus || powerOff.down ? Qt.rgba(1, 0.42, 0.357, 0.11) : Theme.dangerWash
                    border.width: 1
                    border.color: Qt.rgba(1, 0.42, 0.357, 0.4)
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.fast
                        }
                    }
                }
                contentItem: ColumnLayout {
                    spacing: 6
                    Item {
                        Layout.fillHeight: true
                    }
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 60
                        implicitHeight: 60
                        C.Ring {
                            anchors.fill: parent
                            size: 60
                            thickness: 4
                            value: powerOff.progress
                            color: Theme.danger
                            trackColor: Qt.rgba(1, 0.42, 0.357, 0.18)
                        }
                        C.Icon {
                            anchors.centerIn: parent
                            name: "power"
                            size: 22
                            color: Theme.dangerText
                        }
                    }
                    C.Label {
                        text: powerOff.progress > 0 ? "Keep holding" : "Power off"
                        color: Theme.dangerText
                        font.pixelSize: 14
                        font.weight: 650
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                    C.Label {
                        text: "hold for 1 s"
                        color: Theme.mix(Theme.dangerText, Theme.module, 0.3)
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
        }
        // What happens next: the default hint, a pending second press, the hold, or a recording to save first.
        Rectangle {
            id: statusLine
            readonly property string mode: powerOff.progress > 0 ? "hold" : root.picked !== "" ? "picked" : ShellState.recording.active ? "recording" : ""
            Layout.fillWidth: true
            implicitHeight: 30
            radius: Theme.radiusKey
            color: Theme.module
            Accessible.role: Accessible.StatusBar
            Accessible.name: status.text
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: Theme.gapS
                Rectangle {
                    implicitWidth: 6
                    implicitHeight: 6
                    radius: 3
                    color: statusLine.mode === "hold" ? Theme.danger : statusLine.mode === "picked" ? Theme.accent
                         : statusLine.mode === "recording" ? Theme.warning : Theme.textFaint
                }
                C.Label {
                    id: status
                    text: ({
                            hold: "Keep holding · " + Math.round(powerOff.progress * 100) + "%",
                            picked: root.picked === "logout" ? "Press O again or click Sign out to sign out." : "Press R again or click Restart to restart.",
                            recording: "Recording in progress · save it before ending your session."
                        })[statusLine.mode] || "Pick an action or press its letter. Power off needs a one-second hold."
                    color: statusLine.mode === "recording" ? Theme.warning : Theme.textSecondary
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
        }
    }
}
