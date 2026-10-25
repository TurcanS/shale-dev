import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../core/barItems.js" as BarItems
import "../components" as C

// Settings → Bar: where each item sits, how the bar looks, and the screens it shows on.
ColumnLayout {
    id: root
    spacing: 8
    readonly property var layout: BarItems.layout(ShellState.setting("barLayout", {}))
    readonly property var zoneNames: ({left: "Left", center: "Center", right: "Right", hidden: "Hidden"})
    readonly property bool edge: ShellState.setting("barStyle", "floating") === "edge"
    function move(id, zone, step) {
        ShellState.setSetting("barLayout", BarItems.moved(ShellState.setting("barLayout", {}), id, zone, step));
    }
    // A zone's items as the bar draws them: status items next to each other share one key.
    function runs(ids) {
        const result = [];
        for (const id of ids) {
            const status = BarItems.status.indexOf(id) >= 0;
            const last = result[result.length - 1];
            if (status && last && last.status)
                last.ids.push(id);
            else
                result.push({status: status, ids: [id]});
        }
        return result;
    }
    // A plain on/off preference on a group.
    component SettingToggle: C.Toggle {
        property string key: ""
        property bool fallback: false
        flat: true
        Layout.fillWidth: true
        selected: ShellState.setting(key, fallback)
        onClicked: ShellState.setSetting(key, !ShellState.setting(key, fallback))
    }
    // One part of the small bar: an item's glyph, the page dots or the clock.
    component PreviewItem: Item {
        id: part
        property string itemId: ""
        readonly property var item: BarItems.find(itemId)
        implicitWidth: itemId === "workspaces" ? dots.implicitWidth + 4 : itemId === "clock" ? clockText.implicitWidth + 8 : 16
        implicitHeight: 16
        Row {
            id: dots
            visible: part.itemId === "workspaces"
            anchors.centerIn: parent
            spacing: 3
            Rectangle { width: 12; height: 5; radius: 2.5; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: 5; height: 5; radius: 2.5; color: Theme.textFaint; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: 5; height: 5; radius: 2.5; color: Theme.textFaint; anchors.verticalCenter: parent.verticalCenter }
        }
        C.Label {
            id: clockText
            visible: part.itemId === "clock"
            anchors.centerIn: parent
            text: ShellState.setting("clock24h", true) ? "14:30" : "2:30"
            color: Theme.textSecondary
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.features: ({"tnum": 1})
        }
        C.Icon {
            visible: part.itemId !== "workspaces" && part.itemId !== "clock"
            anchors.centerIn: parent
            name: part.item ? part.item.icon : ""
            size: 11
            color: Theme.textMuted
        }
    }
    // A small picture of the bar as arranged, floating over a strip of desktop (or edge to edge).
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 46
        radius: Theme.radiusCard + 2
        color: Theme.well
        border.width: 1
        border.color: Theme.separator
        clip: true
        Accessible.role: Accessible.Graphic
        Accessible.name: "Bar preview"
        Rectangle {
            id: miniBar
            x: root.edge ? 0 : 10
            y: root.edge ? 0 : 10
            width: parent.width - 2 * x
            height: 26
            radius: root.edge ? 0 : 8
            color: Theme.caseColor
            border.width: 1
            border.color: Theme.hairline
            Repeater {
                model: ["left", "center", "right"]
                Row {
                    id: zoneRow
                    required property string modelData
                    anchors.verticalCenter: parent.verticalCenter
                    x: modelData === "left" ? 6 : modelData === "center" ? (miniBar.width - width) / 2 : miniBar.width - width - 6
                    spacing: 3
                    Repeater {
                        model: root.runs(root.layout[zoneRow.modelData])
                        Rectangle {
                            id: run
                            required property var modelData
                            implicitWidth: runRow.implicitWidth + (modelData.status ? 8 : 2)
                            implicitHeight: 18
                            radius: 5
                            color: modelData.status ? Theme.module : "transparent"
                            Row {
                                id: runRow
                                anchors.centerIn: parent
                                spacing: 1
                                Repeater {
                                    model: run.modelData.ids
                                    PreviewItem {
                                        required property string modelData
                                        itemId: modelData
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    C.Caption {
        text: "Items that only show while something happens (recording, focus, timers, VPN) take their place when they appear."
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
    Repeater {
        model: ["left", "center", "right", "hidden"]
        ColumnLayout {
            id: zone
            required property string modelData
            readonly property var ids: root.layout[modelData]
            readonly property bool hidden: modelData === "hidden"
            Layout.fillWidth: true
            spacing: 8
            C.SectionHeader {
                text: root.zoneNames[zone.modelData]
                Layout.topMargin: 2
            }
            C.Group {
                C.Label {
                    visible: zone.ids.length === 0
                    text: zone.hidden ? "Every item is on the bar." : "Nothing here."
                    color: Theme.textDim
                    font.pixelSize: Theme.small
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    Layout.leftMargin: Theme.gapL
                }
                // Glyph, name, what it shows, earlier and later on the bar, then where it sits.
                Repeater {
                    model: zone.ids
                    RowLayout {
                        id: row
                        required property string modelData
                        required property int index
                        readonly property var item: BarItems.find(modelData)
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(50, Theme.body + 34)
                        Layout.leftMargin: 14
                        Layout.rightMargin: 10
                        spacing: Theme.gapM
                        C.Icon {
                            name: row.item.icon
                            size: 16
                            color: zone.hidden ? Theme.textFaint : Theme.textDim
                        }
                        C.Label {
                            text: row.item.title
                            color: zone.hidden ? Theme.textFaint : Theme.text
                            Layout.preferredWidth: Math.max(170, Theme.body * 12)
                        }
                        C.Label {
                            text: row.item.required ? (row.item.description ? row.item.description + " · always shown" : "Always shown") : row.item.description || ""
                            color: Theme.textDim
                            font.pixelSize: Theme.small
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                        }
                        C.Button {
                            visible: !zone.hidden
                            glyph: "chevron"
                            rotation: -90
                            cornerRadius: 8
                            enabled: row.index > 0
                            hint: "Move " + row.item.title + " left"
                            implicitWidth: 28
                            implicitHeight: 28
                            onClicked: root.move(row.modelData, "", -1)
                        }
                        C.Button {
                            visible: !zone.hidden
                            glyph: "chevron"
                            rotation: 90
                            cornerRadius: 8
                            enabled: row.index < zone.ids.length - 1
                            hint: "Move " + row.item.title + " right"
                            implicitWidth: 28
                            implicitHeight: 28
                            onClicked: root.move(row.modelData, "", 1)
                        }
                        C.Segmented {
                            // One width for every row, with or without Hide, so the columns line up.
                            proportional: true
                            Layout.fillWidth: false
                            Layout.preferredWidth: Math.max(236, Theme.body * 17)
                            segmentHeight: 30
                            trackColor: Theme.well
                            model: [{key: "left", text: "Left"}, {key: "center", text: "Center"}, {key: "right", text: "Right"}]
                                .concat(row.item.required ? [] : [{key: "hidden", text: "Hide", hint: "Hide " + row.item.title}])
                            current: zone.modelData
                            Accessible.name: "Where " + row.item.title + " sits"
                            onActivated: key => root.move(row.modelData, key, 0)
                        }
                    }
                }
            }
        }
    }
    C.SectionHeader {
        text: "Look"
        Layout.topMargin: 2
    }
    C.Group {
        C.ChoiceRow {
            label: "Style"
            description: "Floating keeps 8 px from the screen edges"
            model: [{key: "floating", text: "Floating"}, {key: "edge", text: "Edge to edge"}]
            current: ShellState.setting("barStyle", "floating")
            onActivated: key => ShellState.setSetting("barStyle", key)
        }
        C.ChoiceRow {
            label: "Clock"
            description: "What the clock shows beside the time"
            model: [{key: "time", text: "Time"}, {key: "day-time", text: "Day"}, {key: "date-time", text: "Date"}]
            current: ShellState.setting("clockFormat", "date-time")
            onActivated: key => ShellState.setSetting("clockFormat", key)
        }
        SettingToggle {
            text: "Show seconds"
            description: "On the bar's clock"
            key: "clockSeconds"
        }
        C.ChoiceRow {
            label: "Pages"
            description: "How the pages on a screen are drawn"
            model: [{key: "numbers", text: "Numbers"}, {key: "dots", text: "Dots"}]
            current: ShellState.setting("workspaceStyle", "dots")
            onActivated: key => ShellState.setSetting("workspaceStyle", key)
        }
        C.ChoiceRow {
            label: "Empty pages"
            description: "Keep the first ones on the bar even without windows"
            model: [{key: 0, text: "Hide"}, {key: 5, text: "1–5"}, {key: 10, text: "1–10"}]
            current: ShellState.setting("workspaceSlots", 0)
            onActivated: key => ShellState.setSetting("workspaceSlots", key)
        }
        C.ChoiceRow {
            label: "Tray icons"
            description: "The rest open from the tray button"
            model: [{key: -1, text: "Auto", hint: "More on wider screens"}, {key: 0, text: "0"}, {key: 1, text: "1"}, {key: 2, text: "2"}, {key: 3, text: "3"}, {key: 5, text: "5"}]
            current: ShellState.setting("trayIcons", -1)
            onActivated: key => ShellState.setSetting("trayIcons", key)
        }
        C.ChoiceRow {
            label: "Battery percentage"
            description: "Low battery always shows it"
            model: [{key: "auto", text: "Auto", hint: "Hidden on narrow screens"}, {key: "always", text: "Always"}, {key: "never", text: "Never"}]
            current: ShellState.setting("batteryPercent", "auto")
            onActivated: key => ShellState.setSetting("batteryPercent", key)
        }
    }
    C.SectionHeader {
        text: "Behaviour"
        Layout.topMargin: 2
    }
    C.Group {
        SettingToggle {
            text: "Hide bar over fullscreen windows"
            description: "It comes back when the window leaves fullscreen"
            key: "hideFullscreen"
            fallback: true
        }
        SettingToggle {
            text: "Show what's playing in the bar"
            description: "Cover and title, on bars wider than 1100 px"
            key: "barMedia"
            fallback: true
        }
        SettingToggle {
            text: "Show a card when the track changes"
            description: "Title and artist for a moment"
            key: "trackChangeCard"
            fallback: true
        }
    }
    C.SectionHeader {
        text: "Show the bar on"
        Layout.topMargin: 2
    }
    C.Group {
        Repeater {
            model: Quickshell.screens
            C.Toggle {
                required property var modelData
                Layout.fillWidth: true
                flat: true
                text: modelData.name
                description: modelData.model || ""
                selected: ShellState.setting("hiddenOutputs", []).indexOf(modelData.name) < 0
                onClicked: {
                    const hidden = ShellState.setting("hiddenOutputs", []);
                    ShellState.setSetting("hiddenOutputs", hidden.indexOf(modelData.name) < 0 ? hidden.concat([modelData.name]) : hidden.filter(n => n !== modelData.name));
                }
            }
        }
    }
}
