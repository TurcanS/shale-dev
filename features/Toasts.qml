import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../core"
import "../services"
import "../components" as C

Scope {
    id: root
    required property var screen
    readonly property bool target: ShellState.targetScreen() === screen.name
    // Microphone mute and keyboard layout changes show as OSD cards. Every screen has a copy of this scope; only the
    // target screen's reports, and a microphone that just appeared settles first so start-up stays quiet.
    property bool micSettled: false
    Timer {
        id: micSettle
        interval: 2000
        running: true
        onTriggered: root.micSettled = true
    }
    Connections {
        target: Services
        function onInputChanged() {
            root.micSettled = false;
            micSettle.restart();
        }
        function onMicMutedChanged() {
            if (root.micSettled && root.target)
                ShellState.osd((Services.micMuted ? "Muted" : "On") + " · Microphone", -1, Services.micMuted ? "mic-off" : "mic", Services.micMuted);
        }
    }
    readonly property var languages: ({us: "English", gb: "English", au: "English", ca: "Canadian", ie: "Irish", de: "German", at: "German", ch: "Swiss",
        fr: "French", be: "Belgian", es: "Spanish", latam: "Spanish", pt: "Portuguese", br: "Portuguese", it: "Italian", nl: "Dutch",
        se: "Swedish", no: "Norwegian", dk: "Danish", fi: "Finnish", is: "Icelandic", pl: "Polish", cz: "Czech", sk: "Slovak",
        hu: "Hungarian", ro: "Romanian", bg: "Bulgarian", hr: "Croatian", si: "Slovenian", rs: "Serbian", gr: "Greek", tr: "Turkish",
        ru: "Russian", ua: "Ukrainian", by: "Belarusian", lt: "Lithuanian", lv: "Latvian", ee: "Estonian", il: "Hebrew", ara: "Arabic",
        ir: "Persian", in: "Indian", jp: "Japanese", kr: "Korean", cn: "Chinese", th: "Thai", vn: "Vietnamese"})
    // The last layout seen: keyboard, its layouts and the active one. Only a switch among the same layouts shows.
    property string layoutSeen: ""
    Connections {
        target: ShellState
        function onKeyboardChanged() {
            const keyboard = ShellState.keyboard || {};
            const layouts = keyboard.layouts || [];
            const set = (keyboard.name || "") + "|" + JSON.stringify(layouts);
            const previous = root.layoutSeen;
            root.layoutSeen = set + "|" + keyboard.index;
            const current = layouts[keyboard.index];
            if (!root.target || !current || layouts.length < 2 || previous === root.layoutSeen || previous.slice(0, previous.lastIndexOf("|")) !== set)
                return;
            const code = String(current.code || "");
            ShellState.osd((root.languages[code] || code.toUpperCase()) + " · Keyboard · " + [code.toUpperCase(), current.variant || ""].filter(part => part).join(" "), -1, "keyboard");
        }
    }
    // Notification toasts: the Notifications card, stacked up from the bottom right corner, newest lowest.
    PanelWindow {
        id: popups
        // Transparent room around the cards for their shadow; the mask keeps it from taking clicks.
        readonly property int room: 32
        screen: root.screen
        anchors {
            bottom: true
            right: true
        }
        implicitWidth: Math.min(360, screen.width - 48) + room + 24
        implicitHeight: Math.max(1, Math.min(screen.height - ShellState.barBottom - 96, popupList.contentHeight)) + room + 24
        property int retiring: 0
        readonly property bool wanted: root.target && !ShellState.locked && (Services.popupModel.count > 0 || retiring > 0) && ShellState.panel !== "notifications"
        // Applied after the change settles: mapping the window as the session unlocks updates the focused
        // output (and so `target`) while `visible` is still being set, which Qt reports as a binding loop.
        visible: false
        onWantedChanged: Qt.callLater(() => popups.visible = popups.wanted)
        Component.onCompleted: visible = wanted
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "shale-notifications"
        WlrLayershell.layer: WlrLayer.Overlay
        mask: Region {
            item: popupList
        }
        ListView {
            id: popupList
            x: popups.room
            y: popups.room
            width: parent.width - popups.room - 24
            height: parent.height - popups.room - 24
            spacing: 10
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            model: Services.popupModel
            delegate: Item {
                id: popupItem
                required property var notificationData
                width: popupList.width
                height: popupCard.implicitHeight
                ListView.onRemove: {
                    popups.retiring++;
                    removal.start();
                }
                SequentialAnimation {
                    id: removal
                    PropertyAction { target: popupItem; property: "ListView.delayRemove"; value: true }
                    NumberAnimation { target: popupItem; property: "opacity"; to: 0; duration: Theme.leave }
                    ScriptAction { script: popups.retiring-- }
                    PropertyAction { target: popupItem; property: "ListView.delayRemove"; value: false }
                }
                RectangularShadow {
                    anchors.fill: popupCard
                    visible: !Theme.lowPower
                    radius: popupCard.radius
                    blur: 32
                    offset.y: 14
                    color: Qt.rgba(0, 0, 0, 0.45)
                }
                NotificationCard {
                    id: popupCard
                    notification: popupItem.notificationData
                    popup: true
                    width: parent.width
                    height: implicitHeight
                }
            }
            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.panelEnter }
                    NumberAnimation {
                        property: "x"
                        from: Theme.reduced ? 0 : 24
                        to: 0
                        duration: Theme.reduced ? 0 : Theme.lowPower ? 120 : 200
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.easeOut
                    }
                }
            }
            displaced: Transition {
                NumberAnimation { property: "y"; duration: Theme.reduced ? 0 : Theme.enter; easing.type: Easing.OutCubic }
            }
        }
    }
    // Levels (volume, brightness) as a round pill with a slim bar and the value; everything else (microphone,
    // keyboard layout, Do not disturb, countdowns) as a small card with a title and what it is about.
    PanelWindow {
        id: osdWindow
        readonly property bool level: ShellState.osdValue >= 0
        readonly property bool volume: ShellState.osdGlyph === "volume" || ShellState.osdGlyph === "mute"
        // "Muted · Microphone" → Muted over Microphone; the older one-line labels get the same shape.
        readonly property var card: {
            const label = ShellState.osdLabel;
            const dnd = /^Do not disturb (on|off)$/.exec(label);
            if (dnd)
                return {title: dnd[1] === "on" ? "On" : "Off", subtitle: "Do not disturb"};
            const countdown = /^Screenshot in (\d+)$/.exec(label);
            if (countdown)
                return {title: "In " + countdown[1], subtitle: "Screenshot"};
            const parts = label.split(" · ");
            return {title: parts[0], subtitle: parts.slice(1).join(" · ")};
        }
        // Something switched on (Do not disturb): a light tile with dark ink.
        readonly property bool lit: ShellState.osdGlyph === "bell-off"
        // Transparent room for the shadow; nothing here takes clicks.
        readonly property int room: 40
        property real reveal: root.target && ShellState.osdVisible && !ShellState.locked ? 1 : 0
        Behavior on reveal { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
        screen: root.screen
        anchors {
            bottom: true
        }
        margins.bottom: (ShellState.toast !== "" ? 92 : 64) - room
        implicitWidth: (level ? 320 : 196) + 2 * room
        implicitHeight: (level ? 56 : 124) + 2 * room
        visible: root.target && !ShellState.locked && reveal > 0
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "shale-osd"
        WlrLayershell.layer: WlrLayer.Overlay
        // Nothing here is clickable, so clicks reach the windows underneath.
        mask: Region {}
        Item {
            id: osd
            anchors.fill: parent
            anchors.margins: osdWindow.room
            opacity: osdWindow.reveal
            transform: [
                Scale {
                    origin.x: osd.width / 2
                    origin.y: osd.height / 2
                    xScale: Theme.reduced ? 1 : 0.94 + 0.06 * osdWindow.reveal
                    yScale: xScale
                },
                Translate { y: Theme.reduced ? 0 : (1 - osdWindow.reveal) * 6 }
            ]
            RectangularShadow {
                anchors.fill: osdCase
                visible: !Theme.lowPower
                radius: osdCase.radius
                blur: 30
                offset.y: 14
                color: Qt.rgba(0, 0, 0, 0.45)
            }
            Rectangle {
                id: osdCase
                anchors.fill: parent
                radius: osdWindow.level ? height / 2 : 24
                color: Theme.tint(Theme.module, 0.92)
                border.width: 1
                border.color: Theme.cardEdge
            }
            // The level pill: icon disc, slim bar, value.
            RowLayout {
                visible: osdWindow.level
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 16
                spacing: Theme.gapM
                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 18
                    color: ShellState.osdMuted ? Theme.dangerSoft : osdWindow.volume ? Theme.tint(Theme.accent, 0.16) : Theme.key
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                    C.Icon {
                        id: osdIcon
                        anchors.centerIn: parent
                        name: ShellState.osdGlyph
                        color: ShellState.osdMuted ? Theme.dangerText : osdWindow.volume ? Theme.accent : Theme.text
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Theme.key
                    RectangularShadow {
                        anchors.fill: levelFill
                        visible: osdWindow.volume && !ShellState.osdMuted && !Theme.lowPower && levelFill.width > 0
                        radius: levelFill.radius
                        blur: 12
                        color: Theme.accentGlow
                    }
                    Rectangle {
                        id: levelFill
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * Math.max(0, Math.min(1, ShellState.osdValue))
                        radius: 3
                        // Volume runs from the accent wash to the accent; brightness is light; muted keeps the real
                        // level visible, just quieter.
                        color: ShellState.osdMuted ? Theme.textFaint : Theme.text
                        gradient: osdWindow.volume && !ShellState.osdMuted ? volumeGradient : undefined
                        Behavior on width { NumberAnimation { duration: Theme.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
                        Gradient {
                            id: volumeGradient
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.tint(Theme.accent, 0.16) }
                            GradientStop { position: 1; color: Theme.accent }
                        }
                    }
                }
                C.Label {
                    text: Math.round(ShellState.osdValue * 100)
                    color: ShellState.osdMuted ? Theme.textDim : Theme.text
                    font.pixelSize: 14
                    font.weight: 650
                    font.features: ({"tnum": 1})
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 30
                }
            }
            // The card: tile, then the title and what it is about at the bottom.
            ColumnLayout {
                visible: !osdWindow.level
                anchors.fill: parent
                anchors.margins: 16
                spacing: 6
                Rectangle {
                    id: cardTile
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: 13
                    color: ShellState.osdMuted ? Theme.dangerSoft : osdWindow.lit ? Theme.mix(Theme.knob, Theme.textSecondary, 0.35) : Theme.key
                    C.Icon {
                        id: cardIcon
                        anchors.centerIn: parent
                        name: ShellState.osdGlyph
                        color: ShellState.osdMuted ? Theme.dangerText : osdWindow.lit ? Theme.accentInk : Theme.text
                    }
                }
                Item {
                    Layout.fillHeight: true
                }
                C.Label {
                    text: osdWindow.card.title
                    font.pixelSize: 16
                    font.weight: 650
                    Layout.fillWidth: true
                }
                C.Label {
                    visible: text !== ""
                    text: osdWindow.card.subtitle
                    color: Theme.textDim
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
            // A small bump on every change confirms the key press even at 0% or 100%.
            SequentialAnimation {
                id: bump
                property Item icon: osdWindow.level ? osdIcon : cardIcon
                NumberAnimation { target: bump.icon; property: "scale"; to: 1.2; duration: 70; easing.type: Easing.OutQuad }
                NumberAnimation { target: bump.icon; property: "scale"; to: 1; duration: 160; easing.type: Easing.OutBack }
            }
            Connections {
                target: ShellState
                function onOsdSerialChanged() {
                    if (!Theme.reduced && !Theme.lowPower && osdWindow.reveal > 0)
                        bump.restart();
                }
            }
        }
    }
    // Brief "now playing" card when the track changes in the background.
    PanelWindow {
        id: trackWindow
        property string title: ""
        property string artist: ""
        property bool shown: false
        readonly property var workspace: Services.workspaces.find(w => w.monitor && w.monitor.name === root.screen.name && w.active)
        readonly property bool allowed: root.target && !ShellState.locked && ShellState.setting("trackChangeCard", true) && !Focus.digest
            && !(workspace && workspace.hasFullscreen) && !(ShellState.panel === "control" && ShellState.detail === "media")
        property real reveal: shown && allowed ? 1 : 0
        Behavior on reveal { NumberAnimation { duration: trackWindow.shown ? Theme.enter : Theme.leave; easing.type: Easing.OutCubic } }
        Connections {
            target: NowPlaying
            function onTrackChanged() {
                const player = NowPlaying.player;
                if (!trackWindow.allowed || !player)
                    return;
                trackWindow.title = player.trackTitle || "";
                trackWindow.artist = player.trackArtist || player.identity || "";
                trackWindow.shown = true;
                if (!trackHover.hovered)
                    trackTimer.restart();
            }
        }
        Timer {
            id: trackTimer
            interval: 3500
            onTriggered: trackWindow.shown = false
        }
        screen: root.screen
        anchors {
            top: true
        }
        margins.top: ShellState.barBottomOn(root.screen ? root.screen.name : "") + 9
        implicitWidth: 340
        implicitHeight: 64
        visible: reveal > 0
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "shale-track"
        WlrLayershell.layer: WlrLayer.Overlay
        Rectangle {
            anchors.fill: parent
            radius: 18
            color: Theme.module
            border.width: 1
            border.color: Theme.cardEdge
            opacity: trackWindow.reveal
            transform: Translate { y: Theme.reduced ? 0 : (1 - trackWindow.reveal) * -8 }
            HoverHandler {
                id: trackHover
                // Reading the card keeps it open; leaving gives a moment before it goes.
                onHoveredChanged: if (hovered)
                    trackTimer.stop();
                else if (trackWindow.shown)
                    trackTimer.restart()
            }
            TapHandler {
                onTapped: {
                    trackWindow.shown = false;
                    ShellState.open("control", root.screen.name);
                    ShellState.detail = "media";
                }
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: Theme.gapM
                C.CoverArt {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: Theme.radiusKey
                    source: NowPlaying.artFile
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    C.Label {
                        text: trackWindow.title
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    C.Label {
                        text: trackWindow.artist
                        color: Theme.textMuted
                        font.pixelSize: Theme.small
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
                C.Button {
                    glyph: "next"
                    flat: true
                    implicitWidth: 36
                    implicitHeight: Theme.controlHeight
                    cornerRadius: 18
                    hint: "Next track"
                    visible: !!NowPlaying.player && NowPlaying.player.canGoNext
                    onClicked: NowPlaying.player.next()
                }
            }
        }
    }
    // What came in during a focus session, grouped by app. Stays until dismissed.
    PanelWindow {
        id: digestWindow
        readonly property var digest: Focus.digest
        property var retained: null
        onDigestChanged: if (digest)
            retained = digest
        readonly property var groups: retained ? retained.groups : []
        property real reveal: root.target && !!digest && !ShellState.locked ? 1 : 0
        Behavior on reveal { NumberAnimation { duration: digestWindow.digest ? Theme.enter : Theme.leave; easing.type: Easing.OutCubic } }
        screen: root.screen
        anchors {
            top: true
        }
        margins.top: ShellState.barBottomOn(root.screen ? root.screen.name : "") + 9
        implicitWidth: Math.min(380, screen.width - 24)
        implicitHeight: digestColumn.implicitHeight + 2 * Theme.gapM
        visible: reveal > 0
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "shale-digest"
        WlrLayershell.layer: WlrLayer.Overlay
        Rectangle {
            anchors.fill: parent
            radius: 18
            color: Theme.module
            border.width: 1
            border.color: Theme.cardEdge
            opacity: digestWindow.reveal
            transform: Translate { y: Theme.reduced ? 0 : (1 - digestWindow.reveal) * -8 }
            ColumnLayout {
                id: digestColumn
                anchors.fill: parent
                anchors.margins: Theme.gapM
                spacing: Theme.gapS
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gapM
                    C.GlyphTile { glyph: "focus" }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        C.Label {
                            text: digestWindow.retained ? "While you focused · " + digestWindow.retained.minutes + " min" : ""
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        C.Caption {
                            readonly property int total: digestWindow.retained ? digestWindow.retained.total : 0
                            text: total + (total === 1 ? " notification" : " notifications") + " from " + digestWindow.groups.length + (digestWindow.groups.length === 1 ? " app" : " apps")
                            Layout.fillWidth: true
                        }
                    }
                    C.Button {
                        glyph: "close"
                        flat: true
                        hint: "Dismiss"
                        onClicked: Focus.digest = null
                    }
                }
                Repeater {
                    model: digestWindow.groups.slice(0, 4)
                    RowLayout {
                        id: digestRow
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.leftMargin: 2
                        spacing: Theme.gapM
                        Item {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            Image {
                                id: digestIcon
                                anchors.centerIn: parent
                                visible: status === Image.Ready
                                source: digestRow.modelData.appIcon ? Quickshell.iconPath(digestRow.modelData.appIcon, "dialog-information") : ""
                                sourceSize.width: 24
                                sourceSize.height: 24
                                width: 24
                                height: 24
                            }
                            C.Icon {
                                anchors.centerIn: parent
                                visible: !digestIcon.visible
                                name: "bell"
                                size: 16
                                color: Theme.textMuted
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            C.Label {
                                text: digestRow.modelData.appName
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            C.Caption {
                                text: digestRow.modelData.latest
                                visible: text !== ""
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                Layout.fillWidth: true
                            }
                        }
                        C.Label {
                            text: String(digestRow.modelData.count)
                            font.family: Theme.mono
                            font.pixelSize: Theme.small
                            color: Theme.textMuted
                        }
                    }
                }
                C.Caption {
                    visible: digestWindow.groups.length > 4
                    text: "and " + (digestWindow.groups.length - 4) + " more"
                    Layout.leftMargin: 42
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.gapXs
                    spacing: Theme.gapS
                    Item { Layout.fillWidth: true }
                    C.Button {
                        text: "Dismiss"
                        flat: true
                        onClicked: Focus.digest = null
                    }
                    C.Button {
                        text: "Open notifications"
                        onClicked: {
                            Focus.digest = null;
                            ShellState.open("notifications", root.screen.name);
                        }
                    }
                }
            }
        }
    }
    PanelWindow {
        id: messageWindow
        property string retainedText: ""
        property string retainedKind: "info"
        property var retainedAction: null
        property real reveal: root.target && ShellState.toast !== "" && !ShellState.locked ? 1 : 0
        Connections {
            target: ShellState
            function onToastChanged() {
                if (ShellState.toast === "")
                    return;
                messageWindow.retainedText = ShellState.toast;
                messageWindow.retainedKind = ShellState.toastKind;
                messageWindow.retainedAction = ShellState.toastAction;
            }
        }
        Behavior on reveal { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
        screen: root.screen
        anchors {
            bottom: true
        }
        margins.bottom: 18
        TextMetrics {
            id: messageMetrics
            font.family: Theme.font
            font.pixelSize: Theme.body
            text: messageWindow.retainedText
        }
        implicitWidth: Math.min(560, screen.width - 40, Math.max(240, messageMetrics.advanceWidth + 100 + (retainedAction ? actionMetrics.advanceWidth + 36 : 0)))
        TextMetrics {
            id: actionMetrics
            font.family: Theme.font
            font.pixelSize: Theme.body
            text: messageWindow.retainedAction ? messageWindow.retainedAction.label : ""
        }
        implicitHeight: Math.max(60, messageLabel.implicitHeight + 24)
        visible: root.target && !ShellState.locked && reveal > 0
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "shale-message"
        WlrLayershell.layer: WlrLayer.Overlay
        // The same surface as the notification toasts: a tile says what kind of message it is.
        Rectangle {
            anchors.fill: parent
            color: Theme.module
            opacity: messageWindow.reveal
            transform: Translate { y: Theme.reduced ? 0 : (1 - messageWindow.reveal) * 6 }
            radius: 14
            border.width: 1
            border.color: messageWindow.retainedKind === "error" ? Theme.dangerLine : Theme.cardEdge
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: Theme.gapM
                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 9
                    color: messageWindow.retainedKind === "error" ? Theme.dangerSoft : messageWindow.retainedKind === "success" ? Theme.accentSoft : Theme.key
                    C.Icon {
                        anchors.centerIn: parent
                        name: messageWindow.retainedKind === "error" ? "alert" : messageWindow.retainedKind === "success" ? "check" : "info"
                        color: messageWindow.retainedKind === "error" ? Theme.dangerText : messageWindow.retainedKind === "success" ? Theme.accentText : Theme.textSecondary
                    }
                }
                C.Label {
                    id: messageLabel
                    text: messageWindow.retainedText
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    color: messageWindow.retainedKind === "error" ? Theme.dangerText : Theme.text
                }
                C.Button {
                    visible: !!messageWindow.retainedAction
                    text: messageWindow.retainedAction ? messageWindow.retainedAction.label : ""
                    implicitHeight: 30
                    cornerRadius: 8
                    labelSize: 12
                    onClicked: {
                        const action = messageWindow.retainedAction;
                        ShellState.toast = "";
                        if (action)
                            action.run();
                    }
                }
                C.Button {
                    glyph: "close"
                    flat: true
                    implicitWidth: 28
                    implicitHeight: 28
                    foreground: hovered || visualFocus ? Theme.text : Theme.textDim
                    hint: "Dismiss message"
                    onClicked: ShellState.toast = ""
                }
            }
        }
    }
}
