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
    id: titleKey
    // The bar this item is on: its screen, layout, weather and helpers.
    required property var bar
    readonly property var window: Services.activeWindow
    readonly property string appId: window ? (window.wayland ? window.wayland.appId || "" : (window.lastIpcObject || {}).class || "") : ""
    readonly property var entry: appId && DesktopEntries.heuristicLookup ? DesktopEntries.heuristicLookup(appId) : null
    readonly property string app: {
        const name = entry && entry.name ? entry.name : appId.split(".").pop();
        return name.charAt(0).toUpperCase() + name.slice(1);
    }
    readonly property string title: window ? window.title || "" : ""
    shown: bar.width > 1400
    leftPadding: 8
    rightPadding: 8
    // Leaves room for the clock in the middle.
    readonly property real maxWidth: Math.max(120, Math.min(340, bar.width / 2 - 460))
    implicitWidth: Math.min(maxWidth, implicitContentWidth + leftPadding + rightPadding)
    // What the title may take after the tile and the app's name.
    readonly property real titleRoom: Math.max(30, maxWidth - leftPadding - rightPadding - (app !== "" ? 18 + appName.lineWidth : 0))
    hint: title || "Pages"
    onClicked: ShellState.toggle("overview", bar.outputName)
    contentItem: RowLayout {
        spacing: Theme.gapS
        Rectangle {
            visible: titleKey.app !== ""
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            radius: 5
            color: Theme.key
            C.RollText {
                anchors.centerIn: parent
                text: titleKey.app.charAt(0).toUpperCase()
                color: Theme.textSecondary
                font.pixelSize: 10
                font.weight: Font.Bold
            }
        }
        // The name and title roll when focus moves to another window, and the key eases to the new width.
        C.RollText {
            id: appName
            visible: titleKey.app !== ""
            text: titleKey.app
            font.pixelSize: 12
            font.weight: Font.DemiBold
            maximumWidth: 140
        }
        // Runs on from the app name like one line of text.
        C.RollText {
            visible: text !== ""
            text: titleKey.app === "" ? (titleKey.title || "Shale") : titleKey.title && titleKey.title !== titleKey.app ? " · " + titleKey.title : ""
            color: Theme.textDim
            font.pixelSize: 12
            maximumWidth: titleKey.titleRoom
            Layout.leftMargin: titleKey.app === "" ? 0 : -Theme.gapS
        }
    }
}
