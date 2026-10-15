import QtQuick

// Floating confirm / cancel pill that rides above the node being edited: check keeps the text, x drops it.
Rectangle {
    id: root
    readonly property bool shown: board.editingId !== ""
    readonly property rect r: { Cam.panX; Cam.panY; Cam.zoom; return shown ? board.rectOf(board.editingId) : Qt.rect(0, 0, 0, 0) }
    readonly property real cx: Cam.sx(r.x + r.width / 2)
    readonly property real above: Cam.sy(r.y) - height - 10

    visible: shown
    width: 84; height: 40
    radius: Theme.rCard
    color: Theme.elevated
    border.color: Theme.hairlineStrong
    x: Math.max(8, Math.min(parent.width - width - 8, cx - width / 2))
    y: above >= 8 ? above : Math.min(parent.height - height - 8, Cam.sy(r.y + r.height) + 10)

    // A press here must not pull focus from the editor (the editor commits on focus loss)
    Row {
        anchors.centerIn: parent
        spacing: 6
        Rectangle {
            width: 32; height: 28; radius: Theme.rControl
            color: okHover.hovered ? Theme.accentHover : Theme.accent
            Icon { anchors.centerIn: parent; name: "check"; weight: "bold"; size: 15; color: Theme.accentInk }
            HoverHandler { id: okHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: Cam.editAccept() }
        }
        Rectangle {
            width: 32; height: 28; radius: Theme.rControl
            color: noHover.hovered ? Theme.raised : "transparent"
            Icon { anchors.centerIn: parent; name: "x"; weight: "bold"; size: 15; color: noHover.hovered ? Theme.text : Theme.textDim }
            HoverHandler { id: noHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: Cam.editCancel() }
        }
    }
}
