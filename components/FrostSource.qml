import QtQuick
import QtQuick.Effects
import "../core"

// One screen's wallpaper, blurred, for the glass cases of one window (Frost.qml). Each window needs its own, as
// pictures don't cross windows. It is laid out as the wallpaper is on the screen, at a quarter of the size (the blur
// hides the rest), and holds nothing while glass is off.
Item {
    id: root
    property string screenName: ""
    // The screen's size in logical pixels.
    property size screenSize: Qt.size(1920, 1080)
    readonly property string path: ShellState.activeWallpapers[screenName] || ""
    readonly property bool active: Theme.glass && path !== ""
    readonly property bool ready: active && picture.status === Image.Ready
    readonly property Item frosted: heavyTexture
    readonly property size pictureSize: Qt.size(Math.max(1, Math.round(screenSize.width / 4)), Math.max(1, Math.round(screenSize.height / 4)))
    width: 0
    height: 0
    Image {
        id: picture
        visible: false
        width: root.pictureSize.width
        height: root.pictureSize.height
        source: root.active ? "file://" + root.path : ""
        sourceSize: root.pictureSize
        asynchronous: true
        // A new wallpaper replaces the old one when it has loaded, so the glass never goes blank in between.
        retainWhileLoading: true
        // As Settings → Appearance → Wallpaper fit lays it out (tiles are drawn as a fill: too small to tell).
        fillMode: ({contain: Image.PreserveAspectFit, fill: Image.Stretch})[ShellState.setting("wallpaperFit", "cover")] ?? Image.PreserveAspectCrop
    }
    MultiEffect {
        id: heavy
        width: root.pictureSize.width
        height: root.pictureSize.height
        source: picture
        blurEnabled: true
        blur: 1
        blurMax: 24
        autoPaddingEnabled: false
    }
    ShaderEffectSource {
        id: heavyTexture
        sourceItem: heavy
        hideSource: true
        visible: false
    }
}
