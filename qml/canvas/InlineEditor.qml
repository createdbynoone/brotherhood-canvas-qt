import QtQuick

// A small floating text field in screen space (node labels, edge labels). Enter or focus loss commits, Esc cancels.
Rectangle {
    id: root
    property string placeholder: ""
    property string initial: ""
    property bool shown: false
    property real anchorX: 0            // centre x on screen
    property real anchorY: 0            // top y on screen
    signal committed(string text)
    signal cancelled()

    function open(text) { initial = text; field.text = text; shown = true; field.forceFocus(); field.inputItem.selectAll() }
    function close() { shown = false }

    visible: shown
    width: 240; height: 40
    x: Math.max(8, Math.min(parent.width - width - 8, anchorX - width / 2))
    y: Math.max(8, Math.min(parent.height - height - 8, anchorY))
    radius: Theme.rCard
    color: Theme.elevated
    border.color: Theme.alpha(Theme.accent, 0.7)
    property bool done: false

    Field {
        id: field
        anchors.fill: parent; anchors.margins: 5
        placeholder: root.placeholder
        onAccepted: { root.done = true; root.shown = false; root.committed(text); Cam.focusRequested() }
        inputItem.Keys.onEscapePressed: { root.done = true; root.shown = false; root.cancelled(); Cam.focusRequested() }
        inputItem.onActiveFocusChanged: {
            if (!inputItem.activeFocus && root.shown) { root.shown = false; root.committed(text) }
            else if (inputItem.activeFocus) root.done = false
        }
    }
}
