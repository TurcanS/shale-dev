import QtQuick
import QtQuick.Layouts
import "../core"
import "." as C

// One row of a settings group: its name and a line about it on the left, its control on the right. Stacked rows put
// the control under the name, for controls too wide to share the line. Rows sit on a Group, divided by its hairlines.
Item {
    id: root
    property string label: ""
    property string description: ""
    // A row's own error or confirmation tints its description.
    property color descriptionColor: Theme.textDim
    property bool stacked: false
    default property alias control: controls.data
    Layout.fillWidth: true
    implicitWidth: grid.implicitWidth + 2 * Theme.gapL
    implicitHeight: Math.max(description !== "" || stacked ? 58 : 48, grid.implicitHeight + 20)
    Accessible.role: Accessible.Grouping
    Accessible.name: label
    Accessible.description: description
    GridLayout {
        id: grid
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.gapL
        anchors.rightMargin: Theme.gapL
        anchors.verticalCenter: parent.verticalCenter
        columns: root.stacked ? 1 : 2
        columnSpacing: Theme.gapL
        rowSpacing: Theme.gapS + 2
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            C.Label {
                visible: text !== ""
                text: root.label
                color: root.enabled ? Theme.text : Theme.textFaint
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            C.Label {
                visible: text !== ""
                text: root.description
                color: root.descriptionColor
                font.pixelSize: Theme.small
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                Layout.fillWidth: true
            }
        }
        RowLayout {
            id: controls
            spacing: Theme.gapS
            Layout.fillWidth: root.stacked
            Layout.alignment: root.stacked ? Qt.AlignLeft | Qt.AlignVCenter : Qt.AlignRight | Qt.AlignVCenter
        }
    }
}
