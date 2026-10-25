import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import "../core"
import "../core/paths.js" as Paths
import "../core/controlItems.js" as ControlItems
import "../services"
import "../components" as C

FocusScope {
    id: root
    readonly property string title: ({wifi: "Network", bluetooth: "Network", audio: "Sound", power: "Battery & power", media: "Player", tray: "System tray", update: "Update", focus: "Focus"})[ShellState.detail] || "Control"
    // Beside the title on the main page: the battery, or the power mode; it opens Battery & power.
    readonly property string headerNote: {
        if (ShellState.detail !== "")
            return "";
        const mode = ({"power-saver": "Power saver", "balanced": "Balanced", "performance": "Performance"})[ShellState.profiles.active] || "";
        if (!Services.batteryAvailable)
            return mode || "Power modes";
        const seconds = Services.batterySeconds;
        const span = seconds <= 0 ? "" : seconds >= 3600 ? Math.floor(seconds / 3600) + " h " + Math.floor(seconds % 3600 / 60) : Math.max(1, Math.floor(seconds / 60)) + " min";
        return "Battery " + Math.round(Services.batteryPercent) + "%" + (Services.batteryCharging ? (span ? " · full in " + span : " · charging") : span ? " · " + span + " left" : "");
    }
    readonly property string noteHint: "Battery and power modes"
    function noteClicked() {
        ShellState.detail = "power";
    }
    readonly property bool canGoBack: ShellState.detail !== ""
    // Settings → Control center orders the tiles and buttons and turns parts off.
    readonly property var arrangement: ControlItems.layout(ShellState.setting("controlLayout", {}))
    readonly property var shownTiles: arrangement.tiles.filter(tile => tile.shown && (tile.id !== "wifi" || ShellState.wifiAvailable)
                                                                        && (tile.id !== "lid" || Backend.capabilities.lid !== false)).map(tile => tile.id)
    // What a tile shows. Wi-Fi and Bluetooth also open their page; the others are plain switches.
    function tile(id) {
        if (id === "wifi") {
            const current = (ShellState.wifi.networks || []).find(n => n.connected);
            return {text: "Wi-Fi", glyph: ShellState.wifi.powered ? "wifi" : "wifi-off", selected: ShellState.wifi.state === "connected",
                    subtitle: root.pendingMethod === "wifi.power" ? "Updating…" : current ? current.name : ShellState.wifi.powered ? "Not connected" : "Off",
                    hint: ShellState.wifi.powered ? "Turn Wi-Fi off" : "Turn Wi-Fi on", detail: "wifi", detailHint: "Wi-Fi networks", enabled: !root.acting};
        }
        if (id === "bluetooth") {
            const connected = Services.bluetoothDevices.filter(d => d.connected);
            const count = connected.length;
            // One device reads as its name and battery; more as a count.
            const one = count === 1 ? (connected[0].name || "1 connected") + (connected[0].batteryAvailable ? " · " + Math.round(connected[0].battery * 100) + "%" : "") : "";
            return {text: "Bluetooth", glyph: "bluetooth", selected: Services.bluetoothEnabled,
                    subtitle: !Services.bluetoothAvailable ? "Unavailable" : one || (count ? count + " connected" : Services.bluetoothEnabled ? "On" : "Off"),
                    hint: Services.bluetoothEnabled ? "Turn Bluetooth off" : "Turn Bluetooth on", detail: "bluetooth", detailHint: "Bluetooth devices",
                    enabled: Services.bluetoothAvailable};
        }
        const toggle = ({
                dnd: {text: "Do not disturb", glyph: "bell-off", on: ShellState.setting("dnd", false), subtitle: "Popups hidden", busy: false},
                awake: {text: "Stay awake", glyph: "moon", on: ShellState.presentation, subtitle: "Screen stays on", busy: false},
                grayscale: {text: "Grayscale", glyph: "palette", on: ShellState.grayscale, subtitle: "Colors off", busy: ShellState.grayscaleBusy},
                lid: {text: "Lid closed", glyph: "laptop", on: ShellState.lidAwake, subtitle: "Stays awake", busy: ShellState.lidBusy}
            })[id];
        return {text: toggle.text, glyph: toggle.glyph, selected: toggle.on, subtitle: toggle.on ? toggle.subtitle : "Off", hint: "",
                detail: "", detailHint: "", enabled: !toggle.busy, switch: true};
    }
    function activateTile(id) {
        if (id === "wifi")
            root.perform("wifi.power", {powered: !ShellState.wifi.powered}, () => ShellState.refreshWifi());
        else if (id === "bluetooth")
            Services.bluetoothPower(!Services.bluetoothEnabled);
        else if (id === "dnd")
            ShellState.setSetting("dnd", !ShellState.setting("dnd", false));
        else if (id === "awake")
            ShellState.presentation = !ShellState.presentation;
        else if (id === "grayscale")
            ShellState.toggleGrayscale();
        else if (id === "lid")
            ShellState.toggleLidAwake();
    }
    function back() {
        ShellState.detail = "";
    }
    // The Player is laid out wider, at its own 460 px, and Focus at 440.
    readonly property int panelWidth: ShellState.detail === "media" ? 460 : ShellState.detail === "focus" ? 440 : 420
    readonly property var headerChip: ShellState.detail === "focus" ? focusView.chip : null
    // Fits the page, header and padding included, within a 620 px ceiling.
    readonly property int panelHeight: preferredContentHeight > 0 ? Math.max(200, Math.min(620, preferredContentHeight + 70)) : 620
    readonly property Component headerTools: ShellState.detail === "" ? settingsTool : ["wifi", "power", "update"].indexOf(ShellState.detail) >= 0 ? refreshTool : null
    // Settings → Control center is one of Settings' pages; this is the way there.
    Component {
        id: settingsTool
        C.Button {
            id: settingsKey
            glyph: "sliders"
            hint: "Settings"
            implicitWidth: 32
            implicitHeight: 32
            background: Rectangle {
                radius: Theme.radiusKey
                color: settingsKey.hovered || settingsKey.down || settingsKey.visualFocus ? Theme.mix(Theme.module, Theme.text, 0.05) : Theme.module
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.fast
                    }
                }
            }
            onClicked: ShellState.open("settings")
        }
    }
    Component {
        id: refreshTool
        C.Button {
            glyph: "refresh"
            flat: true
            hint: "Refresh"
            implicitWidth: 32
            implicitHeight: 32
            enabled: !root.busy && !Updates.checking
            onClicked: root.refresh(true)
        }
    }
    readonly property int preferredContentHeight: Math.ceil(controlContent.implicitHeight + (errorLabel.visible ? errorLabel.implicitHeight + 10 : 0) + (actionFooter.visible ? actionFooter.implicitHeight + 10 : 0))
    property string error: ""
    property bool busy: false
    // Busy with something the user asked for; background list refreshes don't dim the page.
    readonly property bool acting: busy && ["wifi.list", "power.profiles"].indexOf(pendingMethod) < 0
    // The VPN profile being connected or disconnected, while that request runs.
    property string pendingVpn: ""
    property string pendingMethod: ""
    property int requestGeneration: 0
    property bool alive: true
    property var selectedNetwork: null
    // Kept outside the network rows: refreshes recreate them while you type.
    property string passwordDraft: ""
    TrayMenu {
        id: trayMenu
    }
    property bool passwordVisible: false
    // The mixer's device list under its header: "out", "in" or none.
    property string deviceChooser: ""
    // Connected first, then paired, then nearby; nameless discoveries stay folded away.
    property bool showAllDevices: false
    function unnamed(device) {
        const name = device.name || "";
        return !name || /^([0-9a-f]{2}[-:]){5}[0-9a-f]{2}$/i.test(name);
    }
    readonly property var sortedDevices: {
        const rank = device => device.connected ? 0 : device.paired ? 1 : unnamed(device) ? 3 : 2;
        return Services.bluetoothDevices.slice().sort((a, b) => rank(a) - rank(b) || (a.name || "").localeCompare(b.name || ""));
    }
    readonly property int hiddenDevices: sortedDevices.filter(device => !device.paired && !device.connected && unnamed(device)).length
    readonly property var shownDevices: showAllDevices ? sortedDevices : sortedDevices.filter(device => device.paired || device.connected || !unnamed(device))
    readonly property var pairedDevices: sortedDevices.filter(device => device.paired)
    readonly property var nearbyDevices: shownDevices.filter(device => !device.paired)
    readonly property var autoConnectList: ShellState.setting("bluetoothAutoConnect", [])
    property var pairing: null
    // The Wi-Fi network waiting for a confirmation to be forgotten.
    property string forgetPath: ""
    // The device whose options are open, and the connects and disconnects the shell has under way.
    property string expandedDevice: ""
    property var bluetoothWork: ({})
    function setWork(path, kind) {
        const next = Object.assign({}, bluetoothWork);
        if (kind)
            next[path] = kind;
        else
            delete next[path];
        bluetoothWork = next;
    }
    // Tapping a device: connect or disconnect it through the helper (so auto-connect knows), or pair a new one.
    function bluetoothActivate(device) {
        const path = device.dbusPath;
        if (bluetoothWork[path] || !Services.bluetoothEnabled)
            return;
        if (!device.paired) {
            Services.bluetoothScan(false);
            perform("bluetooth.pair", {path: path}, () => {});
            return;
        }
        const kind = device.connected ? "disconnect" : "connect";
        setWork(path, kind);
        error = "";
        Backend.request("bluetooth." + kind, {path: path}, (r, e) => {
            if (!root.alive)
                return;
            root.setWork(path, "");
            if (e && e.code !== "cancelled")
                root.error = e.message;
        });
    }
    function toggleAutoConnect(device) {
        const address = String(device.address).toUpperCase();
        const list = autoConnectList.slice();
        const at = list.indexOf(address);
        if (at >= 0)
            list.splice(at, 1);
        else
            list.push(address);
        ShellState.setSetting("bluetoothAutoConnect", list);
    }
    // Mixer: the app stream played alone, and the mute states it covered, to give back when solo ends.
    property var soloTarget: null
    property var soloSaved: ({})
    function toggleSolo(node) {
        const target = soloTarget;
        restoreSolo();
        if (target === node || !node)
            return;
        const saved = {};
        for (const stream of Services.audioStreams) {
            if (!stream.audio)
                continue;
            saved[stream.id] = stream.audio.muted;
            stream.audio.muted = stream !== node;
        }
        soloSaved = saved;
        soloTarget = node;
    }
    function restoreSolo() {
        if (!soloTarget)
            return;
        for (const stream of Services.audioStreams)
            if (stream.audio && soloSaved[stream.id] !== undefined)
                stream.audio.muted = soloSaved[stream.id];
        soloTarget = null;
        soloSaved = {};
    }
    // Pan of a stereo node from its two channel volumes: -1 (left) … 1 (right). Mono nodes stay centred.
    function balance(node) {
        const levels = node && node.audio ? node.audio.volumes || [] : [];
        if (levels.length !== 2)
            return 0;
        const loudest = Math.max(levels[0], levels[1]);
        return loudest > 0 ? (levels[1] - levels[0]) / loudest : 0;
    }
    // A panned node's level is its louder channel; moving the fader keeps the pan.
    function level(node) {
        if (!node || !node.audio)
            return 0;
        const levels = node.audio.volumes || [];
        return Math.abs(balance(node)) > 0.01 ? Math.max(levels[0], levels[1]) : node.audio.volume;
    }
    function setPanned(node, value, pan) {
        node.audio.volumes = [value * Math.min(1, 1 - pan), value * Math.min(1, 1 + pan)];
    }
    function setLevel(node, value, setter) {
        const pan = balance(node);
        if (Math.abs(pan) > 0.01 && node && node.audio)
            setPanned(node, Math.max(0, Math.min(node === Services.output && ShellState.setting("amplification", false) ? 1.5 : 1, value)), pan);
        else
            setter(value);
    }
    function setBalance(node, pan) {
        if (!node || !node.audio || (node.audio.volumes || []).length !== 2)
            return;
        setPanned(node, level(node), Math.abs(pan) < 0.05 ? 0 : Math.max(-1, Math.min(1, pan)));
    }
    // The power row: Restart asks for a second press; a session action closes the panel first.
    property bool restartArmed: false
    property bool leaving: false
    function endSession(action) {
        if (leaving)
            return;
        leaving = true;
        ShellState.close();
        ShellState.sessionAction(action);
    }
    property real pageProgress: 1
    NumberAnimation {
        id: pageEntrance
        target: root
        property: "pageProgress"
        from: 0
        to: 1
        duration: Theme.enter
        easing.type: Easing.OutCubic
    }
    function perform(method, params, callback) {
        const generation = ++requestGeneration;
        const page = ShellState.detail;
        busy = true;
        pendingMethod = method;
        error = "";
        Backend.request(method, params, (r, e) => {
            if (!root.alive || generation !== root.requestGeneration || page !== ShellState.detail)
                return;
            busy = false;
            pendingMethod = "";
            if (e) {
                if (method !== "power.profiles")
                    error = method === "wifi.list" ? "Wi-Fi service unavailable" : e.message;
            }
            else if (callback)
                callback(r);
        });
    }
    function connectSelected() {
        if (busy || !selectedNetwork)
            return;
        const network = selectedNetwork;
        const secret = passwordDraft;
        passwordDraft = "";
        perform("wifi.connect", {
            path: network.path,
            password: secret
        }, () => {
            selectedNetwork = null;
            refresh();
        });
    }
    function cancelPassword() {
        passwordDraft = "";
        passwordVisible = false;
        selectedNetwork = null;
        if (busy && pendingMethod === "wifi.connect")
            perform("wifi.disconnect", {}, () => refresh());
    }
    // `manual`: the header's refresh button, which may also ask GitHub again (opening the Update page doesn't).
    function refresh(manual) {
        if (busy)
            return;
        if (ShellState.detail === "wifi") {
            perform("wifi.list", {}, r => ShellState.wifi = r);
            ShellState.refreshVpn();
        }
        if (ShellState.detail === "power")
            perform("power.profiles", {}, r => ShellState.profiles = r);
        if (ShellState.detail === "update")
            Updates.refresh(manual === true);
    }
    Component.onCompleted: {
        refresh();
        ShellState.run("display.lid.get", {}, r => ShellState.lidAwake = r.enabled);
        ShellState.run("display.grayscale.get", {}, r => ShellState.grayscale = r.enabled);
        if (ShellState.detail !== "wifi")
            ShellState.refreshWifi();
        ShellState.run("brightness.get", {}, r => ShellState.brightness = r.available ? r.value : -1);
    }
    Component.onDestruction: {
        restoreSolo();
        alive = false;
        requestGeneration++;
        Services.bluetoothScan(false);
        Backend.request("bluetooth.reply", {
            accept: false
        });
    }
    Connections {
        target: ShellState
        function onDetailChanged() {
            pageEntrance.restart();
            root.requestGeneration++;
            root.busy = false;
            root.pendingMethod = "";
            root.error = "";
            root.selectedNetwork = null;
            root.forgetPath = "";
            root.expandedDevice = "";
            root.passwordDraft = "";
            root.passwordVisible = false;
            root.showAllDevices = false;
            root.restartArmed = false;
            root.deviceChooser = "";
            root.restoreSolo();
            scanWait.stop();
            if (root.pairing && ShellState.detail !== "bluetooth") {
                Backend.request("bluetooth.reply", { accept: false });
                root.pairing = null;
                pin.clear();
            }
            root.refresh();
            if (ShellState.detail !== "bluetooth")
                Services.bluetoothScan(false);
        }
    }
    Connections {
        target: Backend
        function onReadyChanged() {
            if (Backend.ready) root.refresh();
        }
        function onEventReceived(name, data) {
            if (name === "bluetooth.prompt") {
                if (ShellState.detail === "bluetooth")
                    root.pairing = data;
                else
                    Backend.request("bluetooth.reply", { accept: false });
            }
        }
    }
    Timer {
        interval: 5000
        running: ShellState.detail === "wifi" && !root.busy && !root.selectedNetwork
        repeat: true
        onTriggered: root.refresh()
    }
    // Sink names read as their kind of device: HDMI and DisplayPort, headphones, otherwise speakers.
    function outputGlyph(name) {
        return /hdmi|displayport/i.test(name) ? "hdmi" : /head(phone|set)|earbud|earphone|airpods|buds/i.test(name) ? "headphones" : "speaker";
    }
    function outputName(node) {
        const name = node.description || node.nickname || node.name || "";
        return name.replace(/\s+(analog|digital) (stereo|surround|mono).*$/i, "").replace(/^built-in audio$/i, "Speakers") || name;
    }
    function streamName(node) {
        return node.properties && node.properties["application.name"] || node.description || node.name;
    }
    // Wi-Fi strength as lit arcs: 1 (the dot only) to 4.
    function signalBars(signal) {
        return signal >= 67 ? 4 : signal >= 45 ? 3 : signal >= 25 ? 2 : 1;
    }
    // The whole output's loudness from the shared cava levels while the mixer shows (0 … 1). Apps have no level of
    // their own, so their meters show the output level scaled by their volume; the microphone has none.
    C.Spectrum {
        id: outputLevel
        visible: false
        bars: 1
        active: ShellState.detail === "audio" && Services.audioAvailable && ShellState.setting("visualizer", true) && !Theme.reduced && !Theme.lowPower
        readonly property real level: Services.muted ? 0 : Math.min(1, (outputLevel.levels[0] || 0) / 1000)
    }

    // A module's title row: title and a quiet note, then whatever controls it holds.
    component ModuleHeader: RowLayout {
        id: moduleHeader
        property string title: ""
        property string note: ""
        property bool large: false
        property bool noteRight: false
        Layout.fillWidth: true
        Layout.minimumHeight: 28
        spacing: Theme.gapS
        C.Label {
            text: moduleHeader.title
            font.pixelSize: moduleHeader.large ? 15 : 14
            font.weight: moduleHeader.large ? 650 : Font.DemiBold
            elide: Text.ElideNone
        }
        C.Label {
            text: moduleHeader.note
            color: Theme.textDim
            font.pixelSize: 12
            horizontalAlignment: moduleHeader.noteRight ? Text.AlignRight : Text.AlignLeft
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.leftMargin: 2
        }
    }
    // A 28 px key inside modules (Scan, Forget, +5 min).
    component SmallKey: C.Button {
        id: smallKey
        property color rest: Theme.key
        implicitHeight: 28
        leftPadding: 10
        rightPadding: 10
        topPadding: 0
        bottomPadding: 0
        labelSize: 12
        cornerRadius: 8
        background: Rectangle {
            radius: smallKey.cornerRadius
            color: !smallKey.enabled ? Theme.key : smallKey.accent ? (smallKey.hovered || smallKey.down ? Theme.accentHover : Theme.accent) : smallKey.rest
            Behavior on color {
                ColorAnimation {
                    duration: Theme.fast
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                visible: !smallKey.accent
                color: smallKey.wash
                opacity: smallKey.enabled && (smallKey.hovered || smallKey.down || smallKey.visualFocus) ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fast
                    }
                }
            }
        }
    }
    // A 44 px key in the power row.
    component PowerKey: C.Button {
        id: powerKey
        implicitHeight: 44
        labelSize: 13
        cornerRadius: Theme.radiusCard
        background: Rectangle {
            radius: powerKey.cornerRadius
            color: powerKey.selected ? Theme.accentSoft : powerKey.hovered || powerKey.down || powerKey.visualFocus ? Theme.mix(Theme.module, Theme.text, 0.05) : Theme.module
            border.width: powerKey.selected ? 1 : 0
            border.color: Theme.accentLine
            Behavior on color {
                ColorAnimation {
                    duration: Theme.fast
                }
            }
        }
    }
    // Three small bars beside the chosen output; they move while something plays, and rest under reduced motion
    // or power saving.
    component LevelBars: Row {
        id: levelBars
        property bool live: false
        spacing: 2
        height: 14
        Repeater {
            model: [0.55, 0.9, 0.7]
            Rectangle {
                id: levelBar
                required property real modelData
                required property int index
                property real level: modelData
                anchors.bottom: parent.bottom
                width: 3
                height: Math.max(3, 14 * level)
                radius: 1
                color: Theme.accent
                SequentialAnimation on level {
                    running: levelBars.live && levelBars.visible && !Theme.reduced && !Theme.lowPower
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) levelBar.level = levelBar.modelData
                    NumberAnimation { to: 0.25; duration: 240 + levelBar.index * 60; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.9; duration: 300 + levelBar.index * 40; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.45; duration: 220 + levelBar.index * 50; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 280; easing.type: Easing.InOutSine }
                }
            }
        }
    }
    // One output device: icon, name, and the live bars when it is the one playing.
    component OutputKey: C.Button {
        id: outputKey
        required property var modelData
        readonly property string name: root.outputName(modelData)
        selected: modelData === Services.output
        implicitHeight: 36
        leftPadding: 10
        rightPadding: 10
        cornerRadius: Theme.radiusCard
        hint: modelData.description || name
        foreground: selected ? Theme.text : Theme.textSecondary
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Accessible.name: name
        Accessible.role: Accessible.RadioButton
        Accessible.checkable: true
        Accessible.checked: selected
        onClicked: Services.setOutput(modelData)
        background: Rectangle {
            radius: outputKey.cornerRadius
            color: outputKey.selected ? Theme.accentSoft : outputKey.hovered || outputKey.down || outputKey.visualFocus ? Theme.mix(Theme.well, Theme.text, 0.05) : Theme.well
            border.width: 1
            border.color: outputKey.selected ? Theme.accentLine : "transparent"
            Behavior on color {
                ColorAnimation {
                    duration: Theme.fast
                }
            }
        }
        contentItem: RowLayout {
            spacing: Theme.gapS
            C.Icon {
                name: root.outputGlyph(outputKey.modelData.description || outputKey.name)
                size: 17
                color: outputKey.foreground
            }
            C.Label {
                text: outputKey.name
                color: outputKey.foreground
                font.pixelSize: 13
                font.weight: Font.DemiBold
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }
            LevelBars {
                visible: outputKey.selected
                live: NowPlaying.playing && !Services.muted
            }
        }
    }
    // An app's level on the main page: name, a slim track, the value.
    component AppLevel: RowLayout {
        id: appLevel
        required property var modelData
        Layout.fillWidth: true
        Layout.preferredHeight: 26
        spacing: 10
        C.Label {
            text: root.streamName(appLevel.modelData)
            color: Theme.textSecondary
            font.pixelSize: 13
            Layout.preferredWidth: 74
        }
        Slider {
            id: appSlider
            Layout.fillWidth: true
            implicitHeight: 26
            padding: 0
            from: 0
            to: 1
            stepSize: 0.01
            value: root.level(appLevel.modelData)
            wheelEnabled: true
            enabled: !!appLevel.modelData.audio
            Accessible.name: root.streamName(appLevel.modelData) + " volume"
            onMoved: root.setLevel(appLevel.modelData, value, v => Services.setStreamVolume(appLevel.modelData, v))
            background: Rectangle {
                y: (appSlider.height - height) / 2
                width: appSlider.width
                height: 4
                radius: 2
                color: Theme.key
                Rectangle {
                    width: appSlider.visualPosition * parent.width
                    height: parent.height
                    radius: 2
                    color: Theme.textDim
                }
            }
            handle: Rectangle {
                x: appSlider.visualPosition * (appSlider.availableWidth - width)
                y: (appSlider.height - height) / 2
                width: appSlider.pressed ? 14 : 12
                height: width
                radius: width / 2
                color: Theme.textSecondary
                C.FocusRing {
                    visible: appSlider.visualFocus
                    inset: 4
                }
            }
        }
        C.Label {
            text: appLevel.modelData.audio && appLevel.modelData.audio.muted ? "Off" : String(Math.round(appSlider.value * 100))
            color: Theme.textDim
            font.family: Theme.mono
            font.pixelSize: 12
            font.features: {"tnum": 1}
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 34
        }
    }
    // One arc of the Wi-Fi strength glyph, in the icon set's 24-unit box.
    component SignalArc: ShapePath {
        id: arc
        property string d: ""
        property bool lit: true
        property color color: Theme.text
        scale: Qt.size(18 / 24, 18 / 24)
        strokeWidth: 1.5
        strokeColor: lit ? color : Theme.mix(Theme.module, Theme.text, 0.18)
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathSvg { path: arc.d }
    }
    component SignalIcon: Shape {
        id: signalIcon
        property int bars: 4
        property color color: Theme.text
        implicitWidth: 18
        implicitHeight: 18
        preferredRendererType: Shape.CurveRenderer
        SignalArc { d: "M4 9.5a12 12 0 0 1 16 0"; lit: signalIcon.bars >= 4; color: signalIcon.color }
        SignalArc { d: "M7 13a7.5 7.5 0 0 1 10 0"; lit: signalIcon.bars >= 3; color: signalIcon.color }
        SignalArc { d: "M10 16.5a3 3 0 0 1 4 0"; lit: signalIcon.bars >= 2; color: signalIcon.color }
        SignalArc { d: "M12 19.5h.01"; color: signalIcon.color }
    }
    // M and S on a channel strip.
    component StripKey: C.Button {
        id: stripKey
        property color onColor: Theme.accentSoft
        property color onText: Theme.accentText
        implicitWidth: 26
        implicitHeight: 22
        padding: 0
        labelSize: 11
        cornerRadius: 6
        foreground: selected ? onText : Theme.textMuted
        Accessible.role: Accessible.CheckBox
        Accessible.checkable: true
        Accessible.checked: selected
        background: Rectangle {
            radius: stripKey.cornerRadius
            color: stripKey.selected ? stripKey.onColor : stripKey.hovered || stripKey.down || stripKey.visualFocus ? Theme.keyHover : Theme.keyTile
            Behavior on color {
                ColorAnimation {
                    duration: Theme.fast
                }
            }
        }
    }
    // One mixer channel: colour tag, name, pan ring, stereo meters beside the fader, level, then M and S.
    component Strip: Rectangle {
        id: strip
        property string title: ""
        property color tag: Theme.key
        property color fillColor: Theme.textDim
        property color meterColor: Theme.accent
        property real value: 0
        property real maximum: 1
        property bool muted: false
        property bool soloable: false
        property bool soloed: false
        // Muted, or silenced by another channel's solo.
        property bool silent: muted
        property real meter: 0
        property real pan: 0
        property bool pannable: false
        signal moved(real value)
        signal muteClicked()
        signal soloClicked()
        signal panMoved(real pan)
        implicitWidth: 72
        radius: Theme.radiusCard
        color: Theme.moduleAlt
        // The tag follows the strip's rounded top: the top 3 px of a rounded shape the strip's size.
        Item {
            width: parent.width
            height: 3
            clip: true
            Rectangle {
                width: strip.width
                height: strip.height
                radius: strip.radius
                color: strip.tag
            }
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 11
            anchors.bottomMargin: 8
            spacing: Theme.gapS
            C.Label {
                text: strip.title
                font.pixelSize: 12
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 64
            }
            // Pan: drag sideways or scroll; a double-click centres it.
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 30
                implicitHeight: 30
                opacity: strip.pannable ? 1 : 0.5
                Accessible.name: strip.title + " pan"
                C.Ring {
                    anchors.fill: parent
                    size: 30
                    thickness: 3
                    span: 130
                    value: strip.pan
                    color: Theme.textSecondary
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 4
                    height: 4
                    radius: 2
                    color: Theme.textDim
                }
                MouseArea {
                    property real startX: 0
                    property real startPan: 0
                    anchors.fill: parent
                    enabled: strip.pannable
                    cursorShape: Qt.SizeHorCursor
                    onPressed: mouse => {
                        startX = mouse.x;
                        startPan = strip.pan;
                    }
                    onPositionChanged: mouse => {
                        if (pressed)
                            strip.panMoved(startPan + (mouse.x - startX) / 40);
                    }
                    onDoubleClicked: strip.panMoved(0)
                    onWheel: wheel => strip.panMoved(strip.pan + (wheel.angleDelta.y > 0 ? 0.1 : -0.1))
                }
            }
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: true
                Layout.minimumHeight: 80
                implicitWidth: 56
                Repeater {
                    // Left and right; the right one trails a little so the pair reads as stereo.
                    model: [6, 12]
                    Rectangle {
                        required property real modelData
                        required property int index
                        x: modelData
                        width: 4
                        height: parent.height
                        radius: 2
                        color: Theme.mix(Theme.backdrop, Qt.rgba(0, 0, 0, 1), 0.2)
                        clip: true
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: parent.height * (strip.silent ? 0 : strip.meter * (index ? 0.94 : 1))
                            gradient: Gradient {
                                GradientStop { position: 0; color: strip.meterColor }
                                GradientStop { position: 1; color: Theme.accentSoft }
                            }
                            Behavior on height {
                                NumberAnimation {
                                    duration: Theme.reduced ? 0 : 120
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }
                    }
                }
                Slider {
                    id: fader
                    x: 22
                    width: 24
                    height: parent.height
                    orientation: Qt.Vertical
                    padding: 0
                    topPadding: 7
                    bottomPadding: 7
                    from: 0
                    to: strip.maximum
                    stepSize: 0.01
                    value: strip.value
                    wheelEnabled: true
                    Accessible.name: strip.title + " volume"
                    onMoved: strip.moved(value)
                    background: Item {
                        Rectangle {
                            x: (fader.width - width) / 2
                            y: fader.topPadding
                            width: 2
                            height: fader.availableHeight
                            radius: 1
                            color: Theme.key
                        }
                        Rectangle {
                            x: (fader.width - width) / 2
                            y: fader.topPadding + fader.visualPosition * fader.availableHeight
                            width: 2
                            height: (1 - fader.visualPosition) * fader.availableHeight
                            radius: 1
                            color: strip.silent ? Theme.textFaint : strip.fillColor
                        }
                    }
                    handle: Rectangle {
                        x: (fader.width - width) / 2
                        y: fader.topPadding + fader.visualPosition * fader.availableHeight - height / 2
                        width: 24
                        height: 14
                        radius: 4
                        color: Theme.knob
                        Rectangle {
                            anchors.centerIn: parent
                            width: 14
                            height: 2
                            radius: 1
                            color: Theme.accentInk
                        }
                        C.FocusRing {
                            visible: fader.visualFocus
                            inset: 3
                            radius: 7
                        }
                    }
                }
            }
            C.Label {
                text: strip.muted ? "Off" : String(Math.round((fader.pressed ? fader.value : strip.value) * 100))
                color: strip.silent ? Theme.textFaint : Theme.textSecondary
                font.family: Theme.mono
                font.pixelSize: 11
                font.features: {"tnum": 1}
                Layout.alignment: Qt.AlignHCenter
            }
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4
                StripKey {
                    text: "M"
                    hint: (strip.muted ? "Unmute " : "Mute ") + strip.title
                    selected: strip.muted
                    onColor: Theme.tint(Theme.danger, 0.2)
                    onText: Theme.dangerText
                    onClicked: strip.muteClicked()
                }
                StripKey {
                    visible: strip.soloable
                    text: "S"
                    hint: strip.soloed ? "Stop playing " + strip.title + " alone" : "Play only " + strip.title
                    selected: strip.soloed
                    onClicked: strip.soloClicked()
                }
            }
        }
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        C.Label {
            id: errorLabel
            visible: root.error !== ""
            text: root.error
            color: Theme.dangerText
            font.pixelSize: Theme.small
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        ScrollView {
            id: controlScroll
            ScrollBar.vertical: C.ScrollBar {
                parent: controlScroll
                x: controlScroll.width - width
                y: controlScroll.topPadding
                height: controlScroll.availableHeight
            }
            opacity: root.pageProgress
            transform: Translate {
                x: Theme.reduced ? 0 : (1 - root.pageProgress) * 6
            }
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            Layout.preferredHeight: 0
            contentWidth: availableWidth
            clip: true
            ColumnLayout {
                id: controlContent
                width: controlScroll.availableWidth
                spacing: Theme.gapS
                ColumnLayout {
                    visible: ShellState.detail === ""
                    Layout.fillWidth: true
                    spacing: Theme.gapS
                    // A newer Shale, or what the last update brought: the page behind the arrow lists the changes.
                    C.ListRow {
                        visible: Updates.available || !!Updates.recent
                        Layout.fillWidth: true
                        text: Updates.available ? "Update available" : "Updated to " + Updates.installed
                        subtitle: Updates.available ? Updates.installed + " → " + Updates.latest + " · " + Updates.changes(Updates.count) : "See what changed"
                        glyph: "update"
                        positive: true
                        checkmark: false
                        hint: "What changed"
                        onClicked: ShellState.detail = "update"
                        trailing: C.Icon { name: "chevron"; color: Theme.textDim; Layout.rightMargin: 4 }
                    }
                    // Every tile here is an on/off switch; Wi-Fi and Bluetooth open their page from the arrow.
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: Theme.gapS
                        columnSpacing: Theme.gapS
                        Repeater {
                            model: root.shownTiles
                            C.QuickTile {
                                id: quickTile
                                required property string modelData
                                readonly property var info: root.tile(modelData)
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: Math.max(60, Theme.body * 4.2)
                                text: info.text
                                glyph: info.glyph
                                selected: info.selected
                                subtitle: info.subtitle
                                hint: info.hint
                                detailHint: info.detailHint
                                enabled: info.enabled
                                Accessible.role: info.switch ? Accessible.CheckBox : Accessible.Button
                                Accessible.checkable: !!info.switch
                                Accessible.checked: !!info.switch && selected
                                onClicked: root.activateTile(modelData)
                                onDetailRequested: ShellState.detail = quickTile.info.detail
                            }
                        }
                    }
                    // Volume (with its glow), microphone and brightness; each icon mutes, the arrow opens the mixer.
                    C.Card {
                        visible: root.arrangement.sections.levels
                        Layout.fillWidth: true
                        implicitHeight: levelRows.implicitHeight + 20
                        ColumnLayout {
                            id: levelRows
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            anchors.topMargin: 10
                            anchors.bottomMargin: 10
                            spacing: 6
                            C.SliderRow {
                                Layout.fillWidth: true
                                title: "Volume"
                                showTitle: false
                                glow: true
                                muteable: true
                                muted: Services.muted
                                onIconClicked: Services.toggleMute()
                                value: Services.volume
                                maximum: ShellState.setting("amplification", false) ? 1.5 : 1
                                enabled: Services.audioAvailable
                                detailHint: "Mixer"
                                onDetailRequested: ShellState.detail = "audio"
                                onMoved: value => Services.setVolume(value)
                            }
                            C.SliderRow {
                                Layout.fillWidth: true
                                visible: Services.audioAvailable && !!Services.input
                                title: "Microphone"
                                showTitle: false
                                glyph: "mic"
                                mutedGlyph: "mic-off"
                                muteable: true
                                muted: Services.micMuted
                                onIconClicked: Services.toggleMicMute()
                                value: Services.micVolume
                                onMoved: value => Services.setMicVolume(value)
                            }
                            C.SliderRow {
                                Layout.fillWidth: true
                                title: "Brightness"
                                showTitle: false
                                glyph: "sun"
                                // Desktops have no backlight; setting it needs brightnessctl.
                                visible: ShellState.brightness >= 0 && Backend.has("brightnessctl", true)
                                value: Math.max(0, ShellState.brightness)
                                onMoved: value => {
                                    ShellState.brightness = value;
                                    brightnessDebounce.restart();
                                }
                            }
                        }
                    }
                    // The real sinks; the chosen one shows live bars. Apps playing now follow it and have their own levels.
                    C.Card {
                        visible: root.arrangement.sections.levels && Services.audioAvailable && Services.audioOutputs.length > 0
                        Layout.fillWidth: true
                        implicitHeight: outputModule.implicitHeight + 20
                        ColumnLayout {
                            id: outputModule
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            anchors.topMargin: 10
                            anchors.bottomMargin: 10
                            spacing: 10
                            ModuleHeader {
                                title: "Output"
                                note: "playing apps follow"
                                Layout.minimumHeight: 0
                            }
                            GridLayout {
                                Layout.fillWidth: true
                                columns: Math.max(1, Math.min(3, Services.audioOutputs.length))
                                rowSpacing: 6
                                columnSpacing: 6
                                Accessible.role: Accessible.Grouping
                                Accessible.name: "Sound output"
                                Repeater {
                                    model: Services.audioOutputs
                                    OutputKey {}
                                }
                            }
                            Repeater {
                                model: Services.audioStreams
                                AppLevel {}
                            }
                        }
                    }
                    // A focus session: popups held, a ring in the bar, then one digest of what came in.
                    C.Card {
                        visible: root.arrangement.sections.focus
                        Layout.fillWidth: true
                        implicitHeight: focusModule.implicitHeight + 20
                        // Title and state on the left, the lengths on the right, in one line.
                        RowLayout {
                            id: focusModule
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            anchors.topMargin: 10
                            anchors.bottomMargin: 10
                            spacing: Theme.gapS
                            // The name and state open the Focus page: its ring, Pause, and what came in.
                            C.Button {
                                id: focusOpen
                                flat: true
                                hint: "Focus page"
                                Accessible.name: "Focus, " + focusState.text
                                Layout.fillWidth: true
                                Layout.leftMargin: -6
                                implicitHeight: 40
                                leftPadding: 6
                                rightPadding: 6
                                onClicked: ShellState.detail = "focus"
                                contentItem: RowLayout {
                                    spacing: 6
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        C.Label {
                                            text: "Focus"
                                            font.weight: Font.DemiBold
                                            Layout.fillWidth: true
                                        }
                                        C.Label {
                                            id: focusState
                                            text: Focus.paused ? "paused · " + Focus.minutesText(Focus.remainingSeconds) + " left" : Focus.active ? Focus.minutesText(Focus.remainingSeconds) + " left · held" : "not running"
                                            color: Theme.textDim
                                            font.pixelSize: 12
                                            Layout.fillWidth: true
                                        }
                                    }
                                    C.Icon {
                                        name: "chevron"
                                        size: 14
                                        color: focusOpen.hovered || focusOpen.visualFocus ? Theme.textSecondary : Theme.textDim
                                    }
                                }
                            }
                            SmallKey {
                                visible: Focus.active
                                text: "+5"
                                hint: "Five more minutes"
                                onClicked: Focus.extend(5)
                            }
                            C.Segmented {
                                fill: false
                                trackColor: Theme.well
                                segmentHeight: 32
                                model: [{key: 0, text: "Off", hint: "No focus session"}, {key: 25, text: "25", hint: "Focus for 25 minutes"},
                                        {key: 50, text: "50", hint: "Focus for 50 minutes"}, {key: 90, text: "90", hint: "Focus for 90 minutes"}]
                                current: Focus.active ? Focus.lastMinutes : 0
                                onActivated: key => key === 0 ? Focus.end(true) : Focus.start(key)
                            }
                        }
                    }
                    C.ListRow {
                        visible: root.arrangement.sections.media
                        Layout.fillWidth: true
                        text: Services.player ? (Services.player.trackTitle || "Now playing") : "Nothing playing"
                        subtitle: Services.player ? (Services.player.trackArtist || Services.player.identity) : "Player"
                        glyph: "music"
                        hint: "Player"
                        onClicked: ShellState.detail = "media"
                        trailing: C.Button {
                            implicitWidth: 36
                            implicitHeight: 36
                            glyph: Services.player && Services.player.isPlaying ? "pause" : "play"
                            hint: Services.player && Services.player.isPlaying ? "Pause" : "Play"
                            accent: true
                            enabled: !!Services.player && Services.player.canTogglePlaying
                            onClicked: Services.player.togglePlaying()
                        }
                    }
                }
                // The mixer: channel strips for the output, each app and the microphone (scrolling sideways when
                // there are many), then the equalizer.
                ColumnLayout {
                    visible: ShellState.detail === "audio"
                    Layout.fillWidth: true
                    spacing: Theme.gapS
                    C.StatusCard {
                        visible: !Services.audioAvailable
                        Layout.fillWidth: true
                        glyph: "volume"
                        title: "Audio unavailable"
                        subtitle: "No output device or audio service"
                    }
                    ColumnLayout {
                        visible: Services.audioAvailable
                        Layout.fillWidth: true
                        spacing: Theme.gapS
                        C.Card {
                            Layout.fillWidth: true
                            implicitHeight: mixer.implicitHeight + 24
                            ColumnLayout {
                                id: mixer
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10
                                // The devices in use; each chip opens the list to pick another.
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.gapS
                                    C.Label {
                                        text: "Mixer"
                                        font.pixelSize: 15
                                        font.weight: 650
                                        elide: Text.ElideNone
                                    }
                                    C.Chip {
                                        text: "Out · " + (Services.output ? root.outputName(Services.output) : "none")
                                        hint: "Choose the output"
                                        rest: Theme.well
                                        implicitHeight: 24
                                        selected: root.deviceChooser === "out"
                                        Layout.maximumWidth: 180
                                        onClicked: root.deviceChooser = root.deviceChooser === "out" ? "" : "out"
                                    }
                                    C.Chip {
                                        visible: Services.audioInputs.length > 0
                                        text: "In · " + (Services.input ? root.outputName(Services.input) : "none")
                                        hint: "Choose the microphone"
                                        rest: Theme.well
                                        implicitHeight: 24
                                        selected: root.deviceChooser === "in"
                                        Layout.maximumWidth: 160
                                        onClicked: root.deviceChooser = root.deviceChooser === "in" ? "" : "in"
                                    }
                                    Item {
                                        Layout.fillWidth: true
                                    }
                                }
                                Flow {
                                    visible: root.deviceChooser !== ""
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Repeater {
                                        model: root.deviceChooser === "out" ? Services.audioOutputs : root.deviceChooser === "in" ? Services.audioInputs : []
                                        C.Chip {
                                            required property var modelData
                                            text: modelData.description || modelData.name
                                            glyph: root.deviceChooser === "in" ? "mic" : root.outputGlyph(text)
                                            rest: Theme.key
                                            selected: modelData === (root.deviceChooser === "in" ? Services.input : Services.output)
                                            Accessible.role: Accessible.RadioButton
                                            Accessible.checkable: true
                                            Accessible.checked: selected
                                            onClicked: {
                                                if (root.deviceChooser === "in")
                                                    Services.setInput(modelData);
                                                else
                                                    Services.setOutput(modelData);
                                                root.deviceChooser = "";
                                            }
                                        }
                                    }
                                }
                                Flickable {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 236
                                    contentWidth: strips.implicitWidth
                                    contentHeight: height
                                    flickableDirection: Flickable.HorizontalFlick
                                    boundsBehavior: Flickable.StopAtBounds
                                    clip: true
                                    Row {
                                        id: strips
                                        height: parent.height
                                        spacing: 6
                                        Strip {
                                            height: strips.height
                                            title: "Master"
                                            tag: Theme.accent
                                            fillColor: Theme.accent
                                            value: root.level(Services.output)
                                            maximum: ShellState.setting("amplification", false) ? 1.5 : 1
                                            muted: Services.muted
                                            meter: outputLevel.level
                                            pan: root.balance(Services.output)
                                            pannable: !!Services.output && !!Services.output.audio && (Services.output.audio.volumes || []).length === 2
                                            onMoved: value => root.setLevel(Services.output, value, v => Services.setVolume(v))
                                            onMuteClicked: Services.toggleMute()
                                            onPanMoved: pan => root.setBalance(Services.output, pan)
                                        }
                                        Repeater {
                                            model: Services.audioStreams
                                            Strip {
                                                required property var modelData
                                                readonly property bool shut: !!modelData.audio && modelData.audio.muted
                                                height: strips.height
                                                title: root.streamName(modelData)
                                                tag: Theme.mix(Theme.moduleAlt, Theme.text, 0.25)
                                                value: root.level(modelData)
                                                muted: shut
                                                silent: shut || (!!root.soloTarget && root.soloTarget !== modelData)
                                                soloable: true
                                                soloed: root.soloTarget === modelData
                                                meter: outputLevel.level * Math.min(1, root.level(modelData))
                                                pan: root.balance(modelData)
                                                pannable: !!modelData.audio && (modelData.audio.volumes || []).length === 2
                                                enabled: !!modelData.audio
                                                onMoved: value => root.setLevel(modelData, value, v => Services.setStreamVolume(modelData, v))
                                                onMuteClicked: if (modelData.audio) modelData.audio.muted = !modelData.audio.muted
                                                onSoloClicked: root.toggleSolo(modelData)
                                                onPanMoved: pan => root.setBalance(modelData, pan)
                                            }
                                        }
                                        Strip {
                                            visible: !!Services.input
                                            height: strips.height
                                            title: "Mic"
                                            tag: Theme.textSecondary
                                            fillColor: Theme.textSecondary
                                            meterColor: Theme.textSecondary
                                            value: root.level(Services.input)
                                            muted: Services.micMuted
                                            pan: root.balance(Services.input)
                                            pannable: !!Services.input && !!Services.input.audio && (Services.input.audio.volumes || []).length === 2
                                            onMoved: value => root.setLevel(Services.input, value, v => Services.setMicVolume(v))
                                            onMuteClicked: Services.toggleMicMute()
                                            onPanMoved: pan => root.setBalance(Services.input, pan)
                                        }
                                    }
                                }
                                C.Caption {
                                    visible: Services.audioStreams.length === 0
                                    text: "Apps get a strip of their own while they play"
                                    Layout.fillWidth: true
                                }
                            }
                        }
                        Equalizer {
                            Layout.fillWidth: true
                            graphHeight: 130
                            active: ShellState.detail === "audio"
                        }
                    }
                }
                // Network · Wi-Fi: the switch, the current network as an "on" card, then the others by strength.
                C.EmptyState {
                    visible: ShellState.detail === "wifi" && !ShellState.wifiAvailable
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.gapL
                    glyph: "wifi-off"
                    title: "Wi-Fi isn't managed here"
                    description: (ShellState.wifi.reason || "") + " Shale controls Wi-Fi through NetworkManager."
                }
                C.Card {
                    id: wifiModule
                    readonly property var networks: ShellState.wifi.powered ? ShellState.wifi.networks || [] : []
                    readonly property var current: networks.find(n => n.connected) || null
                    visible: ShellState.detail === "wifi" && ShellState.wifiAvailable
                    Layout.fillWidth: true
                    implicitHeight: wifiColumn.implicitHeight + 24
                    ColumnLayout {
                        id: wifiColumn
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6
                        ModuleHeader {
                            title: "Wi-Fi"
                            large: true
                            note: !ShellState.wifi.powered ? "off" : root.pendingMethod === "wifi.power" ? "updating…"
                                  : wifiModule.networks.length ? wifiModule.networks.length + (wifiModule.networks.length === 1 ? " network nearby" : " networks nearby")
                                  : root.busy ? "looking for networks…" : "no networks found"
                            Layout.leftMargin: 2
                            Layout.bottomMargin: 4
                            SmallKey {
                                visible: ShellState.wifi.powered
                                text: root.pendingMethod === "wifi.scan" || scanWait.running ? "Scanning…" : "Scan"
                                hint: "Look for networks again"
                                enabled: !root.acting && !scanWait.running
                                onClicked: root.perform("wifi.scan", {}, () => scanWait.restart())
                            }
                            C.Switch {
                                hint: ShellState.wifi.powered ? "Turn Wi-Fi off" : "Turn Wi-Fi on"
                                selected: ShellState.wifi.powered
                                enabled: !root.acting
                                onClicked: root.perform("wifi.power", {powered: !ShellState.wifi.powered}, () => root.refresh())
                            }
                        }
                        // The network in use: a filled accent tile, its signal, Disconnect and Forget.
                        Rectangle {
                            visible: !!wifiModule.current
                            Layout.fillWidth: true
                            implicitHeight: currentColumn.implicitHeight + 24
                            radius: Theme.radiusCard
                            color: Theme.accentSoft
                            border.width: 1
                            border.color: Theme.accentLine
                            ColumnLayout {
                                id: currentColumn
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.gapM
                                    C.GlyphTile {
                                        size: 36
                                        glyph: "wifi"
                                        selected: true
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        C.Label {
                                            text: wifiModule.current ? wifiModule.current.name : ""
                                            font.weight: Font.DemiBold
                                            Layout.fillWidth: true
                                        }
                                        C.Label {
                                            text: wifiModule.current ? "Connected · " + Math.round(wifiModule.current.signal) + "% signal" : ""
                                            color: Theme.mix(Theme.textSecondary, Theme.text, 0.4)
                                            font.pixelSize: 12
                                            Layout.fillWidth: true
                                        }
                                    }
                                    SmallKey {
                                        text: "Disconnect"
                                        rest: Qt.rgba(0, 0, 0, 0.25)
                                        enabled: !root.acting
                                        onClicked: root.perform("wifi.disconnect", {}, () => root.refresh())
                                    }
                                    SmallKey {
                                        text: "Forget"
                                        hint: "Forget this network"
                                        rest: Qt.rgba(0, 0, 0, 0.25)
                                        enabled: !root.acting
                                        onClicked: root.forgetPath = wifiModule.current.path
                                    }
                                }
                                RowLayout {
                                    visible: !!wifiModule.current && root.forgetPath === wifiModule.current.path
                                    Layout.fillWidth: true
                                    spacing: Theme.gapS
                                    C.Label {
                                        text: "Forget saved credentials?"
                                        font.pixelSize: Theme.small
                                        Layout.fillWidth: true
                                    }
                                    SmallKey {
                                        text: "Cancel"
                                        rest: Qt.rgba(0, 0, 0, 0.25)
                                        onClicked: root.forgetPath = ""
                                    }
                                    C.Button {
                                        text: "Forget"
                                        danger: true
                                        implicitHeight: 28
                                        onClicked: root.perform("wifi.forget", {path: wifiModule.current.path}, () => {
                                            root.forgetPath = "";
                                            root.refresh();
                                        })
                                    }
                                }
                            }
                        }
                        Repeater {
                            model: wifiModule.networks.filter(n => !n.connected)
                            Rectangle {
                                id: networkRow
                                required property var modelData
                                readonly property bool secured: modelData.type !== "open"
                                readonly property bool asking: !!root.selectedNetwork && root.selectedNetwork.path === modelData.path
                                Layout.fillWidth: true
                                implicitHeight: networkColumn.implicitHeight
                                radius: Theme.radiusKey
                                color: asking ? Theme.mix(Theme.module, Theme.text, 0.04) : "transparent"
                                ColumnLayout {
                                    id: networkColumn
                                    width: parent.width
                                    spacing: 0
                                    C.Button {
                                        id: networkKey
                                        Layout.fillWidth: true
                                        implicitHeight: 42
                                        leftPadding: 10
                                        rightPadding: 6
                                        cornerRadius: Theme.radiusKey
                                        hint: networkRow.modelData.name
                                        enabled: !root.acting
                                        Accessible.name: networkRow.modelData.name + (networkRow.secured ? ", secured" : ", open") + ", " + Math.round(networkRow.modelData.signal) + "% signal"
                                        onClicked: {
                                            const network = networkRow.modelData;
                                            if (networkRow.asking)
                                                root.cancelPassword();
                                            else if (!networkRow.secured || network.saved)
                                                root.perform("wifi.connect", {path: network.path}, () => root.refresh());
                                            else {
                                                root.passwordDraft = "";
                                                root.passwordVisible = false;
                                                root.selectedNetwork = network;
                                            }
                                        }
                                        background: Rectangle {
                                            radius: networkKey.cornerRadius
                                            color: networkKey.wash
                                            opacity: networkKey.enabled && (networkKey.hovered || networkKey.down || networkKey.visualFocus) ? 1 : 0
                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: Theme.fast
                                                }
                                            }
                                        }
                                        contentItem: RowLayout {
                                            spacing: Theme.gapM
                                            SignalIcon {
                                                bars: root.signalBars(networkRow.modelData.signal)
                                            }
                                            C.Label {
                                                text: networkRow.modelData.name
                                                Layout.fillWidth: true
                                            }
                                            C.Label {
                                                text: (networkRow.modelData.saved ? "saved" : networkRow.secured ? "" : "open")
                                                visible: text !== ""
                                                color: Theme.textDim
                                                font.pixelSize: 12
                                            }
                                            C.Label {
                                                text: Math.round(networkRow.modelData.signal) + "%"
                                                color: Theme.textDim
                                                font.family: Theme.mono
                                                font.pixelSize: 11
                                                font.features: {"tnum": 1}
                                            }
                                            C.Icon {
                                                visible: networkRow.secured
                                                name: "lock"
                                                size: 13
                                                color: Theme.textDim
                                            }
                                            C.Button {
                                                visible: !!networkRow.modelData.saved
                                                glyph: "trash"
                                                flat: true
                                                hint: "Forget network"
                                                implicitWidth: 28
                                                implicitHeight: 28
                                                onClicked: root.forgetPath = networkRow.modelData.path
                                            }
                                        }
                                    }
                                    // The password opens inline under the network.
                                    Loader {
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 40
                                        Layout.rightMargin: 10
                                        Layout.bottomMargin: 10
                                        active: networkRow.asking
                                        visible: active
                                        sourceComponent: passwordForm
                                        onLoaded: item.focusField()
                                    }
                                    RowLayout {
                                        visible: root.forgetPath === networkRow.modelData.path
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 40
                                        Layout.rightMargin: 6
                                        Layout.bottomMargin: 6
                                        spacing: Theme.gapS
                                        C.Label {
                                            text: "Forget saved credentials?"
                                            font.pixelSize: Theme.small
                                            Layout.fillWidth: true
                                        }
                                        SmallKey {
                                            text: "Cancel"
                                            onClicked: root.forgetPath = ""
                                        }
                                        C.Button {
                                            text: "Forget"
                                            danger: true
                                            implicitHeight: 28
                                            onClicked: root.perform("wifi.forget", {path: networkRow.modelData.path}, () => {
                                                root.forgetPath = "";
                                                root.refresh();
                                            })
                                        }
                                    }
                                }
                            }
                        }
                        C.Label {
                            visible: wifiModule.networks.some(network => network.type === "8021x")
                            text: "Enterprise networks use existing NetworkManager profiles. Configure new enterprise credentials externally."
                            color: Theme.textDim
                            font.pixelSize: Theme.small
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            Layout.leftMargin: 2
                        }
                        // NetworkManager's VPN and WireGuard profiles; new ones are made in nm-connection-editor or nmcli.
                        Flow {
                            visible: (ShellState.vpn.connections || []).length > 0
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            spacing: 6
                            Repeater {
                                model: ShellState.vpn.connections || []
                                C.Chip {
                                    required property var modelData
                                    readonly property bool pending: root.busy && root.pendingVpn === modelData.path
                                    readonly property string kind: modelData.kind === "wireguard" ? "WireGuard" : modelData.kind === "openvpn" ? "OpenVPN" : modelData.kind || ""
                                    glyph: "shield"
                                    rest: Theme.key
                                    text: "VPN · " + modelData.name + (pending || modelData.state === "connecting" || modelData.state === "disconnecting" ? " · …" : "")
                                    hint: (pending ? (modelData.state === "on" ? "Disconnecting…" : "Connecting… Enter any password NetworkManager asks for")
                                           : ({on: "Connected", connecting: "Connecting…", disconnecting: "Disconnecting…"})[modelData.state] || "Off") + (kind ? " · " + kind : "")
                                    selected: modelData.state !== "off"
                                    enabled: !root.acting
                                    Accessible.role: Accessible.CheckBox
                                    Accessible.checkable: true
                                    Accessible.checked: selected
                                    onClicked: {
                                        root.pendingVpn = modelData.path;
                                        root.perform(modelData.state === "off" ? "vpn.connect" : "vpn.disconnect", {path: modelData.path}, () => ShellState.refreshVpn());
                                    }
                                }
                            }
                        }
                        C.Caption {
                            visible: root.busy && root.pendingMethod === "vpn.connect"
                            text: "Connecting… Enter any password NetworkManager asks for"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            Layout.leftMargin: 2
                        }
                    }
                }
                // Network · Bluetooth: the switch and Scan, a pairing prompt, then paired devices and nearby ones.
                C.Card {
                    visible: ShellState.detail === "bluetooth"
                    Layout.fillWidth: true
                    implicitHeight: bluetoothColumn.implicitHeight + 24
                    ColumnLayout {
                        id: bluetoothColumn
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6
                        ModuleHeader {
                            title: "Bluetooth"
                            large: true
                            note: {
                                const count = Services.bluetoothDevices.filter(d => d.connected).length;
                                return !Services.bluetoothAvailable ? "no adapter detected" : !Services.bluetoothEnabled ? "off"
                                     : count ? count + " connected" : Services.bluetoothScanning ? "searching nearby" : "on";
                            }
                            Layout.leftMargin: 2
                            Layout.bottomMargin: 4
                            // Scan turns while it looks; pressing it again stops.
                            C.Button {
                                id: bluetoothScan
                                visible: Services.bluetoothEnabled
                                text: Services.bluetoothScanning ? "Scanning" : "Scan"
                                hint: Services.bluetoothScanning ? "Stop looking for devices" : "Look for devices to pair"
                                implicitHeight: 28
                                leftPadding: 10
                                rightPadding: 10
                                topPadding: 0
                                bottomPadding: 0
                                labelSize: 12
                                cornerRadius: 8
                                foreground: Services.bluetoothScanning ? Theme.accentText : Theme.text
                                Accessible.role: Accessible.CheckBox
                                Accessible.checkable: true
                                Accessible.checked: Services.bluetoothScanning
                                onClicked: Services.bluetoothScan(!Services.bluetoothScanning)
                                background: Rectangle {
                                    radius: bluetoothScan.cornerRadius
                                    color: bluetoothScan.hovered || bluetoothScan.down || bluetoothScan.visualFocus ? Theme.keyHover : Theme.key
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.fast
                                        }
                                    }
                                }
                                contentItem: RowLayout {
                                    spacing: 6
                                    C.Icon {
                                        id: scanSpinner
                                        name: "spinner"
                                        size: 13
                                        color: bluetoothScan.foreground
                                        RotationAnimator on rotation {
                                            running: Services.bluetoothScanning && !Theme.reduced
                                            from: 0
                                            to: 360
                                            duration: 900
                                            loops: Animation.Infinite
                                            onRunningChanged: if (!running) scanSpinner.rotation = 0
                                        }
                                    }
                                    C.Label {
                                        text: bluetoothScan.text
                                        color: bluetoothScan.foreground
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }
                            C.Switch {
                                hint: Services.bluetoothEnabled ? "Turn Bluetooth off" : "Turn Bluetooth on"
                                selected: Services.bluetoothEnabled
                                enabled: Services.bluetoothAvailable
                                onClicked: Services.bluetoothPower(!Services.bluetoothEnabled)
                            }
                        }
                        Rectangle {
                            visible: !!root.pairing
                            Layout.fillWidth: true
                            implicitHeight: pairingContent.implicitHeight + 24
                            radius: Theme.radiusCard
                            color: Theme.accentSoft
                            border.width: 1
                            border.color: Theme.accentLine
                            ColumnLayout {
                                id: pairingContent
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: Theme.gapS
                                C.Label {
                                    text: root.pairing ? root.pairing.message : ""
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }
                                C.Field {
                                    id: pin
                                    Layout.fillWidth: true
                                    implicitHeight: 36
                                    placeholderText: "PIN or passkey"
                                    visible: root.pairing && root.pairing.input
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.gapS
                                    C.Button {
                                        text: "Reject"
                                        implicitHeight: 32
                                        onClicked: {
                                            ShellState.run("bluetooth.reply", {
                                                accept: false
                                            });
                                            root.pairing = null;
                                        }
                                    }
                                    C.Button {
                                        text: "Accept"
                                        accent: true
                                        implicitHeight: 32
                                        Layout.fillWidth: true
                                        enabled: !!root.pairing && (!root.pairing.input || pin.text.trim().length > 0)
                                        onClicked: {
                                            ShellState.run("bluetooth.reply", {
                                                accept: true,
                                                value: pin.text
                                            });
                                            pin.clear();
                                            root.pairing = null;
                                        }
                                    }
                                }
                            }
                        }
                        // Paired devices, connected first.
                        Repeater {
                            model: Services.bluetoothEnabled ? root.pairedDevices : []
                            BluetoothDeviceRow {
                                required property var modelData
                                Layout.fillWidth: true
                                device: modelData
                                working: root.bluetoothWork[modelData.dbusPath] || ""
                                autoConnect: root.autoConnectList.indexOf(String(modelData.address).toUpperCase()) >= 0
                                expanded: root.expandedDevice === modelData.dbusPath
                                locked: root.acting
                                onActivated: root.bluetoothActivate(modelData)
                                onOptionsRequested: root.expandedDevice = expanded ? "" : modelData.dbusPath
                                onAutoConnectToggled: root.toggleAutoConnect(modelData)
                                onForgetRequested: {
                                    root.expandedDevice = "";
                                    modelData.forget();
                                }
                            }
                        }
                        C.EmptyState {
                            visible: Services.bluetoothEnabled && root.nearbyDevices.length === 0 && root.pairedDevices.length === 0
                            Layout.fillWidth: true
                            Layout.topMargin: Theme.gapM
                            Layout.bottomMargin: Theme.gapM
                            glyph: "bluetooth"
                            title: Services.bluetoothScanning ? "Looking for devices…" : "No devices yet"
                            description: Services.bluetoothScanning ? "Put your device in pairing mode" : "Scan to find nearby devices"
                        }
                        // Devices found nearby, to pair.
                        C.Caption {
                            visible: Services.bluetoothEnabled && (root.nearbyDevices.length > 0 || root.pairedDevices.length > 0)
                            text: root.nearbyDevices.length > 0 ? "Nearby" : Services.bluetoothScanning ? "Looking for devices in pairing mode…" : "Scan to add a new device"
                            font.pixelSize: 12
                            Layout.fillWidth: true
                            Layout.leftMargin: 4
                            Layout.topMargin: 4
                        }
                        Repeater {
                            model: Services.bluetoothEnabled ? root.nearbyDevices : []
                            BluetoothDeviceRow {
                                required property var modelData
                                Layout.fillWidth: true
                                device: modelData
                                locked: root.acting
                                onActivated: root.bluetoothActivate(modelData)
                            }
                        }
                        SmallKey {
                            visible: Services.bluetoothEnabled && root.hiddenDevices > 0 && !root.showAllDevices
                            text: "Show " + root.hiddenDevices + (root.hiddenDevices === 1 ? " unnamed device" : " unnamed devices")
                            rest: "transparent"
                            Layout.alignment: Qt.AlignHCenter
                            onClicked: root.showAllDevices = true
                        }
                    }
                }
                ColumnLayout {
                    visible: ShellState.detail === "power"
                    Layout.fillWidth: true
                    spacing: Theme.gapS
                    C.StatusCard {
                        Layout.fillWidth: true
                        glyph: Services.batteryCharging ? "bolt" : Services.batteryAvailable ? "battery" : "gauge"
                        title: Services.batteryAvailable ? Math.round(Services.batteryPercent) + "%" : "AC power"
                        subtitle: {
                            const state = Services.batteryCharging ? "Charging" : Services.onBattery ? "On battery" : "Plugged in";
                            const seconds = Services.batterySeconds;
                            return state + (seconds > 0 ? " · " + (seconds >= 3600 ? Math.floor(seconds / 3600) + "h " : "") + Math.floor(seconds % 3600 / 60) + "m " + (Services.batteryCharging ? "until full" : "remaining") : "");
                        }
                        level: Services.batteryAvailable ? Services.batteryPercent / 100 : -1
                        positive: Services.batteryCharging
                    }
                    C.SectionHeader {
                        text: "Power mode"
                        Layout.topMargin: Theme.gapXs
                    }
                    C.Label {
                        visible: !(ShellState.profiles.profiles || []).length
                        text: root.busy ? "Loading power modes…" : "Power modes are unavailable on this device."
                        color: Theme.muted
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    Repeater {
                        model: ShellState.profiles.profiles || []
                        C.ListRow {
                            required property string modelData
                            Layout.fillWidth: true
                            text: ({"power-saver": "Power saver", "balanced": "Balanced", "performance": "Performance"})[modelData] || modelData
                            subtitle: ({"power-saver": "Longest battery life, quiet fans", "balanced": "Fast when needed, efficient at idle", "performance": "Full CPU and GPU power"})[modelData] || "System power profile"
                            glyph: modelData === "power-saver" ? "leaf" : modelData === "performance" ? "bolt" : "gauge"
                            selected: ShellState.profiles.active === modelData
                            enabled: !root.acting
                            Accessible.role: Accessible.RadioButton
                            Accessible.checkable: true
                            Accessible.checked: selected
                            onClicked: root.perform("power.set", {
                                profile: modelData
                            }, r => ShellState.profiles = r)
                        }
                    }
                    C.Label {
                        id: tunedHint
                        // The installer lives in the Shale repository; a shell run from there knows its path.
                        readonly property string script: Paths.localPath(Qt.resolvedUrl("../scripts/install-power.py"))
                        property bool scriptFound: false
                        visible: (ShellState.profiles.profiles || []).length > 0 && ShellState.profiles.tuned === false
                        function probe() {
                            if (visible && !scriptFound && !scriptProbe.running)
                                scriptProbe.running = true;
                        }
                        onVisibleChanged: probe()
                        Component.onCompleted: probe()
                        text: "Using the stock tuned profiles. For the full effect, run " + (scriptFound
                            ? "sudo python3 " + (/^[\w\/.+-]+$/.test(script) ? script : "'" + script.replace(/'/g, "'\\''") + "'") + " --apply"
                            : "this from the Shale repository: sudo python3 \"$PWD/scripts/install-power.py\" --apply")
                        color: Theme.muted
                        font.pixelSize: Theme.small
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Process {
                            id: scriptProbe
                            command: ["test", "-f", tunedHint.script]
                            onExited: code => tunedHint.scriptFound = code === 0
                        }
                    }
                    C.Toggle {
                        visible: Backend.capabilities.builtinPanel !== false
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.gapXs
                        text: "Lower refresh rate in power saver"
                        selected: ShellState.setting("saverRefresh", true)
                        onClicked: ShellState.setSetting("saverRefresh", !ShellState.setting("saverRefresh", true))
                    }
                }
                UpdatePage {
                    visible: ShellState.detail === "update"
                    Layout.fillWidth: true
                }
                Media {
                    visible: ShellState.detail === "media"
                    Layout.fillWidth: true
                    active: visible
                }
                FocusView {
                    id: focusView
                    visible: ShellState.detail === "focus"
                    Layout.fillWidth: true
                }
                ColumnLayout {
                    visible: ShellState.detail === "tray"
                    Layout.fillWidth: true
                    spacing: Theme.gapS
                    C.EmptyState {
                        visible: Services.trayItems.length === 0
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.gapXl
                        glyph: "grid"
                        title: "No background apps"
                        description: "App indicators appear here"
                    }
                    Repeater {
                        model: Services.trayItems
                        C.ListRow {
                            id: trayRow
                            required property var modelData
                            Layout.fillWidth: true
                            image: modelData.icon
                            text: modelData.tooltipTitle || modelData.title || modelData.id
                            hint: "Open " + text
                            onClicked: modelData.onlyMenu ? trayMenuButton.openMenu() : modelData.activate()
                            trailing: C.Button {
                                id: trayMenuButton
                                glyph: "more"
                                flat: true
                                hint: "Menu for " + (trayRow.modelData.title || trayRow.modelData.id)
                                implicitWidth: 32
                                implicitHeight: 32
                                selected: trayMenu.shown && trayMenu.item === trayRow.modelData
                                function openMenu() {
                                    trayMenu.toggle(trayRow.modelData, trayMenuButton.QsWindow.window, trayMenuButton);
                                }
                                onClicked: openMenu()
                            }
                        }
                    }
                }
                Item {
                    Layout.preferredHeight: 4
                }
            }
        }
        // The power row, in the order Settings → Control center gives its buttons: Capture, Lock, and the session
        // keys (Sleep, Restart, which asks for a second press, and Hold to power off, which takes the rest of the
        // row). Settings sits in the header.
        RowLayout {
            id: actionFooter
            visible: ShellState.detail === ""
            Layout.fillWidth: true
            spacing: Theme.gapS
            Repeater {
                model: root.arrangement.footer.filter(item => item.shown).reduce((keys, item) => keys.concat(({
                        capture: ["capture"],
                        lock: ["lock"],
                        session: ["sleep", "restart", "poweroff"]
                    })[item.id] || []), [])
                Loader {
                    required property string modelData
                    Layout.fillWidth: modelData === "poweroff"
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: 44
                    sourceComponent: ({
                            capture: captureKey,
                            lock: lockKey,
                            sleep: sleepKey,
                            restart: restartKey,
                            poweroff: powerOffKey
                        })[modelData]
                }
            }
        }
    }
    Component {
        id: captureKey
        PowerKey {
            glyph: "camera"
            hint: "Capture"
            implicitWidth: 44
            onClicked: ShellState.open("capture")
        }
    }
    Component {
        id: lockKey
        PowerKey {
            glyph: "lock"
            hint: "Lock"
            implicitWidth: 44
            enabled: !root.leaving
            onClicked: ShellState.action("lock")
        }
    }
    Component {
        id: sleepKey
        PowerKey {
            glyph: "moon"
            hint: "Sleep · locks first"
            implicitWidth: 44
            enabled: !root.leaving
            onClicked: ShellState.action("suspend")
        }
    }
    Component {
        id: restartKey
        // Armed, it spells out the question until the second press or the timeout.
        PowerKey {
            text: root.restartArmed ? "Restart?" : ""
            glyph: "refresh"
            implicitWidth: root.restartArmed ? implicitContentWidth + leftPadding + rightPadding : 44
            hint: root.restartArmed ? "Press again to restart" : "Restart"
            selected: root.restartArmed
            enabled: !root.leaving
            onClicked: {
                if (root.restartArmed) {
                    root.endSession("reboot");
                } else {
                    root.restartArmed = true;
                    restartDisarm.restart();
                }
            }
        }
    }
    Component {
        id: powerOffKey
        C.HoldButton {
            id: powerOff
            text: "Hold to power off"
            destructive: true
            implicitHeight: 44
            implicitWidth: holdRow.implicitWidth + leftPadding + rightPadding
            leftPadding: 12
            rightPadding: 12
            topPadding: 0
            bottomPadding: 0
            armed: !root.leaving && ShellState.panel === "control" && !ShellState.locked && root.Window.active
            onConfirmed: root.endSession("shutdown")
            contentItem: Item {
                implicitWidth: holdRow.implicitWidth
                implicitHeight: holdRow.implicitHeight
                Row {
                    id: holdRow
                    anchors.centerIn: parent
                    spacing: Theme.gapS
                    C.Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "power"
                        size: 17
                        color: Theme.dangerText
                    }
                    C.Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: powerOff.progress > 0 ? "Keep holding" : "Hold to power off"
                        color: Theme.dangerText
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }
    // A second press within a few seconds restarts; after that Restart asks again.
    Timer {
        id: restartDisarm
        interval: 4000
        onTriggered: root.restartArmed = false
    }
    Component {
        id: passwordForm
        RowLayout {
            spacing: 6
            function focusField() {
                passwordField.forceActiveFocus();
            }
            C.Field {
                id: passwordField
                Layout.fillWidth: true
                implicitHeight: 34
                font.pixelSize: 14
                placeholderText: "Password"
                Accessible.name: "Password for " + (root.selectedNetwork ? root.selectedNetwork.name : "Wi-Fi")
                echoMode: root.passwordVisible ? TextInput.Normal : TextInput.Password
                text: root.passwordDraft
                onTextChanged: root.passwordDraft = text
                onAccepted: root.connectSelected()
                Keys.onEscapePressed: event => {
                    if (root.busy) {
                        event.accepted = false;
                        return;
                    }
                    root.cancelPassword();
                    event.accepted = true;
                }
                background: Rectangle {
                    radius: 9
                    color: Theme.well
                    border.width: 1
                    border.color: passwordField.activeFocus ? Theme.accentLine : Theme.edge
                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.fast
                        }
                    }
                }
            }
            C.Button {
                glyph: root.passwordVisible ? "eye-off" : "eye"
                flat: true
                hint: root.passwordVisible ? "Hide password" : "Show password"
                implicitWidth: 34
                implicitHeight: 34
                onClicked: root.passwordVisible = !root.passwordVisible
            }
            C.Button {
                accent: true
                text: root.busy ? "Joining…" : "Join"
                implicitHeight: 34
                cornerRadius: 9
                labelSize: 13
                enabled: !root.busy && !!root.selectedNetwork
                onClicked: root.connectSelected()
            }
        }
    }
    Timer {
        id: scanWait
        interval: 1500
        onTriggered: root.refresh()
    }
    Timer {
        id: brightnessDebounce
        interval: 60
        onTriggered: ShellState.run("brightness.set", {
            value: ShellState.brightness
        }, r => ShellState.osd("Brightness", r.value, "sun"))
    }
}
