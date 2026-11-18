import QtQuick
import "../core"
import "../components" as C

// What one output shows while locked, in the chosen style. `context` is the shared LockScreen (or a preview
// stand-in). Only counts are shown for notifications; their contents stay private. With Settings → Appearance →
// Lock screen → Unlock on Shatter, an accepted password breaks the screen apart from the password field, over the
// plain wallpaper (black around the classic style) that LockTransition then opens onto the desktop from.
Item {
    id: root
    required property var context
    property string screenName: ""
    readonly property bool classic: ShellState.setting("lockStyle", "particles") === "classic"
    readonly property bool shatters: ShellState.setting("unlockEffect", "shatter") === "shatter" && !Theme.reduced && !Theme.lowPower
    // Under the breaking screen: the picture the desktop comes back from.
    Rectangle {
        anchors.fill: parent
        visible: shatter.running
        color: "#000000"
        LockBackdrop {
            anchors.fill: parent
            visible: !root.classic
            screenName: root.screenName
            sharp: true
            blur: 0
            dim: 0
        }
    }
    Item {
        id: face
        anchors.fill: parent
        Loader {
            anchors.fill: parent
            focus: true
            sourceComponent: root.classic ? classic : particles
        }
    }
    // One picture of the screen as the password is accepted; the shards are cut from it.
    ShaderEffectSource {
        id: snapshot
        sourceItem: face
        width: face.width
        height: face.height
        live: false
        hideSource: shatter.running
        visible: false
    }
    C.Shatter {
        id: shatter
        anchors.fill: parent
        visible: running
        source: snapshot
        // The password field, at the bottom centre in both styles.
        impact: Qt.point(width / 2, height - Math.max(48, Math.round(height * 0.133)) - 30)
    }
    Connections {
        target: root.context
        function onUnlockingChanged() {
            if (!root.context.unlocking || !root.shatters)
                return;
            snapshot.scheduleUpdate();
            shatter.start();
        }
    }
    Component {
        id: particles
        LockParticles {
            context: root.context
            screenName: root.screenName
        }
    }
    Component {
        id: classic
        LockClassic {
            context: root.context
            screenName: root.screenName
        }
    }
}
