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

// Something live or on (listening, recording, a focus session): a round accentSoft chip with accent text.
BarKey {
    implicitHeight: 24
    cornerRadius: 12
    rest: Theme.accentSoft
    leftPadding: 10
    rightPadding: 10
    foreground: Theme.accentText
}
