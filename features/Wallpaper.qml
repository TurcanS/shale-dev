import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../core"
import "../core/palette.js" as Palette
import "../components" as C

// Wallpapers: a large preview with a small mock of the shell and the colours the wallpaper gives it on the left,
// the thumbnail grid on the right. Draws its own header row (title, source, search, close).
FocusScope {
    id: root
    readonly property string title: "Wallpapers"
    readonly property bool showHeader: false
    readonly property int panelWidth: 840
    readonly property int panelHeight: 500
    readonly property int columns: 2
    property var entries: []
    readonly property var activeWallpapers: ShellState.activeWallpapers
    property bool localLoading: false
    property bool onlineLoading: false
    property string sourceMode: "local"
    property bool switchingSource: false
    property string localQuery: ""
    property var sourceStates: ({})
    property var onlineEntries: []
    property int onlinePage: 0
    property int onlineGeneration: 0
    property bool hasMore: false
    readonly property bool online: sourceMode !== "local"
    readonly property string sourceName: sourceMode === "wallpaperscom" ? "Wallpapers.com" : "Wallhaven"
    readonly property bool loading: online ? onlineLoading : localLoading
    readonly property bool applying: ShellState.wallpaperBusy || ShellState.wallpaperDownloading
    property string error: ""
    property string directory: ""
    // The helper lists at most 500 local wallpapers; set to that count when it stopped short.
    property int listedCount: 0
    property int selected: 0
    property int generation: 0
    readonly property var filtered: online ? onlineEntries : entries.filter(e => (e.name + " " + e.file).toLowerCase().indexOf(search.text.toLowerCase().trim()) >= 0)
    readonly property var current: selected >= 0 && selected < filtered.length ? filtered[selected] : null
    readonly property string monitor: ShellState.screenName || ShellState.targetScreen()
    readonly property string activePath: activeWallpapers[monitor] || ""
    readonly property bool isCurrent: !!current && !!current.path && current.path === activePath
    IpcHandler {
        target: "wallpaper-picker"
        function status(): string {
            return JSON.stringify({count: root.filtered.length, selected: root.selected, path: root.current ? root.current.path : "", activePath: root.activePath, monitor: root.monitor, busy: root.applying, transitionMs: Theme.enter, loading: root.loading, error: ShellState.wallpaperError || root.error});
        }
        function select(index: int): void {
            if (!root.applying) root.selected = Math.max(0, Math.min(root.filtered.length - 1, index));
        }
        function apply(): void { root.apply(); }
    }
    function switchSourceWithTab() {
        if (applying) return;
        if (sourceMode === "wallhaven") {
            chooseSource("wallpaperscom");
        } else if (sourceMode === "wallpaperscom") {
            chooseSource("local");
        } else {
            // Preserve the original shortcut to Wallhaven's popular feed.
            const states = Object.assign({}, sourceStates);
            delete states.wallhaven;
            sourceStates = states;
            chooseSource("wallhaven");
        }
        root.forceActiveFocus();
    }
    Shortcut {
        sequence: "Tab"
        context: Qt.WindowShortcut
        autoRepeat: false
        enabled: root.visible && ShellState.panel === "wallpaper"
        onActivated: root.switchSourceWithTab()
    }
    function chooseSource(mode) {
        if (sourceMode === mode || applying) return;
        if (online) {
            const states = Object.assign({}, sourceStates);
            states[sourceMode] = {query: search.text, entries: onlineEntries,
                page: onlinePage, hasMore: hasMore, selected: selected, error: error};
            sourceStates = states;
        }
        else localQuery = search.text;
        ++onlineGeneration;
        onlineLoading = false;
        onlineDebounce.stop();
        switchingSource = true;
        sourceMode = mode;
        const state = sourceStates[mode];
        onlineEntries = state ? state.entries : [];
        onlinePage = state ? state.page : 0;
        hasMore = state ? state.hasMore : false;
        search.text = online ? (state ? state.query : "") : localQuery;
        switchingSource = false;
        selected = state ? state.selected : 0;
        error = state ? state.error : "";
        ShellState.wallpaperError = "";
        if (online && !onlineEntries.length) searchOnline(false);
    }
    function searchOnline(append) {
        if (!online || (append && (!hasMore || onlineLoading))) return;
        if (!Backend.ready) {
            onlineLoading = false;
            error = "Wallpaper service is reconnecting…";
            return;
        }
        onlineDebounce.stop();
        const request = ++onlineGeneration;
        const page = append ? onlinePage + 1 : 1;
        onlineLoading = true;
        error = "";
        Backend.request(sourceMode + ".search", {query: search.text.trim(), page: page}, (result, failure) => {
            if (request !== onlineGeneration) return;
            onlineLoading = false;
            if (failure) { error = failure.message; return; }
            error = result.warning || "";
            const position = selected;
            onlineEntries = append ? onlineEntries.concat(result.entries.filter(item => !onlineEntries.some(old => old.id === item.id))) : result.entries;
            onlinePage = result.page;
            hasMore = result.hasMore;
            selected = append ? position : 0;
        });
    }
    function refresh() {
        if (!Backend.ready) return;
        const request = ++generation;
        localLoading = true;
        if (!online) error = "";
        Backend.request("wallpaper.list", {}, (r, e) => {
            if (request !== generation) return;
            localLoading = false;
            if (e) { if (!online) error = e.message; return; }
            const previous = root.current ? root.current.path : "";
            entries = r.entries;
            directory = r.directory;
            listedCount = r.limited === true ? r.entries.length : 0;
            ShellState.activeWallpapers = r.active || {};
            if (!online) error = r.warning || "";
            if (!online) {
                const preferred = filtered.findIndex(item => item.path === (previous || activePath));
                selected = Math.max(0, preferred);
            }
        });
    }
    // A local copy the colour reader can open: the small cached copy, or the file itself.
    function localImage(entry) {
        if (!entry)
            return "";
        if (entry.thumb)
            return entry.thumb;
        return /^file:\/\//.test(entry.url || "") ? entry.url : "";
    }
    // The accent and second colour a wallpaper gives the shell (see Theme.second), its deepest tone, and the surface.
    function swatches(colors) {
        const accent = Palette.accentFrom(colors);
        if (accent === "")
            return [];
        const color = Qt.darker(accent, 1);
        const second = color.hslSaturation < 0.05 ? Theme.textSecondary : Palette.inGamut(0.75, 0.06, Palette.oklch(color).h + 2.6);
        let deep = colors[0];
        for (let i = 1; i < colors.length; i++)
            if (Palette.luminance(colors[i]) < Palette.luminance(deep))
                deep = colors[i];
        return [{role: "Accent", color: color}, {role: "Second", color: second}, {role: "Surface", color: Theme.module}, {role: "Deepest", color: deep}];
    }
    readonly property var currentSwatches: previewColors.item ? swatches(previewColors.item.colors) : []
    readonly property color previewAccent: currentSwatches.length ? currentSwatches[0].color : Theme.accent
    LazyLoader {
        id: previewColors
        active: root.localImage(root.current) !== ""
        ColorQuantizer {
            source: root.localImage(root.current)
            depth: 3
            rescaleSize: 64
        }
    }
    // The grid ends with one action tile: add images to the folder, or load more results.
    readonly property bool showAction: online ? hasMore : directory !== ""
    readonly property var gridModel: filtered.concat(showAction ? [{action: true}] : [])
    function move(delta) {
        if (filtered.length && !applying)
            selected = Math.max(0, Math.min(filtered.length - 1, selected + delta));
    }
    function apply() {
        if (current && !isCurrent && !applying)
            ShellState.applyWallpaper(current, activePath);
    }
    Component.onCompleted: refresh()
    Connections {
        target: Backend
        function onReadyChanged() {
            if (Backend.ready) {
                root.refresh();
                if (root.online) root.searchOnline(false);
            }
        }
    }
    Connections {
        target: ShellState
        function onWallpaperSaved(entry) {
            const markSaved = item => (item.provider || "wallhaven") === (entry.provider || "wallhaven") && item.id === entry.id ? Object.assign({}, item, {path: entry.path}) : item;
            root.onlineEntries = root.onlineEntries.map(markSaved);
            const states = Object.assign({}, root.sourceStates);
            for (const provider of Object.keys(states))
                states[provider] = Object.assign({}, states[provider], {entries: states[provider].entries.map(markSaved)});
            root.sourceStates = states;
            if (!root.entries.some(item => item.path === entry.path))
                root.entries = root.entries.concat([Object.assign({}, entry, {remote: false})]);
        }
    }
    onFilteredChanged: selected = Math.max(0, Math.min(selected, filtered.length - 1))
    onSelectedChanged: {
        if (!applying)
            ShellState.wallpaperError = "";
        grid.positionViewAtIndex(selected, GridView.Contain);
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        // Title, source, search and close.
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: Theme.gapM
            C.Label {
                text: root.title
                font.pixelSize: 17
                font.weight: 650
                elide: Text.ElideNone
                Layout.leftMargin: 2
            }
            C.Segmented {
                fill: false
                segmentHeight: 32
                enabled: !root.applying
                model: [{key: "local", text: "Local", hint: "Your wallpaper folder"}, {key: "wallhaven", text: "Wallhaven"}, {key: "wallpaperscom", text: "Wallpapers.com"}]
                current: root.sourceMode
                onActivated: key => root.chooseSource(key)
            }
            C.Label {
                visible: root.loading && root.filtered.length > 0
                text: "Updating…"
                color: Theme.textDim
                font.pixelSize: 12
            }
            Item {
                Layout.fillWidth: true
            }
            C.Button {
                glyph: root.online ? "search" : "refresh"
                flat: true
                implicitWidth: 32
                implicitHeight: 32
                hint: root.online ? "Search " + root.sourceName : "Refresh wallpapers"
                enabled: !root.applying && !root.loading
                onClicked: root.online ? root.searchOnline(false) : root.refresh()
            }
            C.Field {
                id: search
                Layout.preferredWidth: 200
                implicitHeight: 32
                leftPadding: 32
                font.pixelSize: 13
                enabled: !root.applying
                placeholderText: root.online ? "Search " + root.sourceName : "Search"
                Accessible.name: "Search wallpapers"
                C.Icon {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    size: 14
                    color: Theme.textDim
                }
                onTextChanged: {
                    if (root.switchingSource) return;
                    root.selected = 0;
                    if (root.online) {
                        ++root.onlineGeneration;
                        root.onlineEntries = [];
                        root.onlinePage = 0;
                        root.hasMore = false;
                        root.onlineLoading = true;
                        onlineDebounce.restart();
                    }
                }
                Keys.onDownPressed: root.move(root.columns)
                Keys.onUpPressed: root.move(-root.columns)
                onAccepted: root.online ? root.searchOnline(false) : root.apply()
            }
            C.Button {
                id: closeKey
                glyph: "close"
                implicitWidth: 32
                implicitHeight: 32
                hint: "Close · Escape"
                onClicked: ShellState.close()
                background: Rectangle {
                    radius: Theme.radiusKey
                    color: closeKey.hovered || closeKey.down || closeKey.visualFocus ? Theme.mix(Theme.module, Theme.text, 0.06) : Theme.module
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.fast
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.gapM
            // The chosen wallpaper, its details and what to do with it.
            // A fixed 480 px: a long status line or an empty grid must not let it take the grid's room.
            ColumnLayout {
                Layout.preferredWidth: 480
                Layout.fillWidth: false
                Layout.fillHeight: true
                spacing: 10
                ClippingRectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 270
                    radius: Theme.radiusModule
                    color: Theme.module
                    Image {
                        id: preview
                        anchors.fill: parent
                        source: root.current ? root.current.thumb || root.current.url || "" : ""
                        asynchronous: true
                        sourceSize.width: 960
                        fillMode: Image.PreserveAspectCrop
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.fast
                            }
                        }
                    }
                    // A small mock of the shell over the picture: the bar and a panel lit with the accent it gives.
                    Item {
                        anchors.fill: parent
                        visible: preview.status === Image.Ready
                        Rectangle {
                            x: 10
                            y: 8
                            width: parent.width - 20
                            height: 12
                            radius: 5
                            color: Qt.rgba(Theme.caseColor.r, Theme.caseColor.g, Theme.caseColor.b, 0.85)
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            y: 28
                            width: 92
                            height: 120
                            radius: 8
                            color: Qt.rgba(Theme.caseColor.r, Theme.caseColor.g, Theme.caseColor.b, 0.9)
                            Rectangle {
                                x: 8
                                y: 8
                                width: parent.width - 16
                                height: 18
                                radius: 4
                                color: Qt.rgba(root.previewAccent.r, root.previewAccent.g, root.previewAccent.b, 0.25)
                            }
                            Rectangle {
                                x: 8
                                y: 34
                                width: parent.width - 38
                                height: 4
                                radius: 2
                                color: root.previewAccent
                            }
                        }
                        C.Label {
                            x: 12
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 10
                            width: parent.width - 130
                            text: root.current ? root.current.name : ""
                            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.8)
                            font.pixelSize: 12
                        }
                    }
                    C.Icon {
                        anchors.centerIn: parent
                        visible: !!root.current && preview.status !== Image.Ready
                        name: "palette"
                        size: 32
                        color: Theme.textFaint
                    }
                    C.EmptyState {
                        visible: !root.current
                        anchors.centerIn: parent
                        width: parent.width - 60
                        glyph: "palette"
                        title: root.loading ? "Finding wallpapers…" : root.error && root.online ? "Could not load wallpapers" : search.text ? "No matches" : "Your collection starts here"
                        description: root.loading ? (root.online ? root.sourceName : "Local collection") : root.error && root.online ? "" : search.text ? "No wallpapers match “" + search.text + "”" : root.online ? root.sourceName : (root.directory || "~/Pictures/Wallpapers")
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 0
                        C.Label {
                            text: root.current ? root.current.name : "No wallpaper selected"
                            font.pixelSize: 16
                            font.weight: 650
                            Layout.fillWidth: true
                        }
                        C.Label {
                            text: {
                                if (!root.current)
                                    return root.online ? root.sourceName : "Local collection";
                                const parts = root.online ? [root.current.resolution, root.current.path ? "Saved locally" : root.sourceName] : [root.current.file];
                                return parts.concat([(root.selected + 1) + " of " + root.filtered.length]).filter(part => !!part).join(" · ");
                            }
                            color: Theme.textDim
                            font.pixelSize: 12
                            font.features: ({"tnum": 1})
                            Layout.fillWidth: true
                        }
                    }
                    Repeater {
                        model: root.currentSwatches
                        Rectangle {
                            required property var modelData
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: 8
                            color: modelData.color
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.1)
                            Accessible.role: Accessible.StaticText
                            Accessible.name: modelData.role + " " + Palette.hex(modelData.color)
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gapS
                    C.Button {
                        visible: !root.online
                        text: "Open folder"
                        glyph: "folder"
                        implicitHeight: 34
                        enabled: root.directory !== ""
                        hint: root.directory
                        onClicked: ShellState.openPath(root.directory)
                    }
                    C.Button {
                        visible: root.sourceMode === "wallpaperscom"
                        text: "Wallpapers.com ↗"
                        flat: true
                        implicitHeight: 34
                        onClicked: ShellState.openUrl(root.current && root.current.creditUrl ? root.current.creditUrl : "https://wallpapers.com/")
                    }
                    C.Button {
                        visible: root.online && root.error !== ""
                        text: "Local"
                        flat: true
                        implicitHeight: 34
                        hint: "Your wallpaper folder"
                        enabled: !root.applying
                        onClicked: root.chooseSource("local")
                    }
                    C.Button {
                        visible: root.online && root.error !== ""
                        text: "Retry"
                        flat: true
                        implicitHeight: 34
                        enabled: !root.onlineLoading && !root.applying
                        onClicked: root.searchOnline(false)
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    C.Button {
                        text: ShellState.wallpaperDownloading ? "Saving…" : ShellState.wallpaperBusy ? "Applying…" : root.isCurrent ? "In use" : root.current && root.current.remote && !root.current.path ? "Save and use" : "Use wallpaper"
                        accent: !!root.current && !root.isCurrent
                        implicitHeight: 34
                        labelSize: 13
                        enabled: !!root.current && !root.isCurrent && !root.applying
                        hint: "Enter"
                        onClicked: root.apply()
                    }
                }
                C.Label {
                    visible: text !== ""
                    text: ShellState.wallpaperError || root.error || (!root.online && root.listedCount > 0 ? "Showing the first " + root.listedCount + " wallpapers" : "")
                    color: ShellState.wallpaperError ? Theme.dangerText : root.error ? Theme.warning : Theme.textDim
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                Item {
                    Layout.fillHeight: true
                }
            }
            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                // Tiles keep 4 px to each side, so neighbours sit 8 px apart and the selection ring has room.
                Layout.topMargin: -4
                Layout.leftMargin: -4
                Layout.rightMargin: -4
                clip: true
                cellWidth: width / root.columns
                cellHeight: 104
                boundsBehavior: Flickable.StopAtBounds
                model: root.gridModel
                ScrollBar.vertical: C.ScrollBar {}
                // Only local wallpapers have their colours read, so only they get dots.
                footer: C.Label {
                    visible: !root.online
                    width: grid.width
                    height: visible ? implicitHeight : 0
                    topPadding: 6
                    leftPadding: 6
                    rightPadding: 6
                    bottomPadding: 6
                    text: ShellState.setting("accentFromWallpaper", false)
                          ? "Each wallpaper gives the shell its accent colour and a second colour for charts. The dots are what you get."
                          : "The dots are the accent each wallpaper would give the shell. Turn on Match wallpaper in Settings → Appearance to use it."
                    color: Theme.textDim
                    font.pixelSize: 12
                    lineHeight: 1.25
                    wrapMode: Text.WordWrap
                }
                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool action: !!modelData.action
                    readonly property bool chosen: !action && index === root.selected
                    readonly property bool inUse: !action && !!modelData.path && modelData.path === root.activePath
                    // Set once this tile saved its small copy, so its colours can be read without the original.
                    property string savedCopy: ""
                    width: grid.cellWidth
                    height: grid.cellHeight
                    // The ring sits just outside the tile.
                    Rectangle {
                        anchors.fill: face
                        anchors.margins: -2
                        visible: tile.chosen
                        radius: Theme.radiusCard + 2
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.accent
                    }
                    ClippingRectangle {
                        id: face
                        visible: !tile.action
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: Theme.radiusCard
                        color: Theme.module
                        Image {
                            id: thumbnail
                            // A local wallpaper's small copy once it exists (see wallpaper.catalog). The first time,
                            // the original is decoded and the result saved as that copy, so later opens skip the decode.
                            property bool copyBroken: false
                            property bool copySaved: false
                            readonly property string original: tile.action ? "" : tile.modelData.url
                            anchors.fill: parent
                            source: tile.action ? "" : tile.modelData.thumb && !copyBroken ? tile.modelData.thumb : original
                            asynchronous: true
                            sourceSize.width: 760
                            sourceSize.height: 480
                            cache: true
                            fillMode: Image.PreserveAspectCrop
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.enter } }
                            function saveCopy() {
                                const path = tile.modelData.thumbPath;
                                if (copySaved || !path || status !== Image.Ready || source.toString() !== original || width <= 0)
                                    return;
                                copySaved = grabToImage(result => {
                                    if (result.saveToFile(path))
                                        tile.savedCopy = "file://" + path.split("/").map(encodeURIComponent).join("/");
                                }, Qt.size(760, Math.round(760 * height / width)));
                            }
                            onStatusChanged: {
                                if (status === Image.Error && tile.modelData.thumb && !copyBroken)
                                    copyBroken = true;
                                else
                                    saveCopy();
                            }
                        }
                        C.Icon {
                            anchors.centerIn: parent
                            name: "palette"
                            size: 22
                            color: Theme.textFaint
                            visible: thumbnail.status !== Image.Ready
                        }
                        // Keeps the name readable over bright pictures.
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 34
                            gradient: Gradient {
                                GradientStop { position: 0; color: "transparent" }
                                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.45) }
                            }
                        }
                        Row {
                            x: 8
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            width: parent.width - 16
                            spacing: 6
                            Rectangle {
                                id: dot
                                readonly property string accent: tileColors.item ? Palette.accentFrom(tileColors.item.colors) : ""
                                anchors.verticalCenter: parent.verticalCenter
                                visible: accent !== ""
                                width: 8
                                height: 8
                                radius: 4
                                color: accent !== "" ? accent : Theme.accent
                            }
                            C.Label {
                                width: parent.width - (dot.visible ? 14 : 0)
                                text: tile.action ? "" : tile.modelData.name
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                style: Text.Raised
                                styleColor: Qt.rgba(0, 0, 0, 0.35)
                            }
                        }
                        Rectangle {
                            visible: tile.inUse
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 6
                            implicitWidth: inUseLabel.implicitWidth + 14
                            implicitHeight: 18
                            radius: 6
                            color: Qt.rgba(Theme.caseColor.r, Theme.caseColor.g, Theme.caseColor.b, 0.85)
                            C.Label {
                                id: inUseLabel
                                anchors.centerIn: parent
                                text: "In use"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                        }
                        LazyLoader {
                            id: tileColors
                            readonly property string image: tile.action ? "" : tile.modelData.thumb || tile.savedCopy
                            active: image !== ""
                            ColorQuantizer {
                                source: tileColors.image
                                depth: 3
                                rescaleSize: 32
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.applying
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.selected = tile.index; root.forceActiveFocus(); }
                            onDoubleClicked: { root.selected = tile.index; root.apply(); }
                        }
                        Accessible.role: Accessible.Button
                        Accessible.name: tile.action ? "" : tile.modelData.name + (tile.inUse ? ", in use" : "")
                    }
                    // The last tile: add images to the folder, or fetch the next page of results.
                    C.Button {
                        id: actionTile
                        visible: tile.action
                        anchors.fill: parent
                        anchors.margins: 4
                        flat: true
                        cornerRadius: Theme.radiusCard
                        enabled: root.online ? !root.onlineLoading && !root.applying : root.directory !== ""
                        text: root.online ? (root.onlineLoading ? "Loading…" : "Load more") : "Add wallpapers"
                        hint: root.online ? "" : "Open " + root.directory + " and add images to it"
                        onClicked: root.online ? root.searchOnline(true) : ShellState.openPath(root.directory)
                        contentItem: ColumnLayout {
                            spacing: 6
                            C.Icon {
                                name: root.online ? "chevron" : "plus"
                                size: 18
                                color: actionTile.hovered || actionTile.visualFocus ? Theme.text : Theme.textMuted
                                Layout.alignment: Qt.AlignHCenter
                            }
                            C.Label {
                                text: actionTile.text
                                color: actionTile.hovered || actionTile.visualFocus ? Theme.text : Theme.textMuted
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                        // A dashed edge, drawn as a path: rectangles only draw solid borders.
                        Shape {
                            anchors.fill: parent
                            z: -1
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                id: dash
                                readonly property real r: Theme.radiusCard
                                readonly property real w: actionTile.width - 1.5
                                readonly property real h: actionTile.height - 1.5
                                strokeColor: Theme.mix(Theme.caseColor, Theme.text, 0.18)
                                strokeWidth: 1.5
                                strokeStyle: ShapePath.DashLine
                                dashPattern: [3, 2]
                                fillColor: "transparent"
                                PathSvg {
                                    path: {
                                        const p = dash, o = 0.75;
                                        return "M " + (o + p.r) + " " + o + " H " + (o + p.w - p.r) + " A " + p.r + " " + p.r + " 0 0 1 " + (o + p.w) + " " + (o + p.r)
                                             + " V " + (o + p.h - p.r) + " A " + p.r + " " + p.r + " 0 0 1 " + (o + p.w - p.r) + " " + (o + p.h)
                                             + " H " + (o + p.r) + " A " + p.r + " " + p.r + " 0 0 1 " + o + " " + (o + p.h - p.r)
                                             + " V " + (o + p.r) + " A " + p.r + " " + p.r + " 0 0 1 " + (o + p.r) + " " + o + " Z";
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Timer {
        id: onlineDebounce
        interval: 500
        onTriggered: root.searchOnline(false)
    }
    Keys.onLeftPressed: move(-1)
    Keys.onRightPressed: move(1)
    Keys.onUpPressed: move(-columns)
    Keys.onDownPressed: move(columns)
    Keys.onReturnPressed: apply()
}
