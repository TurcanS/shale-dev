import QtQuick

// Keeps the keyboard focus in view: when focus moves to an item inside `content`, `flickable` scrolls just far enough
// to show it, with a little room around it. Place it anywhere in the same window.
Item {
    id: root
    // A Flickable, or a ScrollView's contentItem (declared as an Item).
    property Item flickable: null
    property Item content: null
    property int margin: 12
    visible: false
    function reveal() {
        const item = Window.activeFocusItem;
        if (!item || !flickable || !content || !flickable.visible)
            return;
        let inside = item;
        while (inside && inside !== content)
            inside = inside.parent;
        if (!inside)
            return;
        const top = item.mapToItem(flickable.contentItem, 0, 0).y;
        const bottom = top + item.height;
        const view = flickable.height;
        const most = Math.max(0, flickable.contentHeight - view);
        if (top - margin < flickable.contentY)
            flickable.contentY = Math.max(0, top - margin);
        else if (bottom + margin > flickable.contentY + view)
            flickable.contentY = Math.min(most, bottom + margin - view);
    }
    Connections {
        target: root.Window
        function onActiveFocusItemChanged() {
            root.reveal();
        }
    }
}
