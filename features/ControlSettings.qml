import QtQuick
import QtQuick.Layouts
import "../core"
import "../core/controlItems.js" as ControlItems
import "../components" as C

// Settings → Control: the order of its tiles and buttons, and which parts it shows.
ColumnLayout {
    id: root
    spacing: 8
    readonly property var setting: ShellState.setting("controlLayout", {})
    readonly property var arrangement: ControlItems.layout(setting)
    function save(value) {
        ShellState.setSetting("controlLayout", value);
    }
    // One reorderable entry: its glyph, name and line, earlier and later, then its switch.
    component Entry: RowLayout {
        id: entry
        property var item: ({})
        property bool shown: true
        property bool first: false
        property bool last: false
        // Read by Find a setting.
        readonly property string label: item.title || ""
        readonly property string description: item.required ? "Always shown" : item.description || ""
        signal toggled()
        signal moved(int step)
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(entry.description !== "" ? 58 : 50, Theme.body + 36)
        Layout.leftMargin: 14
        Layout.rightMargin: Theme.gapL
        spacing: Theme.gapM
        C.Icon {
            name: entry.item.icon || "grid"
            size: 16
            color: entry.shown ? Theme.textDim : Theme.textFaint
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            C.Label {
                text: entry.label
                color: entry.shown ? Theme.text : Theme.textFaint
                Layout.fillWidth: true
            }
            C.Label {
                visible: text !== ""
                text: entry.description
                color: Theme.textDim
                font.pixelSize: Theme.small
                Layout.fillWidth: true
            }
        }
        C.Button {
            glyph: "chevron"
            rotation: -90
            cornerRadius: 8
            // Hidden entries sit after the shown ones; they keep no place of their own.
            enabled: !entry.first && entry.shown
            hint: "Move " + entry.label + " earlier"
            implicitWidth: 28
            implicitHeight: 28
            onClicked: entry.moved(-1)
        }
        C.Button {
            glyph: "chevron"
            rotation: 90
            cornerRadius: 8
            enabled: !entry.last && entry.shown
            hint: "Move " + entry.label + " later"
            implicitWidth: 28
            implicitHeight: 28
            onClicked: entry.moved(1)
        }
        C.Switch {
            Layout.leftMargin: Theme.gapXs
            enabled: !entry.item.required
            selected: entry.shown
            hint: "Show " + entry.label
            onClicked: entry.toggled()
        }
    }
    C.SectionHeader { text: "Tiles" }
    C.Caption {
        text: "Two to a row, in this order. Tiles for hardware this computer lacks stay out of sight."
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
    C.Group {
        Repeater {
            model: root.arrangement.tiles
            Entry {
                required property var modelData
                required property int index
                item: ControlItems.find(ControlItems.tiles, modelData.id)
                shown: modelData.shown
                first: index === 0
                last: index === root.arrangement.tiles.filter(entry => entry.shown).length - 1
                onToggled: root.save(ControlItems.changed(root.setting, "tiles", modelData.id, 0, !modelData.shown))
                onMoved: step => root.save(ControlItems.changed(root.setting, "tiles", modelData.id, step))
            }
        }
    }
    C.SectionHeader {
        text: "Below the tiles"
        Layout.topMargin: 2
    }
    C.Group {
        Repeater {
            model: ControlItems.sections
            C.Toggle {
                required property var modelData
                Layout.fillWidth: true
                flat: true
                text: modelData.title
                description: modelData.description || ""
                selected: root.arrangement.sections[modelData.id]
                onClicked: root.save(ControlItems.section(root.setting, modelData.id, !selected))
            }
        }
    }
    C.SectionHeader {
        text: "Buttons"
        Layout.topMargin: 2
    }
    C.Group {
        Repeater {
            model: root.arrangement.footer
            Entry {
                required property var modelData
                required property int index
                item: ControlItems.find(ControlItems.footer, modelData.id)
                shown: modelData.shown
                first: index === 0
                last: index === root.arrangement.footer.filter(entry => entry.shown).length - 1
                onToggled: root.save(ControlItems.changed(root.setting, "footer", modelData.id, 0, !modelData.shown))
                onMoved: step => root.save(ControlItems.changed(root.setting, "footer", modelData.id, step))
            }
        }
    }
    C.Group {
        Layout.topMargin: 4
        C.SettingRow {
            label: "Control"
            description: "See the arrangement in place"
            C.Button {
                text: "Open Control"
                glyph: "sliders"
                implicitHeight: 32
                onClicked: ShellState.open("control")
            }
        }
    }
}
