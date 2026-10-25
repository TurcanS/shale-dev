import QtQuick
import QtQuick.Layouts
import "../core"
import "../components" as C

// The unlock group both styles show at the bottom centre: your picture, a greeting, the password field and the
// status line under it. A wrong password shakes the field; reduced motion keeps only its red edge and the message.
ColumnLayout {
    id: root
    required property var context
    // Any key reaching the field, for styles that wake on activity.
    signal keyPressed()
    function focusField() {
        field.focusField();
    }
    width: 340
    spacing: 12
    LockAvatar {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 64
        Layout.preferredHeight: 64
    }
    C.Label {
        text: "Welcome back"
        font.pixelSize: 16
        font.weight: Font.DemiBold
        elide: Text.ElideNone
        Layout.alignment: Qt.AlignHCenter
    }
    LockField {
        id: field
        context: root.context
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 340
        Layout.preferredHeight: 48
        onKeyPressed: root.keyPressed()
        transform: Translate { id: shakeOffset }
        SequentialAnimation {
            id: shake
            NumberAnimation { target: shakeOffset; property: "x"; to: -6; duration: 60; easing.type: Easing.InOutSine }
            NumberAnimation { target: shakeOffset; property: "x"; to: 6; duration: 60; easing.type: Easing.InOutSine }
            NumberAnimation { target: shakeOffset; property: "x"; to: -6; duration: 60; easing.type: Easing.InOutSine }
            NumberAnimation { target: shakeOffset; property: "x"; to: 6; duration: 60; easing.type: Easing.InOutSine }
            NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: 60; easing.type: Easing.InOutSine }
        }
        Connections {
            target: root.context
            function onFailed() {
                if (!Theme.reduced && !Theme.lowPower)
                    shake.restart();
            }
        }
    }
    LockNote {
        context: root.context
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(implicitHeight, 18)
    }
}
