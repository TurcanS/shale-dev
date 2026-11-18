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

BarLiveChip {
    id: privacyButton
    // The bar this item is on: its screen, layout, weather and helpers.
    required property var bar
    readonly property bool mic: Services.micUsers.length > 0
    readonly property bool camera: bar.cameraUsers.length > 0
    readonly property bool sharing: Services.screenSharers.length > 0
    readonly property var apps: Services.micUsers.concat(bar.cameraUsers, Services.screenSharers).filter((name, i, all) => all.indexOf(name) === i)
    shown: mic || camera || sharing
    hint: [mic ? "Microphone in use: " + Services.micUsers.join(", ") : "",
           camera ? "Camera in use: " + bar.cameraUsers.join(", ") : "",
           sharing ? "Sharing your screen with " + Services.screenSharers.join(", ") : ""].filter(line => line).join("\n")
    tooltip: bar.tooltip
    Accessible.name: hint
    onClicked: bar.toggleControl("audio")
    contentItem: RowLayout {
        spacing: 6
        // Each source pops in as it starts and out as it stops.
        C.Pop {
            shown: privacyButton.mic
            Layout.preferredWidth: 12
            Layout.preferredHeight: 12
            C.Icon { name: "mic"; size: 12; color: Theme.accentText }
        }
        C.Pop {
            shown: privacyButton.camera
            Layout.preferredWidth: 12
            Layout.preferredHeight: 12
            C.Icon { name: "camera"; size: 12; color: Theme.accentText }
        }
        C.Pop {
            shown: privacyButton.sharing
            Layout.preferredWidth: 12
            Layout.preferredHeight: 12
            C.Icon { name: "cast"; size: 12; color: Theme.accentText }
        }
        // Names the app; more than one shows as "+N".
        C.Label {
            visible: !bar.compact && privacyButton.apps.length > 0
            text: privacyButton.apps.length ? privacyButton.apps[0] + (privacyButton.apps.length > 1 ? " +" + (privacyButton.apps.length - 1) : "") : ""
            color: Theme.accentText
            font.pixelSize: 11
            font.weight: Font.DemiBold
            elide: Text.ElideNone
        }
    }
}
