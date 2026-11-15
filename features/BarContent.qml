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

// The bar's items in their zones. Bar.qml puts it in a layer-shell window; previews put it in a plain one.
Item {
    id: bar
    // A key on the bar, 28 px tall. Flat keys show a light wash on hover; the status key rests on
    // `module`. A key whose panel is open on this screen turns keySelected.
    component BarKey: C.Button {
        id: key
        // Whether the item has something to show; the zone hides its slot otherwise.
        property bool shown: true
        property color rest: "transparent"
        labelSize: 13
        implicitHeight: 28
        topPadding: 0
        bottomPadding: 0
        cornerRadius: Theme.radiusKey
        foreground: !enabled ? Theme.textFaint : tone === "danger" ? Theme.dangerText : tone === "warning" ? Theme.warning : Theme.text
        background: Rectangle {
            radius: key.cornerRadius
            color: key.selected ? Theme.keySelected : key.rest
            Behavior on color {
                ColorAnimation {
                    duration: Theme.fast
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: key.wash
                opacity: key.hovered || key.down || key.visualFocus ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fast
                    }
                }
            }
        }
    }
    // Something live or on (listening, recording, a focus session): a round accentSoft chip with accent text.
    component LiveChip: BarKey {
        implicitHeight: 24
        cornerRadius: 12
        rest: Theme.accentSoft
        leftPadding: 10
        rightPadding: 10
        foreground: Theme.accentText
    }
    // One part of the status key: its own click, scroll and hint, with a wash on hover.
    component StatusPart: BarKey {
        id: part
        implicitWidth: implicitContentWidth + leftPadding + rightPadding
        leftPadding: 6
        rightPadding: 6
        cornerRadius: Theme.radiusSegment
        background: Item {
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 2
                anchors.bottomMargin: 2
                radius: Theme.radiusSegment
                color: part.selected ? Theme.keySelected : part.hovered || part.down || part.visualFocus ? part.wash : "transparent"
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.fast
                    }
                }
            }
        }
    }
    required property string outputName
    // The window it is in, the tooltip its buttons share and the tray menu, which open next to it.
    property var window: null
    property var tooltip: null
    property var trayMenu: null
    // False while the bar is hidden (fullscreen, lock): live visuals pause.
    property bool onScreen: true
    readonly property bool compact: width < 760
    readonly property bool edge: ShellState.setting("barStyle", "floating") === "edge"
    // Settings → Bar arranges the items; anything the saved layout doesn't mention keeps its default place.
    readonly property var layout: BarItems.layout(ShellState.setting("barLayout", {}))
    readonly property var items: ({
            workspaces: workspacesItem, windowTitle: windowTitleItem, clock: clockItem, media: mediaItem,
            tray: trayItem, recording: recordingItem, privacy: privacyItem, focus: focusItem, timer: timerItem, stayAwake: stayAwakeItem,
            keyboard: keyboardItem, vpn: vpnItem, wifi: wifiItem, audio: audioItem, battery: batteryItem, notifications: notificationsItem,
            control: controlItem
        })
    // The now-playing button while it exists, for the hover card.
    property Item mediaButton: null
    property bool mediaHovered: false
    readonly property var monitor: Services.workspaces.find(w => w.monitor && w.monitor.name === bar.outputName && w.active)
    // Apps reading a camera through PipeWire: a video source with a device behind it (screen casts have none).
    readonly property var cameraUsers: Services.captureApps(Services.captureLinks.filter(g => (g.source.type & PwNodeType.Video) && g.source.ready && !!g.source.properties["device.api"]))
    // Empty pages: a step above the key colour, so they read as slots rather than as pages.
    readonly property color emptyPage: Theme.mix(Theme.key, Theme.textFaint, 0.25)
    function controlActive(detail) {
        return ShellState.panel === "control" && ShellState.detail === detail && ShellState.screenName === outputName;
    }
    function toggleControl(detail) {
        if (controlActive(detail)) {
            ShellState.close();
        } else {
            ShellState.open("control", bar.outputName);
            ShellState.detail = detail;
        }
    }
    SystemClock {
        id: clock
        precision: ShellState.setting("clockSeconds", false) ? SystemClock.Seconds : SystemClock.Minutes
    }
    // Today's weather beside the clock, from the forecast Clock and sky shows (the backend keeps it for 30 minutes).
    // Nothing is requested until a city is chosen there.
    readonly property var weatherLocation: ShellState.setting("weatherLocation", {})
    readonly property string weatherKey: weatherLocation && weatherLocation.name ? weatherLocation.latitude + "," + weatherLocation.longitude + "," + ShellState.setting("weatherUnits", "metric") : ""
    property var weather: null
    function refreshWeather() {
        if (weatherKey === "" || !Backend.ready)
            return;
        const key = weatherKey;
        Backend.request("weather.get", {location: weatherLocation, units: ShellState.setting("weatherUnits", "metric"), refresh: false}, (r, e) => {
            if (!e && key === bar.weatherKey)
                bar.weather = r;
        });
    }
    onWeatherKeyChanged: {
        weather = null;
        refreshWeather();
    }
    Timer {
        interval: 600000
        repeat: true
        triggeredOnStart: true
        running: bar.weatherKey !== "" && Backend.ready
        onTriggered: bar.refreshWeather()
    }
    // The case: floating, it is a rounded strip with a hairline edge; edge to edge, a hairline under it.
    Rectangle {
        anchors.fill: parent
        radius: bar.edge ? 0 : 12
        color: Theme.caseColor
        border.width: bar.edge ? 0 : 1
        border.color: Theme.hairline
        Rectangle {
            visible: bar.edge
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.hairline
        }
    }
    // One zone; each slot loads its item and hides while the item has nothing to show. Status items next to each
    // other share one key.
    component Zone: RowLayout {
        id: zoneRow
        required property string name
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        spacing: 5
        Repeater {
            model: BarItems.runs(bar.layout[zoneRow.name])
            Loader {
                required property var modelData
                readonly property var run: modelData
                readonly property string zone: zoneRow.name
                sourceComponent: run.status ? statusKey : bar.items[run.ids[0]] || null
                visible: !!item && item.shown
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: item ? item.implicitWidth : 0
                Layout.preferredHeight: item ? item.implicitHeight : 0
            }
        }
    }
    Zone {
        id: leftZone
        name: "left"
        x: 5
    }
    Zone {
        id: rightZone
        name: "right"
        x: bar.width - width - 5
    }
    // Room between the side zones. The middle zone stays centred while it fits there, and moves aside rather than
    // run into a busy side; the clock drops the weather, then the date, when even that is too tight.
    readonly property real centerRoom: rightZone.x - leftZone.x - leftZone.width - 12
    Zone {
        name: "center"
        x: Math.round(Math.max(leftZone.x + leftZone.width + 5, Math.min((bar.width - width) / 2, rightZone.x - 6 - width)))
    }
    Component {
        id: statusKey
        Rectangle {
            id: status
            readonly property var ids: parent && parent.run ? parent.run.ids : []
            readonly property bool shown: parts.implicitWidth > 0
            implicitWidth: parts.implicitWidth + 12
            implicitHeight: 28
            radius: Theme.radiusKey
            color: Theme.module
            Row {
                id: parts
                x: 6
                height: parent.height
                Repeater {
                    model: status.ids
                    Loader {
                        required property string modelData
                        sourceComponent: bar.items[modelData] || null
                        visible: !!item && item.shown
                    }
                }
            }
        }
    }
    Component {
        id: workspacesItem
        Rectangle {
            id: pages
            readonly property bool shown: true
            readonly property bool dots: ShellState.setting("workspaceStyle", "dots") === "dots"
            // Each page's slot includes the 5 px gap after it; the current page stretches.
            readonly property int slotWidth: dots ? 13 : 23
            readonly property int stretch: dots ? 18 : 8
            readonly property real naturalWidth: workspaceModel.count * slotWidth + (strip.currentIndex >= 0 ? stretch : 0)
            implicitWidth: Math.min(naturalWidth, Math.max(60, Math.min(bar.width / 2 - 260, 300))) + 15
            implicitHeight: 28
            radius: Theme.radiusKey
            color: Theme.module
            ListView {
                id: strip
                // Empty pages 1…N shown as well, unless they belong to another screen.
                readonly property int slots: ShellState.setting("workspaceSlots", 0)
                readonly property int activeId: bar.monitor ? bar.monitor.id : (Services.focusedWorkspace ? Services.focusedWorkspace.id : 1)
                readonly property var occupied: Services.workspaces.filter(w => w.id > 0 && w.monitor && w.monitor.name === bar.outputName && (w.id === activeId || Services.windows.some(win => win.workspace && win.workspace.id === w.id))).sort((a, b) => a.id - b.id)
                function syncWorkspaces() {
                    if (!workspaceModel || !occupied)
                        return;
                    const entries = occupied.map(w => ({ workspaceId: w.id, workspaceName: w.name || String(w.id), urgent: !!w.urgent, empty: false }));
                    if (!entries.some(w => w.workspaceId === activeId) && activeId > 0)
                        entries.push({ workspaceId: activeId, workspaceName: String(activeId), urgent: false, empty: false });
                    for (let id = 1; id <= slots; ++id)
                        if (!entries.some(w => w.workspaceId === id) && !Services.workspaces.some(w => w.id === id && w.monitor && w.monitor.name !== bar.outputName))
                            entries.push({ workspaceId: id, workspaceName: String(id), urgent: false, empty: true });
                    entries.sort((a, b) => a.workspaceId - b.workspaceId);
                    for (let i = workspaceModel.count - 1; i >= 0; --i)
                        if (!entries.some(w => w.workspaceId === workspaceModel.get(i).workspaceId))
                            workspaceModel.remove(i);
                    for (let i = 0; i < entries.length; ++i) {
                        if (i >= workspaceModel.count || workspaceModel.get(i).workspaceId !== entries[i].workspaceId)
                            workspaceModel.insert(i, entries[i]);
                        else
                            workspaceModel.set(i, entries[i]);
                    }
                    currentIndex = entries.findIndex(w => w.workspaceId === activeId);
                }
                onOccupiedChanged: syncWorkspaces()
                onActiveIdChanged: syncWorkspaces()
                onSlotsChanged: syncWorkspaces()
                onCurrentIndexChanged: if (currentIndex >= 0 && interactive)
                    positionViewAtIndex(currentIndex, ListView.Contain)
                Component.onCompleted: syncWorkspaces()
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 7
                clip: true
                orientation: ListView.Horizontal
                boundsBehavior: Flickable.StopAtBounds
                interactive: pages.naturalWidth > width + 1
                model: ListModel { id: workspaceModel }
                delegate: C.Button {
                    id: page
                    required property int workspaceId
                    required property string workspaceName
                    required property bool urgent
                    required property bool empty
                    readonly property bool current: strip.activeId === workspaceId
                    readonly property color tint: current ? Theme.accent : urgent ? Theme.warning : page.hovered ? Theme.textSecondary : empty ? bar.emptyPage : Theme.textDim
                    // The current page stretches into a lit pill.
                    property real markWidth: pages.dots ? (current ? 22 : 7) : (current ? 22 : 16)
                    width: markWidth + 5
                    height: strip.height
                    padding: 0
                    hint: "Page " + workspaceName
                    Accessible.name: "Page " + workspaceName + (current ? ", current" : empty ? ", empty" : ", has windows")
                    Behavior on markWidth {
                        NumberAnimation {
                            duration: Theme.reduced ? 0 : Theme.lowPower ? 140 : 220
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.easeOut
                        }
                    }
                    background: Item {}
                    contentItem: Item {
                        // The glow costs a blur pass; power saver goes without it.
                        RectangularShadow {
                            anchors.fill: mark
                            visible: page.current && !Theme.lowPower
                            radius: mark.radius
                            blur: 10
                            color: Theme.tint(Theme.accent, 0.55)
                        }
                        Rectangle {
                            id: mark
                            x: 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: page.markWidth
                            height: pages.dots ? 7 : 16
                            radius: pages.dots ? 4 : 6
                            color: pages.dots || page.current ? page.tint : "transparent"
                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.fast
                                }
                            }
                            C.Label {
                                visible: !pages.dots
                                anchors.centerIn: parent
                                text: page.workspaceName
                                color: page.current ? Theme.accentInk : page.tint
                                font.family: Theme.mono
                                font.pixelSize: 10
                                font.weight: page.current ? Font.DemiBold : Font.Normal
                                elide: Text.ElideNone
                            }
                        }
                    }
                    onClicked: Services.workspace(workspaceId)
                }
                add: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.fast }
                }
                remove: Transition {
                    NumberAnimation { property: "opacity"; to: 0; duration: Theme.fast }
                }
                displaced: Transition {
                    NumberAnimation { property: "x"; duration: Theme.reduced ? 0 : Theme.lowPower ? 120 : 200; easing.type: Easing.OutCubic }
                }
            }
            WheelHandler {
                // A touchpad sends many small movements: one notch of a wheel (120) is one step.
                property real travelled: 0
                onWheel: event => {
                    travelled += event.angleDelta.y;
                    const steps = Math.trunc(travelled / 120);
                    if (!workspaceModel.count || !steps)
                        return;
                    travelled -= steps * 120;
                    const next = (strip.currentIndex + (steps < 0 ? 1 : -1) + workspaceModel.count) % workspaceModel.count;
                    Services.workspace(workspaceModel.get(next).workspaceId);
                }
            }
        }
    }
    Component {
        id: windowTitleItem
        BarKey {
            id: titleKey
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
            implicitWidth: Math.min(Math.max(120, Math.min(340, bar.width / 2 - 460)), implicitContentWidth + leftPadding + rightPadding)
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
                    C.Label {
                        anchors.centerIn: parent
                        text: titleKey.app.charAt(0).toUpperCase()
                        color: Theme.textSecondary
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        elide: Text.ElideNone
                    }
                }
                C.Label {
                    visible: titleKey.app !== ""
                    text: titleKey.app
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    Layout.maximumWidth: 140
                }
                // Runs on from the app name like one line of text.
                C.Label {
                    visible: text !== ""
                    text: titleKey.app === "" ? (titleKey.title || "Shale") : titleKey.title && titleKey.title !== titleKey.app ? " · " + titleKey.title : ""
                    color: Theme.textDim
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    Layout.leftMargin: titleKey.app === "" ? 0 : -Theme.gapS
                }
            }
        }
    }
    Component {
        id: clockItem
        BarKey {
            id: clockKey
            readonly property bool seconds: ShellState.setting("clockSeconds", false)
            readonly property string style: ShellState.setting("clockFormat", "date-time")
            readonly property string time: Qt.formatDateTime(clock.date, ShellState.setting("clock24h", true) ? (seconds ? "HH:mm:ss" : "HH:mm") : (seconds ? "h:mm:ss AP" : "h:mm AP"))
            readonly property string day: style === "time" ? "" : Qt.formatDateTime(clock.date, style === "date-time" ? "ddd d MMM" : "ddd")
            readonly property string temperature: bar.weather && bar.weather.current && bar.weather.current.temperature !== null && bar.weather.current.temperature !== undefined ? bar.weather.current.temperature + "°" : ""
            // In the middle zone it gives up the weather, then the date, before crowding the sides.
            readonly property real room: parent && parent.zone === "center" ? bar.centerRoom : Infinity
            readonly property real timeWidth: Math.ceil(timeMetrics.advanceWidth) + leftPadding + rightPadding
            readonly property real dayWidth: day !== "" ? Math.ceil(dayMetrics.advanceWidth) + 10 : 0
            readonly property bool showDay: day !== "" && timeWidth + dayWidth <= room
            readonly property bool showWeather: temperature !== "" && (day === "" || showDay) && timeWidth + dayWidth + Math.ceil(weatherMetrics.advanceWidth) + 26 <= room
            TextMetrics {
                id: timeMetrics
                text: clockKey.time
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: 650
                font.features: ({"tnum": 1})
            }
            TextMetrics {
                id: dayMetrics
                text: clockKey.day
                font.family: Theme.font
                font.pixelSize: 12
            }
            TextMetrics {
                id: weatherMetrics
                text: clockKey.temperature
                font.family: Theme.font
                font.pixelSize: 12
                font.features: ({"tnum": 1})
            }
            leftPadding: 12
            rightPadding: 12
            selected: ShellState.panel === "calendar" && ShellState.screenName === bar.outputName
            hint: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy") + (temperature ? "\n" + bar.weather.current.label + " · " + temperature : "")
            tooltip: bar.tooltip
            Accessible.name: "Clock and sky, " + Qt.formatDateTime(clock.date, "dddd d MMMM") + ", " + time
            onClicked: ShellState.toggle("calendar", bar.outputName)
            // Labels without eliding, so their implicit widths stay the full text.
            contentItem: RowLayout {
                spacing: 8
                C.Label {
                    text: clockKey.time
                    font.pixelSize: 13
                    font.weight: 650
                    font.features: ({"tnum": 1})
                    elide: Text.ElideNone
                }
                C.Label {
                    visible: clockKey.showDay
                    text: clockKey.day
                    color: Theme.textMuted
                    font.pixelSize: 12
                    elide: Text.ElideNone
                }
                RowLayout {
                    visible: clockKey.showWeather
                    spacing: Theme.gapXs
                    C.Icon {
                        name: bar.weather && bar.weather.current ? bar.weather.current.icon : "cloud"
                        size: 13
                        color: Theme.textMuted
                    }
                    C.Label {
                        text: clockKey.temperature
                        color: Theme.textMuted
                        font.pixelSize: 12
                        font.features: ({"tnum": 1})
                        elide: Text.ElideNone
                    }
                }
            }
        }
    }
    Component {
        id: mediaItem
        BarKey {
            id: mediaButton
            // Narrow bars keep the cover but drop the title.
            readonly property bool wide: bar.width > 1500
            readonly property var player: NowPlaying.player
            readonly property string artist: player ? player.trackArtist || "" : ""
            shown: !!player && bar.width > 1100 && ShellState.setting("barMedia", true)
            leftPadding: 8
            rightPadding: wide ? 12 : 8
            implicitWidth: Math.min(implicitContentWidth + leftPadding + rightPadding, wide ? 300 : 36)
            hint: "Player"
            Accessible.name: player ? "Player, " + (player.trackTitle || player.identity) + (artist ? " by " + artist : "") : "Media controls"
            selected: bar.controlActive("media")
            onClicked: bar.toggleControl("media")
            Component.onCompleted: bar.mediaButton = mediaButton
            Component.onDestruction: if (bar.mediaButton === mediaButton) {
                bar.mediaButton = null;
                bar.mediaHovered = false;
            }
            HoverHandler {
                onHoveredChanged: bar.mediaHovered = hovered
            }
            contentItem: RowLayout {
                spacing: 8
                C.CoverArt {
                    id: cover
                    // Moves while playing: the live spectrum when the visualizer runs, otherwise three bars on a loop.
                    readonly property bool live: bar.onScreen && mediaButton.visible && NowPlaying.playing && ShellState.setting("visualizer", true) && !Theme.reduced && !Theme.lowPower
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    radius: 5
                    glyphSize: 12
                    source: NowPlaying.artFile
                    // Darkens the cover under the bars; without a cover it hides the placeholder note.
                    Rectangle {
                        anchors.fill: parent
                        visible: NowPlaying.playing
                        color: cover.ready ? Qt.rgba(0, 0, 0, 0.5) : Theme.key
                    }
                    C.Spectrum {
                        id: spectrum
                        anchors.centerIn: parent
                        width: 9
                        height: 10
                        visible: active && available
                        bars: 3
                        spacing: 1.5
                        floor: 2
                        maxRadius: 1
                        curve: 0.6
                        color: Theme.accent
                        secondary: Theme.accent
                        active: cover.live
                    }
                    Row {
                        id: meter
                        anchors.centerIn: parent
                        visible: NowPlaying.playing && !spectrum.visible
                        height: 10
                        spacing: 1.5
                        Repeater {
                            model: [0.8, 0.5, 0.65]
                            Rectangle {
                                id: meterBar
                                required property real modelData
                                required property int index
                                width: 2
                                height: 10
                                color: Theme.accent
                                transform: Scale {
                                    id: level
                                    origin.y: 10
                                    yScale: meterBar.modelData
                                }
                                SequentialAnimation {
                                    running: cover.live && meter.visible
                                    loops: Animation.Infinite
                                    NumberAnimation { target: level; property: "yScale"; to: 0.95; duration: 290 + meterBar.index * 40; easing.type: Easing.InOutSine }
                                    NumberAnimation { target: level; property: "yScale"; to: 0.45; duration: 220 + meterBar.index * 30; easing.type: Easing.InOutSine }
                                    NumberAnimation { target: level; property: "yScale"; to: 0.8; duration: 210 + meterBar.index * 50; easing.type: Easing.InOutSine }
                                    NumberAnimation { target: level; property: "yScale"; to: 0.25; duration: 300 + meterBar.index * 20; easing.type: Easing.InOutSine }
                                }
                            }
                        }
                    }
                }
                C.Label {
                    visible: mediaButton.wide
                    text: mediaButton.player ? mediaButton.player.trackTitle || mediaButton.player.identity : ""
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    Layout.maximumWidth: 170
                }
                C.Label {
                    visible: mediaButton.wide && mediaButton.artist !== ""
                    text: " · " + mediaButton.artist
                    color: Theme.textDim
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    Layout.maximumWidth: 130
                    Layout.leftMargin: -8
                }
            }
        }
    }
    Component {
        id: trayItem
        RowLayout {
            id: tray
            // How many apps get their own icon; the rest open from the tray page. Narrow bars show none.
            readonly property int count: {
                const chosen = ShellState.setting("trayIcons", -1);
                return bar.width <= 1100 ? 0 : chosen >= 0 ? chosen : bar.width > 1700 ? 3 : 2;
            }
            readonly property bool shown: Services.trayItems.length > 0
            spacing: 2
            Repeater {
                model: Services.trayItems.slice(0, tray.count)
                BarKey {
                    id: trayButton
                    required property var modelData
                    implicitWidth: 28
                    hint: modelData.tooltipTitle || modelData.title || modelData.id
                    tooltip: bar.tooltip
                    contentItem: Item {
                        Image {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: trayButton.modelData.icon
                            sourceSize.width: 32
                            sourceSize.height: 32
                            fillMode: Image.PreserveAspectFit
                        }
                    }
                    selected: !!bar.trayMenu && bar.trayMenu.shown && bar.trayMenu.item === modelData
                    onClicked: modelData.onlyMenu ? bar.trayMenu.toggle(modelData, bar.window, trayButton) : modelData.activate()
                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: {
                            bar.tooltip.hide(trayButton, true);
                            bar.trayMenu.toggle(trayButton.modelData, bar.window, trayButton);
                        }
                    }
                    TapHandler {
                        acceptedButtons: Qt.MiddleButton
                        onTapped: {
                            bar.tooltip.hide(trayButton, true);
                            trayButton.modelData.secondaryActivate();
                        }
                    }
                    // Apps such as volume mixers act on scrolling; deltas are Qt's, as Plasma sends them.
                    WheelHandler {
                        onWheel: event => {
                            if (event.angleDelta.y !== 0)
                                trayButton.modelData.scroll(event.angleDelta.y, false);
                            if (event.angleDelta.x !== 0)
                                trayButton.modelData.scroll(event.angleDelta.x, true);
                        }
                    }
                }
            }
            BarKey {
                visible: Services.trayItems.length > tray.count
                implicitWidth: 28
                glyph: "tray"
                hint: "System tray"
                tooltip: bar.tooltip
                selected: bar.controlActive("tray")
                onClicked: bar.toggleControl("tray")
            }
        }
    }
    Component {
        id: recordingItem
        LiveChip {
            id: recordingChip
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
    }
    Component {
        id: privacyItem
        LiveChip {
            id: privacyButton
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
                C.Icon { visible: privacyButton.mic; name: "mic"; size: 12; color: Theme.accentText }
                C.Icon { visible: privacyButton.camera; name: "camera"; size: 12; color: Theme.accentText }
                C.Icon { visible: privacyButton.sharing; name: "cast"; size: 12; color: Theme.accentText }
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
    }
    Component {
        id: focusItem
        LiveChip {
            id: focusButton
            shown: Focus.active
            readonly property string remaining: Focus.remainingSeconds < 60 ? Focus.remainingSeconds + "s" : Focus.minutesText(Focus.remainingSeconds)
            hint: "Focus · " + remaining + " left\nClick to end · Scroll to add or take 5 min"
            tooltip: bar.tooltip
            Accessible.name: "Focus, " + remaining + " left"
            onClicked: Focus.end(true)
            WheelHandler {
                property real travelled: 0
                onWheel: event => {
                    travelled += event.angleDelta.y;
                    const steps = Math.trunc(travelled / 120);
                    if (!steps)
                        return;
                    travelled -= steps * 120;
                    Focus.extend(steps > 0 ? 5 : -5);
                }
            }
            contentItem: RowLayout {
                spacing: 6
                // The ring empties as the session runs out.
                Shape {
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 14
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Theme.accentLine
                        strokeWidth: 2
                        fillColor: "transparent"
                        PathAngleArc { centerX: 7; centerY: 7; radiusX: 5.5; radiusY: 5.5; startAngle: 0; sweepAngle: 360 }
                    }
                    ShapePath {
                        strokeColor: Theme.accentText
                        strokeWidth: 2
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: 7; centerY: 7; radiusX: 5.5; radiusY: 5.5; startAngle: -90; sweepAngle: 360 * Focus.progress }
                    }
                }
                C.Label {
                    text: focusButton.remaining
                    color: Theme.accentText
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.features: ({"tnum": 1})
                    elide: Text.ElideNone
                }
            }
        }
    }
    Component {
        id: timerItem
        BarKey {
            id: timerButton
            readonly property var timer: Focus.nextTimer
            readonly property int remaining: timer ? Math.max(0, Math.ceil((timer.endsAt - Focus.now) / 1000)) : 0
            shown: !!timer
            leftPadding: 10
            rightPadding: 10
            hint: Focus.timers.map(t => (t.label || Focus.minutesText(t.seconds) + " timer") + " · " + Focus.clockText(Math.max(0, Math.ceil((t.endsAt - Focus.now) / 1000)))).join("\n") + "\nClick to cancel the first"
            tooltip: bar.tooltip
            Accessible.name: "Timer, " + Focus.clockText(remaining) + " left"
            onClicked: {
                const timer = timerButton.timer, left = timerButton.remaining;
                Focus.cancelTimer(timer.id);
                ShellState.message("Timer cancelled", "info", {label: "Undo", run: () => Focus.addTimer(left, timer.label)});
            }
            contentItem: RowLayout {
                spacing: 6
                C.Icon {
                    name: "timer"
                    size: 14
                    color: timerButton.foreground
                }
                C.Label {
                    text: Focus.clockText(timerButton.remaining)
                    color: timerButton.foreground
                    font.pixelSize: 12
                    font.features: ({"tnum": 1})
                    elide: Text.ElideNone
                }
            }
        }
    }
    Component {
        id: stayAwakeItem
        LiveChip {
            shown: ShellState.presentation
            implicitWidth: 24
            padding: 0
            leftPadding: 0
            rightPadding: 0
            hint: "Stay awake is on"
            tooltip: bar.tooltip
            onClicked: ShellState.presentation = false
            contentItem: Item {
                C.Icon {
                    anchors.centerIn: parent
                    name: "moon"
                    size: 13
                    color: Theme.accentText
                }
            }
        }
    }
    Component {
        id: keyboardItem
        BarKey {
            readonly property var layouts: ShellState.keyboard.layouts || []
            readonly property var current: layouts[ShellState.keyboard.index] || null
            shown: layouts.length > 1
            leftPadding: 10
            rightPadding: 10
            labelSize: 12
            text: current ? current.code.toUpperCase().slice(0, 3) : ""
            hint: (ShellState.keyboard.name || "Keyboard layout") + "\n" + layouts.map((l, i) => (i === ShellState.keyboard.index ? "● " : "○ ") + l.code + (l.variant ? " (" + l.variant + ")" : "")).join("\n") + "\nClick for the next layout"
            tooltip: bar.tooltip
            Accessible.name: "Keyboard layout, " + (ShellState.keyboard.name || text)
            onClicked: ShellState.nextKeyboardLayout()
        }
    }
    Component {
        id: vpnItem
        StatusPart {
            shown: !!ShellState.activeVpn
            glyph: "shield"
            foreground: Theme.accentText
            hint: ShellState.activeVpn ? "VPN · " + ShellState.activeVpn.name : ""
            tooltip: bar.tooltip
            selected: bar.controlActive("wifi")
            onClicked: bar.toggleControl("wifi")
        }
    }
    Component {
        id: wifiItem
        StatusPart {
            readonly property var network: (ShellState.wifi.networks || []).find(n => n.connected) || null
            readonly property bool connected: ShellState.wifi.state === "connected"
            shown: bar.width >= 560 && ShellState.wifiAvailable
            // The arcs show the signal; dimmed while disconnected so a dropped network is visible at a glance.
            glyph: !connected ? (ShellState.wifi.powered ? "wifi" : "wifi-off") : !network || network.signal >= 67 ? "wifi" : network.signal >= 34 ? "wifi-2" : "wifi-1"
            opacity: connected || bar.controlActive("wifi") ? 1 : 0.45
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }
            hint: connected ? "Wi-Fi" + (network ? " · " + network.name : "") : ShellState.wifi.powered ? "Wi-Fi · Not connected" : "Wi-Fi · Off"
            tooltip: bar.tooltip
            selected: bar.controlActive("wifi")
            onClicked: bar.toggleControl("wifi")
        }
    }
    Component {
        id: audioItem
        StatusPart {
            glyph: Services.muted ? "mute" : "volume"
            selected: bar.controlActive("audio")
            hint: "Audio · " + Math.round(Services.volume * 100) + "%"
            tooltip: bar.tooltip
            onClicked: bar.toggleControl("audio")
            WheelHandler {
                property real travelled: 0
                onWheel: event => {
                    travelled += event.angleDelta.y;
                    const steps = Math.trunc(travelled / 120);
                    if (!Services.audioAvailable || !steps)
                        return;
                    travelled -= steps * 120;
                    Services.setVolume(Services.volume + 0.05 * steps);
                }
            }
            TapHandler {
                acceptedButtons: Qt.MiddleButton
                onTapped: Services.toggleMute()
            }
        }
    }
    Component {
        id: batteryItem
        StatusPart {
            id: batteryButton
            readonly property bool low: !Services.batteryCharging && Services.onBattery && Services.batteryPercent <= 20
            // Low charge always shows its number, even when the percentage is turned off.
            readonly property bool percent: {
                const choice = ShellState.setting("batteryPercent", "auto");
                return low || choice === "always" || (choice === "auto" && !bar.compact);
            }
            readonly property color level: tone === "danger" ? Theme.danger : tone === "warning" ? Theme.warning : Theme.text
            shown: Services.batteryAvailable
            text: percent ? Math.round(Services.batteryPercent) + "%" : ""
            tone: !low ? "" : Services.batteryPercent <= 10 ? "danger" : "warning"
            hint: "Battery " + Math.round(Services.batteryPercent) + "% · Power profiles"
            tooltip: bar.tooltip
            Accessible.name: "Battery " + Math.round(Services.batteryPercent) + "%" + (Services.batteryCharging ? ", charging" : "")
            selected: bar.controlActive("power")
            onClicked: bar.toggleControl("power")
            contentItem: RowLayout {
                spacing: 5
                C.Icon {
                    visible: Services.batteryCharging
                    name: "bolt"
                    size: 12
                    color: batteryButton.foreground
                }
                // A small battery that empties with the charge.
                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 10
                    radius: 3
                    color: "transparent"
                    border.width: 1.5
                    border.color: batteryButton.low ? batteryButton.level : Theme.textSecondary
                    Rectangle {
                        x: 3
                        y: 3
                        width: Math.max(1, (parent.width - 6) * Math.min(1, Services.batteryPercent / 100))
                        height: parent.height - 6
                        radius: 1
                        color: batteryButton.level
                    }
                }
                C.Label {
                    visible: batteryButton.text !== ""
                    text: batteryButton.text
                    color: batteryButton.foreground
                    font.pixelSize: 12
                    font.features: ({"tnum": 1})
                    elide: Text.ElideNone
                }
            }
        }
    }
    Component {
        id: controlItem
        StatusPart {
            glyph: "sliders"
            selected: bar.controlActive("")
            hint: Updates.available ? "Control · Update available" : "Control"
            tooltip: bar.tooltip
            Accessible.name: hint
            onClicked: bar.toggleControl("")
            // A newer Shale is waiting; Control's first row says what it changes.
            Rectangle {
                visible: Updates.available
                z: 2
                x: parent.width - width - 3
                y: 4
                width: 6
                height: 6
                radius: 3
                color: Theme.accent
            }
        }
    }
    Component {
        id: notificationsItem
        BarKey {
            id: bell
            readonly property int count: Services.notifications.length
            readonly property bool dnd: ShellState.setting("dnd", false) || ShellState.quietNow
            implicitWidth: 32
            // Do not disturb swaps the bell so suppressed popups are never a surprise.
            glyph: dnd ? "bell-off" : "bell"
            selected: ShellState.panel === "notifications" && ShellState.screenName === bar.outputName
            hint: "Notifications"
            tooltip: bar.tooltip
            Accessible.name: "Notifications" + (dnd ? ", do not disturb" : "") + (count ? ", " + count + " waiting" : "")
            onClicked: ShellState.toggle("notifications", bar.outputName)
            Rectangle {
                visible: bell.count > 0
                z: 2
                x: parent.width - width - 4
                y: 1
                width: Math.max(14, badge.implicitWidth + 6)
                height: 14
                radius: 7
                color: Theme.accent
                C.Label {
                    id: badge
                    anchors.centerIn: parent
                    text: bell.count > 99 ? "99+" : String(bell.count)
                    color: Theme.accentInk
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.features: ({"tnum": 1})
                    elide: Text.ElideNone
                }
            }
        }
    }
}
