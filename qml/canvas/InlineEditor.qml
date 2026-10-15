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
    width: 240 + 76; height: 40
    x: Math.max(8, Math.min(parent.width - width - 8, anchorX - width / 2))
    y: Math.max(8, Math.min(parent.height - height - 8, anchorY))
    radius: Theme.rCard
    color: Theme.elevated
    border.color: Theme.alpha(Theme.accent, 0.7)
    property bool done: false

    function accept() { done = true; shown = false; committed(field.text); Cam.focusRequested() }
    function cancel() { done = true; shown = false; cancelled(); Cam.focusRequested() }

    Row {
        id: btns
        anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Rectangle {
            width: 32; height: 28; radius: Theme.rControl
            color: okHover.hovered ? Theme.accentHover : Theme.accent
            Icon { anchors.centerIn: parent; name: "check"; weight: "bold"; size: 15; color: Theme.accentInk }
            HoverHandler { id: okHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.accept() }
        }
        Rectangle {
            width: 32; height: 28; radius: Theme.rControl
            color: noHover.hovered ? Theme.raised : "transparent"
            Icon { anchors.centerIn: parent; name: "x"; weight: "bold"; size: 15; color: noHover.hovered ? Theme.text : Theme.textDim }
            HoverHandler { id: noHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.cancel() }
        }
    }
    Field {
        id: field
        anchors.left: parent.left; anchors.right: btns.left; anchors.top: parent.top; anchors.bottom: parent.bottom
        anchors.margins: 5
        placeholder: root.placeholder
        onAccepted: { root.done = true; root.shown = false; root.committed(text); Cam.focusRequested() }
        inputItem.Keys.onEscapePressed: { root.done = true; root.shown = false; root.cancelled(); Cam.focusRequested() }
        inputItem.onActiveFocusChanged: {
            if (!inputItem.activeFocus && root.shown) { root.shown = false; root.committed(text) }
            else if (inputItem.activeFocus) root.done = false
        }
    }
}
