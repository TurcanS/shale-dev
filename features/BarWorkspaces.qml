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

Rectangle {
    id: pages
    // The bar this item is on: its screen, layout, weather and helpers.
    required property var bar
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
