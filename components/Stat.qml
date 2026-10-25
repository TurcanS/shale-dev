import QtQuick
import QtQuick.Layouts
import "../core"

// A labelled headline number with an optional note, for summary rows: a stat tile, one step below a module.
Card {
    id: stat
    color: Theme.moduleAlt
    radius: Theme.radiusCard
    property string label: ""
    property string value: ""
    property string note: ""
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.preferredHeight: Math.max(64, content.implicitHeight + 2 * Theme.gapM - 4)
    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.gapM - 2
        spacing: 1
        Label { text: stat.label; font.pixelSize: Theme.small; color: Theme.textDim; Layout.fillWidth: true }
        Label { text: stat.value; font.pixelSize: Theme.body + 8; font.weight: 650; font.features: {"tnum": 1}; Layout.fillWidth: true }
        Caption { visible: stat.note !== ""; text: stat.note; color: Theme.textFaint; Layout.fillWidth: true }
    }
}
