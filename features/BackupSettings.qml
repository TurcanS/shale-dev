import QtQuick
import QtQuick.Layouts
import "../core"
import "../components" as C

// Settings → Backup: copy your settings to a file, and bring them back here or on another computer.
ColumnLayout {
    id: root
    spacing: 8
    property bool busy: false
    property string result: ""
    property bool failed: false
    // When the file in the field was exported, and when the settings from before a reset or import were kept.
    property string exported: ""
    property string previous: ""
    function when(stamp) {
        const date = new Date(stamp);
        return stamp && !isNaN(date.getTime()) ? Qt.formatDateTime(date, "d MMM yyyy, " + (ShellState.setting("clock24h", true) ? "HH:mm" : "h:mm AP")) : "";
    }
    function refresh() {
        Backend.request("settings.backup", {path: pathField.text.trim()}, (r, e) => {
            exported = e ? "" : when(r.exported);
            previous = e ? "" : when(r.previous);
        });
    }
    Component.onCompleted: refresh()
    Connections {
        target: ShellState
        // A reset on another page, or its Undo, changes what there is to put back.
        function onSettingsSaved() {
            root.refresh();
        }
    }
    Timer {
        id: lookUp
        interval: 400
        onTriggered: root.refresh()
    }
    function transfer(method) {
        busy = true;
        result = "";
        Backend.request(method, {path: pathField.text.trim()}, (r, e) => {
            busy = false;
            failed = !!e;
            if (e) {
                result = e.message;
                return;
            }
            if (method === "settings.export") {
                result = r.count ? "Saved " + r.count + " setting" + (r.count === 1 ? "" : "s") + " to " + r.path : "Saved to " + r.path + ". Everything is at its default, so there was nothing to save.";
                refresh();
                return;
            }
            ShellState.unsaved = {};
            ShellState.settings = r.settings;
            ShellState.settingsSaved();
            const others = r.skipped.filter(key => key !== "shortcuts");
            result = (r.applied.length ? "Applied " + r.applied.length + " setting" + (r.applied.length === 1 ? "" : "s") + "." : "Nothing to apply.")
                + (others.length ? " Skipped " + others.join(", ") + "." : "")
                + (r.shortcutsReason ? " Shortcuts were left alone: " + r.shortcutsReason + "." : "")
                + (r.problem ? " " + r.problem : "");
            failed = !!r.problem;
        });
    }
    C.Label {
        text: "Save your settings to a file to keep a copy or move them to another computer. Usage history, pinned apps, your weather location and folders stay out of it."
        color: Theme.textSecondary
        font.pixelSize: Theme.label
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
    C.Group {
        C.SettingRow {
            label: "File"
            description: root.exported ? "Exported " + root.exported : "Where the copy is saved, and read from"
            C.Field {
                id: pathField
                Layout.preferredWidth: 280
                implicitHeight: 36
                font.pixelSize: Theme.label
                Accessible.name: "Backup file"
                text: "~/shale-settings.json"
                onTextEdited: {
                    root.result = "";
                    lookUp.restart();
                }
            }
        }
        C.SettingRow {
            label: "Export"
            description: "Every setting you changed, in one file"
            C.Button {
                text: "Export"
                glyph: "copy"
                accent: true
                implicitHeight: 32
                enabled: !root.busy && Backend.ready
                onClicked: root.transfer("settings.export")
            }
        }
        C.SettingRow {
            label: "Import"
            description: "Load the file here, from this or another computer"
            C.Button {
                text: "Import"
                glyph: "folder"
                implicitHeight: 32
                enabled: !root.busy && Backend.ready
                onClicked: root.transfer("settings.import")
            }
        }
        C.SettingRow {
            label: "Settings from before"
            description: root.previous ? "As they were before the last reset or import, kept " + root.previous : "Kept when you reset a page or import a file"
            C.Button {
                text: "Put back"
                glyph: "refresh"
                implicitHeight: 32
                enabled: !root.busy && Backend.ready && root.previous !== ""
                onClicked: {
                    root.result = "";
                    ShellState.restoreSettings();
                }
            }
        }
    }
    C.Label {
        visible: root.result !== ""
        text: root.result
        color: root.failed ? Theme.dangerText : Theme.success
        font.pixelSize: Theme.small
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
    C.Label {
        text: "Importing replaces the settings the file has and keeps the rest. Shortcuts come along when their keys are free on this computer. Exporting replaces an earlier export of the same name, never another file. Putting back swaps today's settings with the ones from before, so doing it twice returns you here; shortcuts stay as they are."
        color: Theme.textDim
        font.pixelSize: Theme.small
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
}
