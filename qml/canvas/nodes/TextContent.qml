import QtQuick

// Text card and note: Markdown when at rest, a plain editor on double click. Esc or a click elsewhere confirms.
Item {
    id: root
    property Item node
    readonly property bool isNote: node.nodeType === "note"
    readonly property real padX: 14
    readonly property real padTop: isNote ? 15 : 12
    clip: true

    Text {
        id: rendered
        visible: !node.editing && node.content.length > 0
        x: root.padX; y: root.padTop
        width: parent.width - root.padX * 2
        height: parent.height - root.padTop - 10
        text: node.content
        textFormat: Text.MarkdownText
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        color: Theme.text
        font.family: Theme.sans
        font.pixelSize: 13
        lineHeight: 1.25
        renderType: Text.QtRendering
        clip: true
    }
    Txt {
        visible: !node.editing && node.content.length === 0
        x: root.padX; y: root.padTop
        text: "Double-click to write"
        font.italic: true; muted: true
        renderType: Text.QtRendering
    }

    Loader {
        anchors.fill: parent
        active: node.editing
        sourceComponent: Item {
            TextEdit {
                id: ed
                x: root.padX; y: root.padTop
                width: parent.width - root.padX * 2
                height: parent.height - root.padTop - 10
                wrapMode: TextEdit.Wrap
                color: Theme.text
                font.family: Theme.sans
                font.pixelSize: 13
                selectionColor: Theme.alpha(Theme.accent, 0.45)
                selectedTextColor: Theme.text
                selectByMouse: true
                renderType: Text.QtRendering
                persistentSelection: true
                Component.onCompleted: {
                    text = node.content            // a one-time copy: a binding would reset the cursor while typing
                    board.beginGesture()
                    forceActiveFocus()
                    cursorPosition = text.length
                }
                Component.onDestruction: { board.endGesture() }
                onTextChanged: if (activeFocus) save.restart()
                Timer { id: save; interval: 500; onTriggered: board.setNodeData(node.nodeId, "content", ed.text) }
                function finish() {
                    save.stop()
                    board.setNodeData(node.nodeId, "content", ed.text)
                    board.editingId = ""
                    Cam.focusRequested()
                }
                Keys.onEscapePressed: finish()
                Keys.onPressed: e => { if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && (e.modifiers & Qt.ControlModifier)) { finish(); e.accepted = true } }
                onActiveFocusChanged: if (!activeFocus && node.editing) finish()
            }
        }
    }
}
