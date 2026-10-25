import QtQuick
import QtQuick.Layouts
import "../core"
import "../components" as C

// Settings → Displays: resolution, refresh rate and scale for each screen. A change applies at once and goes back
// after a few seconds unless it is kept, so a mode the screen can't show never sticks.
ColumnLayout {
    id: root
    spacing: Theme.gapM
    // display.list: {displays: [{name, title, width, height, rate, scale, modes, scales, saved, pending (seconds left)}],
    // revertSeconds, startup}
    property var listing: ({displays: [], revertSeconds: 15, startup: true})
    property bool loaded: false
    property string error: ""
    property bool busy: false
    function load() {
        Backend.request("display.list", {}, (r, e) => {
            root.loaded = true;
            root.error = e ? e.message : "";
            if (!e)
                root.listing = r;
        });
    }
    function call(method, params, done) {
        busy = true;
        Backend.request(method, params, (r, e) => {
            busy = false;
            error = e ? e.message : "";
            if (done && !e)
                done(r);
            load();
        });
    }
    // A choice on its own line: its name (and a note at the right) above equal-width options.
    component Choice: ColumnLayout {
        id: choice
        property string label: ""
        property string note: ""
        property var model: []
        property var current: null
        signal activated(var key)
        Layout.fillWidth: true
        Layout.margins: Theme.gapM
        spacing: Theme.gapS
        RowLayout {
            Layout.fillWidth: true
            C.Label {
                text: choice.label
                Layout.fillWidth: true
            }
            C.Caption {
                visible: text !== ""
                text: choice.note
            }
        }
        C.Segmented {
            Layout.fillWidth: true
            trackColor: Theme.well
            model: choice.model
            current: choice.current
            enabled: choice.enabled
            Accessible.name: choice.label
            onActivated: key => choice.activated(key)
        }
    }
    function rateText(rate, rates) {
        // Whole hertz unless two rates would read the same.
        const whole = Math.round(rate);
        return (rates.filter(other => Math.round(other) === whole).length > 1 ? rate.toFixed(2) : String(whole)) + " Hz";
    }
    function scaleText(scale) {
        return Math.round(scale * 100) + "%";
    }
    onVisibleChanged: if (visible)
        load()
    Component.onCompleted: if (visible)
        load()
    Connections {
        target: Backend
        function onEventReceived(name, data) {
            if (name === "display.reverted") {
                root.load();
                ShellState.message("Display settings went back", "info");
            }
        }
    }
    C.Caption {
        text: "Changes apply right away. If you don't keep them within " + root.listing.revertSeconds + " seconds, the screen goes back to how it was."
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
    C.Caption {
        visible: root.loaded && !root.listing.startup
        text: "Kept settings last until Hyprland restarts. Update Shale to have them applied every time Hyprland starts."
        color: Theme.warning
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
    C.Caption {
        visible: root.error !== ""
        text: root.error
        color: Theme.dangerText
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
    C.Caption {
        visible: root.loaded && root.listing.displays.length === 0 && root.error === ""
        text: "No displays found."
        Layout.fillWidth: true
    }
    Repeater {
        model: root.listing.displays
        ColumnLayout {
            id: screen
            required property var modelData
            readonly property var display: modelData
            // The choice being made; it matches the screen until something is picked.
            property int chosenWidth: display.width
            property int chosenHeight: display.height
            property real chosenRate: display.rate
            property real chosenScale: display.scale
            property bool picking: false
            readonly property string sizeKey: chosenWidth + "x" + chosenHeight
            readonly property var mode: display.modes.find(m => m.width === chosenWidth && m.height === chosenHeight) || {width: chosenWidth, height: chosenHeight, rates: [chosenRate]}
            readonly property var scales: display.scales[sizeKey] || [chosenScale]
            readonly property bool changed: chosenWidth !== display.width || chosenHeight !== display.height || Math.abs(chosenRate - display.rate) > 0.005 || Math.abs(chosenScale - display.scale) > 0.001
            // Counts down while the change waits to be kept; the backend says how long is left.
            property int secondsLeft: display.pending
            function reset() {
                chosenWidth = display.width;
                chosenHeight = display.height;
                chosenRate = display.rate;
                chosenScale = display.scale;
            }
            function pickSize(w, h) {
                chosenWidth = w;
                chosenHeight = h;
                picking = false;
                const rates = mode.rates;
                if (!rates.some(r => Math.abs(r - chosenRate) < 0.005))
                    chosenRate = rates[0];
                // Keep the scale when it suits the new size, otherwise the nearest one that does.
                if (!scales.some(s => Math.abs(s - chosenScale) < 0.001))
                    chosenScale = scales.reduce((best, s) => Math.abs(s - chosenScale) < Math.abs(best - chosenScale) ? s : best, scales[0]);
            }
            Layout.fillWidth: true
            spacing: Theme.gapS
            Timer {
                interval: 1000
                repeat: true
                running: screen.secondsLeft > 0
                onTriggered: screen.secondsLeft = Math.max(0, screen.secondsLeft - 1)
            }
            C.SectionHeader {
                text: screen.display.title
                Layout.topMargin: Theme.gapS
            }
            C.Caption {
                text: screen.display.name + " · " + screen.display.width + " × " + screen.display.height + " · " + root.rateText(screen.display.rate, (screen.display.modes.find(m => m.width === screen.display.width && m.height === screen.display.height) || {rates: []}).rates) + " · " + root.scaleText(screen.display.scale)
                    + (screen.display.saved ? " · kept by Shale" : "")
                Layout.fillWidth: true
            }
            C.Group {
                // Resolution: the chosen one, opening the full list below it.
                C.ListRow {
                    Layout.fillWidth: true
                    text: "Resolution"
                    subtitle: screen.chosenWidth + " × " + screen.chosenHeight
                    glyph: "monitor"
                    checkmark: false
                    enabled: !root.busy && screen.display.pending === 0
                    onClicked: screen.picking = !screen.picking
                    trailing: C.Icon {
                        name: "chevron"
                        size: 14
                        rotation: screen.picking ? 90 : 0
                        color: Theme.textDim
                    }
                }
                Repeater {
                    model: screen.picking ? screen.display.modes : []
                    C.ListRow {
                        required property var modelData
                        Layout.fillWidth: true
                        text: modelData.width + " × " + modelData.height
                        subtitle: modelData.rates.map(r => root.rateText(r, modelData.rates)).join(" · ")
                        selected: modelData.width === screen.chosenWidth && modelData.height === screen.chosenHeight
                        onClicked: screen.pickSize(modelData.width, modelData.height)
                    }
                }
                Choice {
                    visible: screen.mode.rates.length > 1
                    label: "Refresh rate"
                    model: screen.mode.rates.map(r => ({key: r, text: root.rateText(r, screen.mode.rates)}))
                    current: screen.mode.rates.find(r => Math.abs(r - screen.chosenRate) < 0.005)
                    enabled: !root.busy && screen.display.pending === 0
                    onActivated: key => screen.chosenRate = key
                }
                Choice {
                    label: "Scale"
                    note: "Desktop " + Math.round(screen.chosenWidth / screen.chosenScale) + " × " + Math.round(screen.chosenHeight / screen.chosenScale)
                    model: screen.scales.map(s => ({key: s, text: root.scaleText(s)}))
                    current: screen.scales.find(s => Math.abs(s - screen.chosenScale) < 0.001)
                    enabled: !root.busy && screen.display.pending === 0
                    onActivated: key => screen.chosenScale = key
                }
            }
            // Apply, then keep or go back while the countdown runs.
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gapS
                C.Label {
                    visible: screen.display.pending > 0
                    text: "Keep these display settings? Going back in " + screen.secondsLeft + " s"
                    color: Theme.accentText
                    font.pixelSize: Theme.label
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                Item {
                    visible: screen.display.pending === 0
                    Layout.fillWidth: true
                }
                C.Button {
                    visible: screen.display.pending > 0
                    text: "Go back"
                    enabled: !root.busy
                    onClicked: root.call("display.revert", {output: screen.display.name})
                }
                C.Button {
                    visible: screen.display.pending > 0
                    text: "Keep"
                    accent: true
                    enabled: !root.busy
                    onClicked: root.call("display.keep", {output: screen.display.name}, () => ShellState.message(screen.display.title + " settings kept", "success"))
                }
                C.Button {
                    visible: screen.display.pending === 0 && screen.display.saved && !screen.changed
                    text: "Use Hyprland's setting"
                    hint: "Forget what Shale kept for this display and reload the Hyprland config"
                    enabled: !root.busy
                    onClicked: root.call("display.reset", {output: screen.display.name})
                }
                C.Button {
                    visible: screen.display.pending === 0 && screen.changed
                    text: "Cancel"
                    flat: true
                    onClicked: screen.reset()
                }
                C.Button {
                    visible: screen.display.pending === 0 && screen.changed
                    text: "Apply"
                    accent: true
                    enabled: !root.busy
                    onClicked: root.call("display.set", {output: screen.display.name, width: screen.chosenWidth, height: screen.chosenHeight, rate: screen.chosenRate, scale: screen.chosenScale},
                                         null)
                }
            }
        }
    }
}
