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
    id: recordingChip
    // The bar this item is on: its screen, layout, weather and helpers.
    required property var bar
    readonly property string elapsed: Math.floor(ShellState.recordingSeconds / 60) + ":" + String(ShellState.recordingSeconds % 60).padStart(2, "0")
    shown: ShellState.recording.active
    text: "Recording " + elapsed
    hint: "Stop recording"
    tooltip: bar.tooltip
    onClicked: ShellState.action("stop-recording")
    contentItem: RowLayout {
        spacing: 6
        C.Icon {
            name: "record"
            size: 12
            color: Theme.accentText
        }
        // Tabular digits keep the chip from jittering every second.
        C.Label {
            text: recordingChip.elapsed
            color: Theme.accentText
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.features: ({"tnum": 1})
            elide: Text.ElideNone
        }
    }
}
