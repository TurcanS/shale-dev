pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import "../core"
import "../services"
import "../core/format.js" as Format
import "../core/airdrop.js" as Words
import "../components" as C

// AirDrop: how this computer receives beside the title (Off, Visible for ten minutes, Background), then what to send
// (dropped, browsed, the latest screenshot or a link), the devices nearby to send it to, and what came and went.
// Looking for devices takes the radio, so it starts only once something is chosen, or when asked.
FocusScope {
    id: root
    readonly property string title: "AirDrop"
    readonly property bool showHeader: false
    readonly property int panelWidth: 600
    readonly property int panelHeight: browsing ? 640 : Math.ceil(body.implicitHeight) + Theme.casePadding * 2
    property bool browsing: false
    readonly property bool canGoBack: browsing
    function back() {
        browsing = false;
        forceActiveFocus();
    }
    readonly property bool busy: !!AirDrop.sending && (AirDrop.sending.phase === "asking" || AirDrop.sending.phase === "sending")
    readonly property string clipboard: String(Quickshell.clipboardText || "").trim()
    readonly property bool clipboardLink: /^https?:\/\/\S+$/i.test(clipboard) && clipboard !== AirDrop.stagedUrl
    function paste() {
        const lines = clipboard.split("\n").map(line => line.trim()).filter(line => line);
        if (lines.length && lines.every(line => line.startsWith("/") || line.startsWith("file://")))
            AirDrop.stage(lines);
        else if (!AirDrop.stageUrl(clipboard))
            ShellState.message("The clipboard holds no link or file to send", "error");
    }
    // Something chosen: look for devices to send it to.
    function lookIfReady() {
        if (AirDrop.available && AirDrop.hasStaged && !AirDrop.looking)
            AirDrop.search();
    }
    Connections {
        target: AirDrop
        function onHasStagedChanged() {
            root.lookIfReady();
        }
    }
    // What an earlier search left goes; something already chosen starts a new one.
    Component.onCompleted: {
        AirDrop.clearPeers();
        lookIfReady();
    }
    Component.onDestruction: AirDrop.endSearch()
    Keys.onPressed: event => {
        if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_V) {
            paste();
            event.accepted = true;
        } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_O) {
            browsing = true;
            event.accepted = true;
        } else if (event.key === Qt.Key_Delete && (AirDrop.staged.length || AirDrop.stagedUrl)) {
            AirDrop.unstage(AirDrop.stagedUrl ? -1 : AirDrop.staged.length - 1);
            event.accepted = true;
        }
    }
    function ago(time) {
        const minutes = Math.floor((Date.now() - time) / 60000);
        return minutes < 1 ? "just now" : minutes < 60 ? minutes + " min ago" : Qt.formatTime(new Date(time), ShellState.timeFormat);
    }
    readonly property string countdown: Format.clock(AirDrop.visibleLeft)
    readonly property string statusText: {
        if (!AirDrop.available)
            return "";
        if (AirDrop.recovering)
            return "Giving Wi-Fi back…";
        if (AirDrop.looking && AirDrop.resumeMode && AirDrop.resumeMode !== "off")
            return "Receiving waits while you send, and comes back after.";
        if (AirDrop.mode === "visible")
            return AirDrop.receiverState === "starting" ? "Becoming visible…"
                 : "Visible as “" + AirDrop.deviceName + "” for " + countdown + (AirDrop.wifiPaused ? " · Wi-Fi is paused until then" : "");
        if (AirDrop.mode === "background")
            return AirDrop.receiverState === "waking" ? "An iPhone nearby opened AirDrop · visible now"
                 : "Listening: when an iPhone nearby opens AirDrop, this computer appears in its list. Wi-Fi stays on until then.";
        return "Nobody nearby can see this computer. Choose Visible to receive.";
    }
    ColumnLayout {
        id: body
        anchors.fill: parent
        spacing: 12
        // Title, how it receives, close.
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 12
            AirDropRadar {
                size: 30
                live: AirDrop.looking || AirDrop.mode === "visible" && AirDrop.receiverState === "ready" || AirDrop.receiverState === "waking"
            }
            C.Label {
                text: root.browsing ? "Choose files" : root.title
                font.pixelSize: 17
                font.weight: 650
                elide: Text.ElideNone
            }
            Item {
                Layout.fillWidth: true
            }
            C.Segmented {
                visible: AirDrop.available && !root.browsing
                Layout.fillWidth: false
                Layout.preferredWidth: Math.max(320, implicitWidth)
                segmentHeight: 32
                model: [{key: "off", text: "Off", accessibleName: "Receive nothing"},
                        {key: "visible", text: AirDrop.mode === "visible" ? "Visible " + root.countdown : "Visible", accessibleName: "Visible for 10 minutes"},
                        {key: "background", text: "Background", accessibleName: "Receive in the background"}]
                current: AirDrop.looking && AirDrop.resumeMode ? AirDrop.resumeMode : AirDrop.mode
                onActivated: key => AirDrop.setMode(key)
            }
            C.Button {
                glyph: "close"
                implicitWidth: 32
                implicitHeight: 32
                flat: true
                hint: "Close · Escape"
                onClicked: ShellState.close()
            }
        }
        // Without the command there is nothing to drive: say what to install.
        C.EmptyState {
            visible: !AirDrop.available
            Layout.fillWidth: true
            Layout.topMargin: 40
            Layout.bottomMargin: 40
            glyph: "airdrop"
            title: AirDrop.command ? "This airdrop is too old for Shale" : "AirDrop needs the airdrop command"
            description: AirDrop.command ? "Shale talks to it with --json, which came later. Update it from its source folder (cargo build --release) and install it again."
                                         : "Install AirDrop for Linux (the airdrop command and its helper), then open this again. Shale finds it on your PATH or in ~/.local/bin."
        }
        AirDropBrowse {
            visible: root.browsing
            focus: root.browsing
            Layout.fillWidth: true
            Layout.fillHeight: true
            onPicked: paths => {
                AirDrop.stage(paths);
                root.back();
            }
            onCancelled: root.back()
        }
        // How it receives, in words, with the extra ten minutes beside it.
        RowLayout {
            visible: AirDrop.available && !root.browsing && !AirDrop.error
            Layout.fillWidth: true
            Layout.leftMargin: 2
            spacing: 8
            C.Label {
                text: root.statusText
                color: Theme.textDim
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                Layout.fillWidth: true
            }
            C.Chip {
                visible: AirDrop.mode === "visible" && AirDrop.receiverState === "ready"
                text: "+10 min"
                onClicked: AirDrop.extend()
            }
        }
        // What went wrong, and the one thing to do about it.
        Rectangle {
            id: problem
            visible: AirDrop.available && !root.browsing && !!AirDrop.error
            Layout.fillWidth: true
            implicitHeight: problemRow.implicitHeight + 24
            radius: Theme.radiusCard
            color: Theme.dangerWash
            border.width: 1
            border.color: Theme.dangerLine
            RowLayout {
                id: problemRow
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12
                C.Icon {
                    name: "alert"
                    size: 20
                    color: Theme.dangerText
                    Layout.alignment: Qt.AlignTop
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    C.Label {
                        text: AirDrop.error ? AirDrop.error.message : ""
                        color: Theme.dangerText
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                        Layout.fillWidth: true
                    }
                    C.Label {
                        visible: text !== ""
                        text: AirDrop.error ? AirDrop.error.hint : ""
                        color: Theme.textSecondary
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                        Layout.fillWidth: true
                    }
                    // The one thing most likely to help first: Try again, or Wi-Fi back when that is what is wrong.
                    Flow {
                        spacing: 8
                        Layout.topMargin: 4
                        Layout.fillWidth: true
                        C.Button {
                            visible: AirDrop.canRetry
                            text: "Try again"
                            glyph: "refresh"
                            accent: true
                            implicitHeight: 28
                            onClicked: AirDrop.retry()
                        }
                        C.Button {
                            visible: !!AirDrop.error && ["link", "exit", "wifi"].indexOf(AirDrop.error.code) >= 0
                            text: AirDrop.recovering ? "Giving Wi-Fi back…" : "Give Wi-Fi back"
                            glyph: "wifi"
                            accent: !!AirDrop.error && AirDrop.error.code === "wifi"
                            enabled: !AirDrop.recovering && !AirDrop.looking
                            implicitHeight: 28
                            onClicked: AirDrop.recover()
                        }
                        C.Button {
                            visible: !!AirDrop.error && AirDrop.error.code !== "wifi"
                            text: "Check this computer"
                            flat: AirDrop.canRetry
                            implicitHeight: 28
                            onClicked: ShellState.openSettings("AirDrop")
                        }
                    }
                }
                C.Button {
                    glyph: "close"
                    flat: true
                    hint: "Dismiss"
                    implicitWidth: 28
                    implicitHeight: 28
                    Layout.alignment: Qt.AlignTop
                    onClicked: AirDrop.error = null
                }
            }
        }
        // What to send: a drop zone until something is chosen, then the chosen things as chips.
        Rectangle {
            id: share
            visible: AirDrop.available && !root.browsing
            Layout.fillWidth: true
            implicitHeight: shareColumn.implicitHeight + 28
            radius: Theme.radiusModule
            color: drop.containsDrag ? Theme.accentSoft : Theme.module
            border.width: 1
            border.color: drop.containsDrag ? Theme.accentLine : "transparent"
            scale: drop.containsDrag && !Theme.reduced ? 1.015 : 1
            Behavior on color {
                ColorAnimation {
                    duration: Theme.fast
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.fast
                    easing.type: Easing.OutCubic
                }
            }
            DropArea {
                id: drop
                anchors.fill: parent
                keys: ["text/uri-list"]
                // Files, or a link dragged from a browser.
                onDropped: event => {
                    const urls = (event.urls || []).map(url => String(url));
                    const paths = urls.filter(url => url.startsWith("file://"));
                    const links = urls.filter(url => /^https?:\/\//i.test(url));
                    if (paths.length)
                        AirDrop.stage(paths);
                    else if (!links.length || !AirDrop.stageUrl(links[0]))
                        return;
                    event.acceptProposedAction();
                }
            }
            ColumnLayout {
                id: shareColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 12
                // Nothing chosen yet.
                ColumnLayout {
                    visible: !AirDrop.hasStaged
                    Layout.fillWidth: true
                    spacing: 6
                    C.Icon {
                        name: "send"
                        size: 28
                        color: drop.containsDrag ? Theme.accentText : Theme.textDim
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 6
                        transform: Translate {
                            y: drop.containsDrag && !Theme.reduced ? -4 : 0
                            Behavior on y {
                                NumberAnimation {
                                    duration: Theme.enter
                                    easing.type: Easing.OutBack
                                }
                            }
                        }
                    }
                    C.Label {
                        text: drop.containsDrag ? "Drop to share" : "Drop files or a link here to share them"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: drop.containsDrag ? Theme.accentText : Theme.text
                        Layout.alignment: Qt.AlignHCenter
                    }
                    C.Label {
                        text: "Or choose them here; Ctrl+V pastes a link"
                        color: Theme.textDim
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 6
                        spacing: 8
                        C.Button {
                            text: "Browse"
                            glyph: "folder"
                            implicitHeight: 32
                            onClicked: root.browsing = true
                        }
                        C.Button {
                            visible: root.latestShot !== ""
                            text: "Latest screenshot"
                            glyph: "image"
                            implicitHeight: 32
                            onClicked: AirDrop.stage([root.latestShot])
                        }
                        C.Button {
                            visible: root.clipboardLink
                            text: "Link from clipboard"
                            glyph: "link"
                            implicitHeight: 32
                            onClicked: AirDrop.stageUrl(root.clipboard)
                        }
                    }
                }
                // What is chosen.
                Flow {
                    visible: AirDrop.hasStaged
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: AirDrop.stagedUrl ? [{name: AirDrop.stagedUrl, kind: "link", size: -1}] : AirDrop.staged
                        Rectangle {
                            id: chip
                            required property var modelData
                            required property int index
                            implicitHeight: 32
                            implicitWidth: Math.min(shareColumn.width, chipRow.implicitWidth + 14)
                            radius: 16
                            color: Theme.key
                            opacity: 0
                            scale: 0.9
                            Component.onCompleted: {
                                opacity = 1;
                                scale = 1;
                            }
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.enter
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.enter
                                    easing.type: Easing.OutBack
                                }
                            }
                            RowLayout {
                                id: chipRow
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 4
                                spacing: 6
                                C.Icon {
                                    name: ({folder: "folder", image: "image", video: "film", audio: "music", text: "text", link: "link"})[chip.modelData.kind] || "file"
                                    size: 15
                                    color: Theme.textSecondary
                                }
                                C.Label {
                                    text: chip.modelData.name
                                    font.pixelSize: 13
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 260
                                }
                                C.Label {
                                    visible: chip.modelData.size >= 0
                                    text: Format.bytes(chip.modelData.size)
                                    color: Theme.textDim
                                    font.pixelSize: 12
                                    font.features: ({"tnum": 1})
                                }
                                C.Button {
                                    glyph: "close"
                                    flat: true
                                    hint: "Remove"
                                    implicitWidth: 24
                                    implicitHeight: 24
                                    padding: 4
                                    cornerRadius: 12
                                    enabled: !root.busy
                                    onClicked: AirDrop.unstage(AirDrop.stagedUrl ? -1 : chip.index)
                                }
                            }
                        }
                    }
                }
                RowLayout {
                    visible: AirDrop.hasStaged
                    Layout.fillWidth: true
                    spacing: 8
                    C.Label {
                        text: AirDrop.stagedUrl ? "A link" : (AirDrop.staged.length === 1 ? "1 item" : AirDrop.staged.length + " items") + " · " + Format.bytes(AirDrop.stagedBytes)
                        color: Theme.textDim
                        font.pixelSize: 12
                        font.features: ({"tnum": 1})
                        Layout.fillWidth: true
                    }
                    C.Button {
                        visible: !AirDrop.stagedUrl
                        text: "Add"
                        glyph: "plus"
                        flat: true
                        implicitHeight: 28
                        enabled: !root.busy
                        onClicked: root.browsing = true
                    }
                    C.Button {
                        text: "Clear"
                        flat: true
                        implicitHeight: 28
                        enabled: !root.busy
                        onClicked: AirDrop.clearStaged()
                    }
                }
            }
        }
        // The devices nearby.
        Rectangle {
            visible: AirDrop.available && !root.browsing
            Layout.fillWidth: true
            implicitHeight: nearbyColumn.implicitHeight + 28
            radius: Theme.radiusModule
            color: Theme.module
            ColumnLayout {
                id: nearbyColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    C.Label {
                        text: "Nearby"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                    C.Label {
                        readonly property var s: AirDrop.sending
                        text: {
                            if (s && s.phase === "asking")
                                return "Waiting for " + s.name + " to accept";
                            if (s && s.phase === "sending")
                                return [Format.bytes(s.done) + " of " + Format.bytes(s.total), s.rate > 0 ? Format.bytes(s.rate) + "/s" : "",
                                        Words.left(s.done, s.total, s.rate)].filter(part => part).join(" · ");
                            return AirDrop.sendState === "starting" ? "Starting…"
                                 : AirDrop.sendState === "searching" ? (AirDrop.senderWifi ? "Looking · Wi-Fi paused meanwhile" : "Looking…") : "";
                        }
                        color: s && s.phase === "sending" ? Theme.accentText : Theme.textDim
                        font.pixelSize: 12
                        font.features: ({"tnum": 1})
                        Layout.fillWidth: true
                    }
                    C.Button {
                        visible: !AirDrop.looking
                        text: AirDrop.sendState === "ended" ? "Look again" : "Look for devices"
                        glyph: "search"
                        accent: AirDrop.hasStaged
                        enabled: !AirDrop.recovering
                        implicitHeight: 28
                        onClicked: AirDrop.search()
                    }
                    C.Button {
                        visible: AirDrop.looking && !root.busy
                        text: "Stop"
                        flat: true
                        implicitHeight: 28
                        onClicked: AirDrop.endSearch()
                    }
                }
                // No one yet: what to do on the other device.
                ColumnLayout {
                    visible: AirDrop.peers.count === 0
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    Layout.bottomMargin: 6
                    spacing: 10
                    AirDropRadar {
                        visible: AirDrop.looking
                        live: true
                        size: 44
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 16
                        Layout.bottomMargin: 16
                    }
                    C.Label {
                        text: AirDrop.looking ? "Looking for iPhones, iPads and Macs"
                            : AirDrop.sendState === "ended" ? (AirDrop.lastFound > 0 ? "Stopped looking" : "No one answered")
                            : AirDrop.hasStaged ? "Ready to look" : "Choose something to send"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        Layout.alignment: Qt.AlignHCenter
                    }
                    C.Label {
                        text: AirDrop.sendState === "ended" && AirDrop.lastFound > 0 ? "Nothing was picked for a minute and a half, so Wi-Fi got the radio back. Look again to send."
                            : AirDrop.sendState === "ended" && AirDrop.searchHint ? AirDrop.searchHint
                            : "On the other device: Control Center → AirDrop → Everyone for 10 Minutes, with its screen on and unlocked."
                        color: Theme.textDim
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                }
                Flow {
                    id: peerFlow
                    visible: AirDrop.peers.count > 0
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: AirDrop.peers
                        AirDropPeer {
                            required property int index
                            order: index
                            ready: AirDrop.hasStaged && !root.busy && AirDrop.looking
                            onClicked: moving ? AirDrop.cancel(peerId) : AirDrop.sendTo(peerId)
                        }
                    }
                }
                C.Label {
                    visible: AirDrop.peers.count > 0 && !AirDrop.hasStaged
                    text: "Choose something to send, then pick a device."
                    color: Theme.textDim
                    font.pixelSize: 12
                }
            }
        }
        // What came and went this session, else the newest files in the AirDrop folder.
        Rectangle {
            visible: AirDrop.available && !root.browsing && (AirDrop.recent.length > 0 || root.folderRows.length > 0)
            Layout.fillWidth: true
            implicitHeight: recentColumn.implicitHeight + 20
            radius: Theme.radiusModule
            color: Theme.module
            ColumnLayout {
                id: recentColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.bottomMargin: 4
                    C.Label {
                        text: "Recent"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                    }
                    C.Button {
                        text: "Open folder"
                        glyph: "folder"
                        flat: true
                        implicitHeight: 28
                        onClicked: ShellState.openPath(AirDrop.folderPath)
                    }
                }
                Repeater {
                    model: AirDrop.recent.length ? AirDrop.recent.slice(0, 4) : root.folderRows
                    RowLayout {
                        id: entry
                        required property var modelData
                        readonly property string target: modelData.url || (modelData.paths && modelData.paths.length ? modelData.paths[0] : "")
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        spacing: 10
                        C.GlyphTile {
                            glyph: entry.modelData.dir === "out" ? "send" : "download"
                            size: 30
                            color: Theme.keyTile
                            glyphColor: entry.modelData.phase === "done" ? Theme.text : Theme.dangerText
                            Layout.leftMargin: 4
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            C.Label {
                                text: entry.modelData.title
                                font.pixelSize: 13
                                Layout.fillWidth: true
                            }
                            C.Label {
                                readonly property var m: entry.modelData
                                text: [m.who ? (m.dir === "out" ? "to " : "from ") + m.who : "",
                                       m.phase === "done" ? (m.bytes ? Format.bytes(m.bytes) : "")
                                       : ({declined: "declined", failed: m.dir === "in" ? "didn't arrive" : "didn't send", cancelled: "cancelled"})[m.phase] || "",
                                       m.time ? root.ago(m.time) : ""].filter(part => part).join(" · ")
                                color: m.phase === "done" ? Theme.textDim : Theme.dangerText
                                font.pixelSize: 12
                                Layout.fillWidth: true
                            }
                        }
                        C.Button {
                            visible: entry.modelData.phase === "done" && entry.target !== ""
                            text: entry.modelData.url ? "Open link" : "Open"
                            implicitHeight: 28
                            onClicked: entry.modelData.url ? AirDrop.openLink(entry.modelData.url) : ShellState.openPath(entry.target)
                        }
                        C.Button {
                            visible: entry.modelData.phase === "done" && !entry.modelData.url && entry.target !== ""
                            glyph: "folder"
                            hint: "Show in folder"
                            flat: true
                            implicitWidth: 28
                            implicitHeight: 28
                            Layout.rightMargin: 4
                            onClicked: ShellState.openPath(entry.target.slice(0, entry.target.lastIndexOf("/")))
                        }
                    }
                }
            }
        }
    }
    // The newest files received before this session, for Recent. A folder that doesn't exist yet leaves a folder model
    // on the working directory, so only paths inside the folder count.
    readonly property var folderRows: {
        const rows = [];
        for (let i = 0; i < Math.min(3, received.count); i++)
            if (String(received.get(i, "filePath")).startsWith(AirDrop.folderPath.replace(/\/+$/, "") + "/"))
                rows.push({dir: "in", title: received.get(i, "fileName"), paths: [received.get(i, "filePath")], phase: "done",
                       bytes: received.get(i, "fileIsDir") ? 0 : received.get(i, "fileSize"), time: received.get(i, "fileModified").getTime(), who: ""});
        return rows;
    }
    FolderListModel {
        id: received
        folder: "file://" + AirDrop.folderPath.split("/").map(encodeURIComponent).join("/")
        showDirs: true
        sortField: FolderListModel.Time
    }
    readonly property string screenshots: String(ShellState.setting("screenshotDirectory", "~/Pictures/Screenshots")).replace(/^~(?=\/)/, AirDrop.home).replace(/\/+$/, "")
    readonly property string latestShot: latest.count > 0 && String(latest.get(0, "filePath")).startsWith(screenshots + "/") ? latest.get(0, "filePath") : ""
    FolderListModel {
        id: latest
        folder: "file://" + root.screenshots.split("/").map(encodeURIComponent).join("/")
        nameFilters: ["*.png", "*.jpg", "*.jpeg"]
        showDirs: false
        sortField: FolderListModel.Time
    }
}
