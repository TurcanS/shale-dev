import QtQuick
import QtQuick.Controls
import "../core"
import "../components" as C

// The password field with its unlock button. Typing on one screen shows on all of them; each style adds
// its own motion for a wrong password.
Item {
    id: root
    required property var context
    readonly property alias masked: field.masked
    // Room on the left for something drawn over the field.
    property int leftInset: 18
    // Any key reaching the field, for styles that wake on activity.
    signal keyPressed()
    function focusField() {
        field.forceActiveFocus();
    }
    implicitWidth: 340
    implicitHeight: 48
    Connections {
        target: root.context
        function onFailed() {
            field.forceActiveFocus();
        }
        function onPasswordChanged() {
            if (field.text !== root.context.password)
                field.text = root.context.password;
        }
    }
    TextField {
        id: field
        // PAM's follow-up questions, such as a one-time code, may show what is typed.
        readonly property bool masked: root.context.prompt === "" || !root.context.promptVisible
        anchors.fill: parent
        focus: true
        echoMode: masked ? TextInput.Password : TextInput.Normal
        passwordCharacter: "●"
        enabled: !root.context.busy && !root.context.unlocking
        placeholderText: root.context.prompt || (root.context.busy ? "Checking…" : "Password")
        placeholderTextColor: Theme.tint(Theme.text, 0.45)
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: text === "" || !masked ? 15 : 12
        font.letterSpacing: text === "" || !masked ? 0 : 4
        selectionColor: Theme.selectionHover
        leftPadding: root.leftInset
        rightPadding: 50
        verticalAlignment: TextInput.AlignVCenter
        Accessible.name: root.context.prompt || "Password"
        Component.onCompleted: {
            // A screen added while locked picks up what was already typed.
            text = root.context.password;
            forceActiveFocus();
        }
        // Back after a check, possibly with PAM's next question.
        onEnabledChanged: if (enabled)
            forceActiveFocus()
        onActiveFocusChanged: if (activeFocus)
            capsWatch.restart()
        onTextChanged: if (root.context.password !== text)
            root.context.password = text
        onAccepted: root.context.submit()
        Keys.onEscapePressed: root.context.cancel()
        Keys.onPressed: event => {
            capsWatch.restart();
            root.keyPressed();
            event.accepted = false;
        }
        // A dark pill with a hairline edge; a failed check turns the edge red.
        background: Rectangle {
            radius: height / 2
            color: Theme.tint(Theme.caseColor, 0.7)
            border.width: 1
            border.color: root.context.status !== "" ? Theme.tint(Theme.danger, 0.6) : Qt.rgba(1, 1, 1, 0.1)
            Behavior on border.color { ColorAnimation { duration: Theme.fast } }
        }
    }
    // Caps Lock is checked each second only while this field has the keyboard and someone
    // pressed a key in the last half minute, so an idle lock screen does no polling.
    Timer {
        id: capsWatch
        interval: 30000
    }
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: field.activeFocus && capsWatch.running
        onTriggered: root.context.checkCapsLock()
    }
    // The round accent key at the end of the field. It answers only once something is typed.
    C.Button {
        id: unlockKey
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: 36
        implicitHeight: 36
        cornerRadius: 18
        accent: true
        glyph: "arrow-right"
        hint: "Unlock"
        enabled: root.context.password !== "" && !root.context.busy
        focusPolicy: Qt.NoFocus
        foreground: Theme.accentInk
        onClicked: root.context.submit()
        background: Rectangle {
            radius: unlockKey.cornerRadius
            color: unlockKey.enabled && (unlockKey.hovered || unlockKey.down) ? Theme.accentHover : Theme.accent
        }
    }
}
