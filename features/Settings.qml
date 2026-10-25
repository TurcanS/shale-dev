import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../core"
import "../core/paths.js" as Paths
import "../components" as C

// Settings: the sections with their icons and Find a setting on the left; the chosen page on the right, its settings
// in grouped cards of rows. Typing in Find a setting lists matching rows from every page; picking one opens its page
// and lights the row up.
FocusScope {
    id: root
    readonly property string title: "Settings"
    readonly property int panelWidth: 1060
    readonly property int panelHeight: 680
    // The sidebar carries the title; Escape or a click outside closes.
    readonly property bool showHeader: false
    property string category: "Appearance"
    property string query: ""
    property real pageProgress: 1
    // The installer writes the commit it installed next to shell.qml; a checkout run directly has none.
    property string version: ""
    FileView {
        path: Paths.localPath(Qt.resolvedUrl("../COMMIT"))
        printErrors: false
        onLoaded: root.version = text().trim().split("\n")[0].slice(0, 40)
    }
    NumberAnimation {
        id: pageEntrance
        target: root
        property: "pageProgress"
        from: 0
        to: 1
        duration: Theme.panelEnter
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easeOut
    }
    // A folder setting with its own error and a short confirmation once saved.
    component FolderField: C.SettingRow {
        id: folder
        property string key: ""
        property string fallback: ""
        property string note: ""
        property string error: ""
        property bool saved: false
        function save(value) {
            const path = value.trim();
            if (!(path.startsWith("~/") || path.startsWith("/")) || /[\r\n]/.test(path)) {
                error = "Enter an absolute folder path or a path beginning with ~/";
                return;
            }
            error = "";
            if (path === ShellState.setting(key, fallback))
                return;
            ShellState.setSetting(key, path);
            saved = true;
            savedTimer.restart();
        }
        description: error || (saved ? "Saved" : note)
        descriptionColor: error ? Theme.dangerText : saved ? Theme.success : Theme.textDim
        C.Field {
            Layout.preferredWidth: 280
            implicitHeight: 36
            font.pixelSize: Theme.label
            Accessible.name: folder.label
            text: ShellState.setting(folder.key, folder.fallback)
            onTextEdited: folder.saved = false
            onEditingFinished: folder.save(text)
        }
        Timer {
            id: savedTimer
            interval: 2500
            onTriggered: folder.saved = false
        }
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
    // A row whose control is one button that opens something.
    component OpenRow: C.SettingRow {
        id: openRow
        property string action: "Open"
        property string glyph: ""
        signal opened()
        C.Button {
            text: openRow.action
            glyph: openRow.glyph
            implicitHeight: 32
            onClicked: openRow.opened()
        }
    }
    // A value shown at the right of a row, for facts rather than choices.
    component ValueRow: C.SettingRow {
        id: valueRow
        property string value: ""
        property color valueColor: Theme.textSecondary
        property bool mono: false
        C.Label {
            text: valueRow.value
            color: valueRow.valueColor
            font.family: valueRow.mono ? Theme.mono : Theme.font
            font.pixelSize: valueRow.mono ? Theme.small : Theme.label
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            Layout.maximumWidth: 320
        }
    }
    // Aliases keep older names working: `shale settings control-center`, Find's "settings:Control center", and the
    // Motion and Audio pages, now part of Appearance and Sound.
    readonly property var categories: [
        {name: "Appearance", icon: "palette", aliases: ["motion"], description: "Colour, size, motion, wallpaper and the lock screen."},
        {name: "Displays", icon: "monitor", description: "Resolution, refresh rate and scale for each screen."},
        {name: "Bar", icon: "bar", description: "Put bar items in order, and choose how the bar looks."},
        {name: "Control", icon: "sliders", aliases: ["control center"], description: "What the Control panel shows, and in which order."},
        {name: "Desktop", icon: "widgets", aliases: ["widgets"], description: "Widgets on the desktop: which cards, their order and their corner."},
        {name: "Shortcuts", icon: "keyboard", description: "Keyboard shortcuts and what they open."},
        {name: "General", icon: "settings", description: "Time, units, search, the terminal and updates."},
        {name: "Notifications", icon: "bell", description: "History and focus sessions."},
        {name: "Sound", icon: "volume", aliases: ["audio"], description: "Volume limits and the player."},
        {name: "Capture", icon: "camera", description: "Screenshots and recordings, and where they go."},
        {name: "Activity", icon: "pulse", description: "Your private desktop history."},
        {name: "Backup", icon: "folder", description: "Keep a copy of your settings or move them."},
        {name: "Diagnostics", icon: "info", description: "The services behind your desktop."}
    ]
    // The settings each page owns, for its reset button.
    readonly property var resetKeys: ({
            Appearance: ["fontSize", "panelSize", "accentColor", "accentManual", "accentFromWallpaper", "surfaceTone", "visualizer", "wallpaperDirectory", "lockScreen", "lockStyle",
                         "reducedMotion", "batterySaving", "windowPreviews"],
            Bar: ["hideFullscreen", "barMedia", "trackChangeCard", "hiddenOutputs", "barLayout", "barStyle", "clockFormat", "clockSeconds",
                  "workspaceStyle", "workspaceSlots", "trayIcons", "batteryPercent"],
            Control: ["controlLayout"],
            Desktop: ["widgets", "widgetCards", "widgetCorner"],
            General: ["clock24h", "weekStart", "weatherUnits", "searchEngine", "terminal", "updateCheck"],
            Notifications: ["persistNotifications", "focusMinutes"],
            Sound: ["amplification", "mediaRemaining"],
            Capture: ["screenshotDirectory", "recordingDirectory", "recordAudio", "captureDelay"]
        })
    readonly property var currentCategory: categories.find(item => item.name === category) || categories[0]
    // Opens a page by its name or as typed after `shale settings` ("control-center").
    function showPage(name) {
        const wanted = String(name || "").toLowerCase().replace(/[-_]/g, " ").trim();
        const found = categories.find(item => item.name.toLowerCase() === wanted || (item.aliases || []).indexOf(wanted) >= 0);
        if (found)
            category = found.name;
    }
    Component.onCompleted: showPage(ShellState.detail)
    Connections {
        target: ShellState
        function onDetailChanged() {
            if (ShellState.panel === "settings")
                root.showPage(ShellState.detail);
        }
    }
    onCategoryChanged: {
        settingsScroll.contentItem.contentY = 0;
        pageEntrance.restart();
    }
    // For previews of long pages.
    function scrollTo(y) {
        settingsScroll.contentItem.contentY = Math.max(0, Math.min(y, settingsScroll.contentItem.contentHeight - settingsScroll.height));
    }

    // Find a setting. Rows are read from the pages themselves (every row with a name and a description line: toggles,
    // choices and the rest), so whatever a page shows can be found, its own words included.
    readonly property var results: query.trim() === "" ? [] : search(query)
    function collect(item, out) {
        const children = item.children;
        for (let i = 0; i < children.length; i++) {
            const child = children[i];
            // Hold-to-reset buttons have a description too; they aren't settings.
            if (child.description !== undefined && child.triggered === undefined) {
                const label = child.label !== undefined ? child.label : child.text;
                if (typeof label === "string" && label !== "")
                    out.push({label: label, description: String(child.description || ""), item: child});
            }
            collect(child, out);
        }
    }
    function search(text) {
        const words = text.toLowerCase().split(/\s+/).filter(word => word !== "");
        const fits = haystack => words.every(word => haystack.indexOf(word) >= 0);
        // Names that start with what was typed first, then names that hold it, then the rest.
        const rank = label => label.toLowerCase().startsWith(words[0]) ? 0 : label.toLowerCase().indexOf(words[0]) >= 0 ? 1 : 2;
        const found = [];
        const seen = {};
        function add(page, label, description, item) {
            const key = page + "\n" + label.toLowerCase();
            if (seen[key])
                return;
            seen[key] = true;
            found.push({page: page, label: label, description: description, item: item, rank: rank(label) * 1000 + found.length});
        }
        for (const entry of categories) {
            if (fits([entry.name].concat(entry.aliases || [], [entry.description]).join(" ").toLowerCase()))
                add(entry.name, entry.name, entry.description, null);
        }
        for (let i = 0; i < pages.children.length; i++) {
            const page = pages.children[i];
            if (!page.objectName)
                continue;
            const rows = [];
            collect(page, rows);
            for (const row of rows) {
                if (fits((row.label + " " + row.description + " " + page.objectName).toLowerCase()))
                    add(page.objectName, row.label, row.description, row.item);
            }
        }
        found.sort((a, b) => a.rank - b.rank);
        return found.slice(0, 40);
    }
    // Opens a result's page and lights its row up once the page has laid out.
    function openResult(result) {
        if (!result)
            return;
        category = result.page;
        flash.opacity = 0;
        revealTimer.target = result.item;
        revealTimer.restart();
    }
    Timer {
        id: revealTimer
        property Item target: null
        interval: 40
        onTriggered: {
            const item = target;
            if (!item || !item.visible || item.height <= 0)
                return;
            const at = item.mapToItem(scrollContent, 0, 0);
            root.scrollTo(at.y - 48);
            flash.x = at.x;
            flash.y = at.y;
            flash.width = item.width;
            flash.height = item.height;
            flashAnimation.restart();
        }
    }
    function focusSearch() {
        searchField.forceActiveFocus();
        searchField.selectAll();
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
            root.focusSearch();
            event.accepted = true;
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.casePadding

        // Sidebar: title, Find a setting, then the sections (or what Find a setting found).
        ColumnLayout {
            Layout.preferredWidth: root.width < 860 ? 196 : 230
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 2
            C.Label {
                text: "Settings"
                font.pixelSize: 17
                font.weight: 650
                elide: Text.ElideNone
                Layout.leftMargin: 10
                Layout.topMargin: 6
                Layout.bottomMargin: 10
                Accessible.role: Accessible.Heading
            }
            C.Field {
                id: searchField
                focus: true
                Layout.fillWidth: true
                Layout.bottomMargin: 8
                implicitHeight: 34
                leftPadding: 32
                rightPadding: clearSearch.visible ? 34 : 10
                font.pixelSize: Theme.label
                placeholderText: "Find a setting"
                Accessible.name: "Find a setting"
                text: root.query
                onTextEdited: root.query = text
                onAccepted: root.openResult(root.results[0])
                Keys.onEscapePressed: event => {
                    if (text !== "") {
                        root.query = "";
                        event.accepted = true;
                    } else {
                        event.accepted = false;
                    }
                }
                Keys.onDownPressed: {
                    const first = root.query.trim() !== "" ? resultItems.itemAt(0) : navigationItems.itemAt(Math.max(0, root.categories.indexOf(root.currentCategory)));
                    if (first)
                        first.forceActiveFocus(Qt.TabFocusReason);
                }
                C.Icon {
                    anchors.left: parent.left
                    anchors.leftMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    size: 14
                    color: Theme.textDim
                }
                C.Button {
                    id: clearSearch
                    visible: searchField.text !== ""
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "close"
                    flat: true
                    hint: "Clear"
                    focusPolicy: Qt.NoFocus
                    implicitWidth: 26
                    implicitHeight: 26
                    onClicked: {
                        root.query = "";
                        searchField.forceActiveFocus();
                    }
                }
            }
            Flickable {
                id: navigation
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: root.query.trim() === "" ? sections.implicitHeight : resultList.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                ScrollBar.vertical: C.ScrollBar {}
                ColumnLayout {
                    id: sections
                    visible: root.query.trim() === ""
                    width: navigation.width
                    spacing: 2
                    Repeater {
                        id: navigationItems
                        model: root.categories
                        C.Button {
                            id: section
                            required property var modelData
                            required property int index
                            text: modelData.name
                            selected: root.category === modelData.name
                            Layout.fillWidth: true
                            implicitHeight: Math.max(38, Theme.body + 24)
                            leftPadding: 10
                            rightPadding: 10
                            cornerRadius: Theme.radiusKey
                            Accessible.role: Accessible.PageTab
                            onClicked: root.category = modelData.name
                            Keys.onDownPressed: {
                                const next = navigationItems.itemAt(Math.min(index + 1, root.categories.length - 1));
                                root.category = next.modelData.name;
                                next.forceActiveFocus(Qt.TabFocusReason);
                            }
                            Keys.onUpPressed: {
                                if (index === 0) {
                                    searchField.forceActiveFocus();
                                    return;
                                }
                                const previous = navigationItems.itemAt(index - 1);
                                root.category = previous.modelData.name;
                                previous.forceActiveFocus(Qt.TabFocusReason);
                            }
                            // The chosen section is an accent wash with accent text; the others light up under the pointer.
                            background: Rectangle {
                                radius: Theme.radiusKey
                                color: section.selected ? Theme.accentSoft : section.hovered || section.visualFocus || section.down ? section.wash : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.fast } }
                            }
                            contentItem: RowLayout {
                                spacing: 10
                                C.Icon {
                                    name: section.modelData.icon
                                    size: 17
                                    color: section.selected ? Theme.accentText : Theme.textSecondary
                                }
                                C.Label {
                                    text: section.text
                                    color: section.selected ? Theme.accentText : Theme.textSecondary
                                    font.weight: section.selected ? Font.DemiBold : Font.Medium
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }
                ColumnLayout {
                    id: resultList
                    visible: root.query.trim() !== ""
                    width: navigation.width
                    spacing: 2
                    C.Label {
                        visible: root.results.length === 0
                        text: "No setting matches “" + root.query.trim() + "”"
                        color: Theme.textDim
                        font.pixelSize: Theme.label
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        Layout.topMargin: 6
                    }
                    Repeater {
                        id: resultItems
                        model: root.results
                        C.Button {
                            id: result
                            required property var modelData
                            required property int index
                            readonly property string where: modelData.label === modelData.page ? modelData.description : modelData.page
                            text: modelData.label
                            Layout.fillWidth: true
                            implicitHeight: resultText.implicitHeight + 16
                            leftPadding: 10
                            rightPadding: 10
                            cornerRadius: Theme.radiusKey
                            Accessible.description: where
                            onClicked: root.openResult(modelData)
                            Keys.onReturnPressed: root.openResult(modelData)
                            Keys.onEnterPressed: root.openResult(modelData)
                            Keys.onDownPressed: {
                                const next = resultItems.itemAt(index + 1);
                                if (next)
                                    next.forceActiveFocus(Qt.TabFocusReason);
                            }
                            Keys.onUpPressed: {
                                const previous = resultItems.itemAt(index - 1);
                                if (previous)
                                    previous.forceActiveFocus(Qt.TabFocusReason);
                                else
                                    searchField.forceActiveFocus();
                            }
                            onActiveFocusChanged: if (activeFocus) {
                                if (y < navigation.contentY)
                                    navigation.contentY = y;
                                else if (y + height > navigation.contentY + navigation.height)
                                    navigation.contentY = y + height - navigation.height;
                            }
                            background: Rectangle {
                                radius: Theme.radiusKey
                                color: result.hovered || result.visualFocus || result.down ? result.wash : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.fast } }
                            }
                            contentItem: ColumnLayout {
                                id: resultText
                                spacing: 1
                                C.Label {
                                    text: result.text
                                    font.weight: Font.Medium
                                    Layout.fillWidth: true
                                }
                                C.Label {
                                    visible: text !== ""
                                    text: result.where
                                    color: Theme.textDim
                                    font.pixelSize: Theme.small
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }
            }
        }

        // The page: its title and a line about it, then its groups, scrolling under the title.
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusModule
            color: Theme.moduleAlt
            clip: true
            ColumnLayout {
                id: pageHeader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                anchors.topMargin: 22
                spacing: 4
                C.Label {
                    text: root.category
                    font.pixelSize: Math.max(22, Theme.body + 8)
                    font.weight: 650
                    Layout.fillWidth: true
                    Accessible.role: Accessible.Heading
                }
                C.Label {
                    text: root.currentCategory.description
                    color: Theme.textDim
                    font.pixelSize: Theme.label
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
            ScrollView {
                id: settingsScroll
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: pageHeader.bottom
                anchors.bottom: parent.bottom
                anchors.leftMargin: 24
                anchors.topMargin: 12
                contentWidth: availableWidth
                clip: true
                opacity: root.pageProgress
                ScrollBar.vertical: C.ScrollBar {
                    parent: settingsScroll
                    x: settingsScroll.width - width - 8
                    y: settingsScroll.topPadding
                    height: settingsScroll.availableHeight - 8
                }
                Item {
                    id: scrollContent
                    width: settingsScroll.availableWidth - 24
                    implicitHeight: pages.implicitHeight + 22
                    transform: Translate { y: (1 - root.pageProgress) * Theme.panelRise * 0.75 }
                    ColumnLayout {
                        id: pages
                        width: parent.width
                        spacing: Theme.gapM

                        // Appearance: colour, size, behaviour, wallpaper and lock screen.
                        ColumnLayout {
                            objectName: "Appearance"
                            visible: root.category === objectName
                            Layout.fillWidth: true
                            spacing: 8
                            ColorSettings {
                                Layout.fillWidth: true
                            }
                            C.SectionHeader { text: "Size" }
                            C.Group {
                                C.ChoiceRow {
                                    label: "Text size"
                                    description: "In panels; the bar keeps its own"
                                    model: [12, 14, 16, 18].map(size => ({key: size, text: String(size)}))
                                    current: Theme.body
                                    onActivated: key => ShellState.setSetting("fontSize", key)
                                }
                                C.ChoiceRow {
                                    label: "Panel size"
                                    description: "How large panels are drawn"
                                    model: [80, 85, 90, 100].map(size => ({key: size, text: size + "%"}))
                                    current: ShellState.setting("panelSize", 85)
                                    onActivated: key => ShellState.setSetting("panelSize", key)
                                }
                            }
                            C.SectionHeader { text: "Behaviour" }
                            C.Group {
                                SettingToggle {
                                    text: "Reduce motion"
                                    description: "Panels and controls change without animating"
                                    key: "reducedMotion"
                                }
                                SettingToggle {
                                    text: "Reduce effects in every mode"
                                    description: "No visualizers, blur, shadows or live window previews"
                                    key: "batterySaving"
                                }
                                SettingToggle {
                                    text: "Window preview snapshots"
                                    description: "Pictures of windows in Pages"
                                    key: "windowPreviews"
                                    fallback: true
                                }
                                SettingToggle {
                                    text: "Music visualizer"
                                    description: "In the bar and on the Player"
                                    key: "visualizer"
                                    fallback: true
                                }
                            }
                            C.SectionHeader { text: "Wallpaper" }
                            C.Group {
                                FolderField {
                                    label: "Wallpaper folder"
                                    note: "Where Wallpapers looks for pictures"
                                    key: "wallpaperDirectory"
                                    fallback: "~/Pictures/Wallpapers"
                                }
                                OpenRow {
                                    label: "Wallpaper"
                                    description: "Pick from the folder or find new ones"
                                    action: "Choose wallpaper"
                                    glyph: "image"
                                    onOpened: ShellState.open("wallpaper")
                                }
                            }
                            C.SectionHeader { text: "Lock screen" }
                            C.Group {
                                C.Toggle {
                                    readonly property bool hyprlock: Backend.has("hyprlock", true)
                                    readonly property bool builtin: ShellState.setting("lockScreen", "builtin") === "builtin" || !hyprlock
                                    Layout.fillWidth: true
                                    flat: true
                                    enabled: hyprlock
                                    text: "Use the built-in lock screen"
                                    description: !hyprlock ? "Install hyprlock to use it instead." : builtin ? "Blurred wallpaper, clock and media controls. hyprlock takes over if the shell stops." : "hyprlock locks the screen."
                                    selected: builtin
                                    onClicked: ShellState.setSetting("lockScreen", builtin ? "hyprlock" : "builtin")
                                }
                                C.ChoiceRow {
                                    visible: ShellState.setting("lockScreen", "builtin") === "builtin" || !Backend.has("hyprlock", true)
                                    label: "Style"
                                    description: ShellState.setting("lockStyle", "particles") === "classic" ? "A large clock over your wallpaper" : "The time drawn in points of light that gather, shift and burst"
                                    model: [{key: "particles", text: "Particles"}, {key: "classic", text: "Classic"}]
                                    current: ShellState.setting("lockStyle", "particles")
                                    onActivated: key => ShellState.setSetting("lockStyle", key)
                                }
                            }
                        }

                        DisplaySettings {
                            objectName: "Displays"
                            visible: root.category === objectName
                            Layout.fillWidth: true
                        }
                        BarSettings {
                            objectName: "Bar"
                            visible: root.category === objectName
                            Layout.fillWidth: true
                        }
                        ControlSettings {
                            objectName: "Control"
                            visible: root.category === objectName
                            Layout.fillWidth: true
                        }
                        DesktopSettings {
                            objectName: "Desktop"
                            visible: root.category === objectName
                            Layout.fillWidth: true
                        }
                        ShortcutSettings {
                            objectName: "Shortcuts"
                            visible: root.category === objectName
                            Layout.fillWidth: true
                        }

                        // General: time and units, search and the terminal, updates.
                        ColumnLayout {
                            objectName: "General"
                            visible: root.category === objectName
                            Layout.fillWidth: true
                            spacing: 8
                            C.SectionHeader { text: "Time and units" }
                            C.Group {
                                SettingToggle {
                                    text: "24-hour clock"
                                    description: "Everywhere Shale shows the time"
                                    key: "clock24h"
                                    fallback: true
                                }
                                C.ChoiceRow {
                                    label: "Week starts on"
                                    description: "In the calendar and Activity"
                                    model: [{key: "locale", text: "Auto", hint: "As your language and region have it"}, {key: "monday", text: "Mon"}, {key: "sunday", text: "Sun"}, {key: "saturday", text: "Sat"}]
                                    current: ShellState.setting("weekStart", "locale")
                                    onActivated: key => ShellState.setSetting("weekStart", key)
                                }
                                C.ChoiceRow {
                                    label: "Weather units"
                                    description: "Temperature and wind"
                                    model: [{key: "metric", text: "°C, km/h"}, {key: "imperial", text: "°F, mph"}]
                                    current: ShellState.setting("weatherUnits", "metric")
                                    onActivated: key => ShellState.setSetting("weatherUnits", key)
                                }
                            }
                            C.SectionHeader { text: "Search and terminal" }
                            C.Group {
                                C.ChoiceRow {
                                    label: "Web search"
                                    description: "Type ? in Find"
                                    model: [{key: "duckduckgo", text: "DuckDuckGo"}, {key: "google", text: "Google"}, {key: "brave", text: "Brave"}]
                                    current: ShellState.setting("searchEngine", "duckduckgo")
                                    onActivated: key => ShellState.setSetting("searchEngine", key)
                                }
                                C.ChoiceRow {
                                    readonly property string chosen: ShellState.setting("terminal", "auto")
                                    readonly property var installed: Backend.capabilities.terminals || []
                                    label: "Terminal"
                                    description: "For commands run with > in Find"
                                    model: [{key: "auto", text: "Auto", hint: "$TERMINAL or the first one installed"}]
                                        .concat(installed.concat(chosen !== "auto" && installed.indexOf(chosen) < 0 ? [chosen] : []).map(name => ({key: name, text: name})))
                                    // Many terminals don't fit beside the name.
                                    stacked: model.length > 4
                                    current: chosen
                                    onActivated: key => ShellState.setSetting("terminal", key)
                                }
                            }
                            C.SectionHeader { text: "Updates" }
                            C.Group {
                                SettingToggle {
                                    text: "Check for updates"
                                    description: "Asks GitHub every 12 hours. Control shows what a new version changes."
                                    key: "updateCheck"
                                    fallback: true
                                }
                            }
                        }

                        // Notifications: history and focus sessions.
                        ColumnLayout {
                            objectName: "Notifications"
                            visible: root.category === objectName
                            Layout.fillWidth: true
                            spacing: 8
                            C.Group {
                                SettingToggle {
                                    text: "Keep notification history across restarts"
                                    description: "Up to 200 notifications for seven days. Contents stay hidden on the lock screen."
                                    key: "persistNotifications"
                                }
                                C.ChoiceRow {
                                    label: "Focus length"
                                    description: "Notifications wait until a focus session ends"
                                    model: [25, 50, 90].map(minutes => ({key: minutes, text: minutes + " min"}))
                                    current: ShellState.setting("focusMinutes", 25)
                                    onActivated: key => ShellState.setSetting("focusMinutes", key)
                                }
                            }
                        }

                        // Sound: volume limits, the player's time and the equalizer.
                        ColumnLayout {
                            objectName: "Sound"
                            visible: root.category === objectName
                            Layout.fillWidth: true
                            spacing: 8
                            C.Group {
                                SettingToggle {
                                    text: "Allow volume amplification up to 150%"
                                    description: "Volume sliders go past 100%"
                                    key: "amplification"
                                }
                                SettingToggle {
                                    text: "Show time left instead of track length"
                                    description: "On the Player"
                                    key: "mediaRemaining"
                                }
                                OpenRow {
                                    label: "Equalizer"
                                    description: "Curves for the output, in Control → Sound"
                                    action: "Open the equalizer"
                                    glyph: "equalizer"
                                    onOpened: {
                                        ShellState.open("control");
                                        ShellState.detail = "audio";
                                    }
                                }
                            }
                        }

                        // Capture: recording sound, delay and folders.
                        ColumnLayout {
                            objectName: "Capture"
                            visible: root.category === objectName
                            Layout.fillWidth: true
                            spacing: 8
                            C.Group {
                                C.ChoiceRow {
                                    label: "Recording sound"
                                    description: "What a screen recording hears"
                                    model: [{key: "none", text: "None"}, {key: "system", text: "System"}, {key: "microphone", text: "Microphone"}]
                                    current: ShellState.setting("recordAudio", "none")
                                    onActivated: key => ShellState.setSetting("recordAudio", key)
                                }
                                C.ChoiceRow {
                                    label: "Screenshot delay"
                                    description: "Time to set the screen up first"
                                    model: [0, 3, 5, 10].map(seconds => ({key: seconds, text: seconds ? seconds + " s" : "None"}))
                                    current: ShellState.setting("captureDelay", 0)
                                    onActivated: key => ShellState.setSetting("captureDelay", key)
                                }
                            }
                            C.SectionHeader { text: "Folders" }
                            C.Group {
                                FolderField {
                                    label: "Screenshot folder"
                                    note: "Saved screenshots go here"
                                    key: "screenshotDirectory"
                                    fallback: "~/Pictures/Screenshots"
                                }
                                FolderField {
                                    label: "Recording folder"
                                    note: "Screen recordings go here"
                                    key: "recordingDirectory"
                                    fallback: "~/Videos/Recordings"
                                }
                            }
                        }

                        // Activity: recording on or off, and the panel.
                        ColumnLayout {
                            objectName: "Activity"
                            visible: root.category === objectName
                            Layout.fillWidth: true
                            spacing: 8
                            C.Group {
                                C.Toggle {
                                    Layout.fillWidth: true
                                    flat: true
                                    text: "Record activity"
                                    description: "How long you use each app and when you're active. It stays on this computer."
                                    selected: ShellState.setting("activityTracking", "ask") === "on"
                                    onClicked: ShellState.setSetting("activityTracking", selected ? "off" : "on")
                                }
                                OpenRow {
                                    label: "Activity"
                                    description: "Your day, the year and the apps you use most"
                                    action: "Open activity"
                                    glyph: "activity"
                                    onOpened: ShellState.open("activity")
                                }
                            }
                            C.Label {
                                text: "Active time ends at your last input; time with a video playing or an app keeping the screen awake counts as watching. Only app IDs and time ranges are kept, never window titles, until you clear them. Pause recording or hold Clear history in the Activity panel."
                                color: Theme.textDim
                                font.pixelSize: Theme.small
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        BackupSettings {
                            objectName: "Backup"
                            visible: root.category === objectName
                            Layout.fillWidth: true
                        }

                        // Diagnostics: the helper, the version, the commands Shale uses and the system monitor.
                        ColumnLayout {
                            objectName: "Diagnostics"
                            visible: root.category === objectName
                            Layout.fillWidth: true
                            spacing: 8
                            C.Group {
                                C.SettingRow {
                                    label: "Desktop helper"
                                    description: Backend.ready ? "Desktop services are available" : "Desktop controls may be unavailable"
                                    // A status chip: green dot and Connected, or a danger wash while the helper is away.
                                    Rectangle {
                                        implicitWidth: statusRow.implicitWidth + 20
                                        implicitHeight: 28
                                        radius: 14
                                        color: Backend.ready ? "transparent" : Theme.dangerWash
                                        border.width: 1
                                        border.color: Backend.ready ? Theme.edge : Theme.dangerLine
                                        RowLayout {
                                            id: statusRow
                                            anchors.centerIn: parent
                                            spacing: 6
                                            Rectangle {
                                                implicitWidth: 7
                                                implicitHeight: 7
                                                radius: 3.5
                                                color: Backend.ready ? Theme.success : Theme.danger
                                            }
                                            C.Label {
                                                text: Backend.ready ? "Connected" : "Helper offline"
                                                color: Backend.ready ? Theme.textSecondary : Theme.dangerText
                                                font.pixelSize: Theme.small
                                                font.weight: Font.DemiBold
                                            }
                                        }
                                    }
                                }
                                ValueRow {
                                    label: "Version"
                                    description: "The commit the installer put in place"
                                    value: root.version ? "Shale " + root.version : "Shale · version unknown"
                                    mono: true
                                }
                                ValueRow {
                                    label: "D-Bus adapter"
                                    description: "For Wi-Fi and power controls"
                                    value: Backend.capabilities.dbus ? "Available" : "Install python-dbus-next"
                                    valueColor: Backend.capabilities.dbus ? Theme.success : Theme.warning
                                }
                            }
                            C.Label {
                                text: ShellState.settings.diagnostic || Backend.lastError
                                visible: text !== ""
                                color: Theme.warning
                                font.pixelSize: Theme.small
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            C.SectionHeader { text: "Commands" }
                            C.Group {
                                Repeater {
                                    model: Object.keys(Backend.capabilities.commands || {})
                                    RowLayout {
                                        id: command
                                        required property string modelData
                                        readonly property bool available: Backend.has(modelData, false)
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Math.max(40, Theme.body + 24)
                                        Layout.leftMargin: Theme.gapL
                                        Layout.rightMargin: Theme.gapL
                                        spacing: Theme.gapM
                                        C.Label {
                                            text: command.modelData
                                            font.family: Theme.mono
                                            font.pixelSize: Theme.small
                                            wrapMode: Text.WrapAnywhere
                                            Layout.fillWidth: true
                                        }
                                        C.Label {
                                            text: command.available ? "Available" : "Not installed"
                                            color: command.available ? Theme.success : Theme.textDim
                                            font.pixelSize: Theme.small
                                        }
                                    }
                                }
                            }
                            C.SectionHeader { text: "System monitor" }
                            C.Group {
                                C.ChoiceRow {
                                    label: "System monitor graphs"
                                    description: "How far back the graphs reach"
                                    model: [{key: 60, text: "1 min"}, {key: 300, text: "5 min"}]
                                    current: ShellState.setting("systemWindow", 60)
                                    onActivated: key => ShellState.setSetting("systemWindow", key)
                                }
                                OpenRow {
                                    label: "System monitor"
                                    description: "Processor, memory, disks, network and graphics, live"
                                    action: "Open system monitor"
                                    glyph: "gauge"
                                    onOpened: ShellState.open("system")
                                }
                            }
                        }

                        C.ResetButton {
                            visible: !!root.resetKeys[root.category]
                            Layout.topMargin: Theme.gapS
                            description: "Hold to put this page back to how Shale comes"
                            onConfirmed: {
                                const page = root.category;
                                ShellState.resetSettings(root.resetKeys[page], () => ShellState.message(page + " settings reset", "success"));
                            }
                        }
                    }
                    // Lights up the row a search result opened, then fades.
                    Rectangle {
                        id: flash
                        opacity: 0
                        radius: Theme.radiusCard + 2
                        color: Theme.accentSoft
                        border.width: 1
                        border.color: Theme.accentLine
                        SequentialAnimation {
                            id: flashAnimation
                            NumberAnimation { target: flash; property: "opacity"; to: 1; duration: Theme.fast }
                            PauseAnimation { duration: 900 }
                            NumberAnimation { target: flash; property: "opacity"; to: 0; duration: Theme.reduced ? 0 : Theme.lowPower ? 200 : 500 }
                        }
                    }
                }
            }
        }
    }
}
