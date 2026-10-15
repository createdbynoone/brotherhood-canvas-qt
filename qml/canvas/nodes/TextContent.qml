import QtQuick

// Text card and note: Markdown when at rest, a plain editor on double click.
// A note is a sticky note: ink on its own colour, and its # headings are drawn in the marker face (uppercase).
// Leaving the editor: the floating check / x (Cam.editAccept / editCancel), Esc or a click elsewhere keep the text.
Item {
    id: root
    property Item node
    readonly property bool isNote: node.nodeType === "note"
    readonly property color ink: isNote ? node.noteInk : Theme.text
    readonly property real padX: 14
    readonly property real padTop: isNote ? 15 : 12
    clip: true

    // Split Markdown into heading lines and the runs of ordinary text between them
    readonly property var segments: {
        if (!isNote) return []
        const out = []
        let run = []
        const flush = () => { if (run.length) { out.push({ h: 0, t: run.join("\n") }); run = [] } }
        for (const line of node.content.split("\n")) {
            const m = /^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$/.exec(line)
            if (m) { flush(); out.push({ h: m[1].length, t: m[2] }) }
            else run.push(line)
        }
        flush()
        return out
    }

    Text {
        id: rendered
        visible: !root.isNote && !node.editing && node.content.length > 0
        x: root.padX; y: root.padTop
        width: parent.width - root.padX * 2
        height: parent.height - root.padTop - 10
        text: node.content
        textFormat: Text.MarkdownText
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        color: root.ink
        font.family: Theme.sans
        font.pixelSize: 13
        lineHeight: 1.25
        renderType: Text.QtRendering
        clip: true
    }
    Column {
        visible: root.isNote && !node.editing && node.content.length > 0
        x: root.padX; y: root.padTop
        width: parent.width - root.padX * 2
        spacing: 4
        Repeater {
            model: root.segments
            delegate: Text {
                required property var modelData
                width: parent.width
                text: modelData.t
                textFormat: modelData.h > 0 ? Text.PlainText : Text.MarkdownText
                wrapMode: Text.Wrap
                color: root.ink
                font.family: modelData.h > 0 ? Theme.markerFamily : Theme.sans
                font.weight: modelData.h > 0 && Theme.marker.length === 0 ? Font.Bold : Font.Normal
                font.capitalization: modelData.h > 0 ? Font.AllUppercase : Font.MixedCase
                font.pixelSize: modelData.h === 1 ? 30 : modelData.h === 2 ? 23 : modelData.h > 2 ? 18 : 13
                lineHeight: modelData.h > 0 ? 1.0 : 1.25
                renderType: Text.QtRendering
            }
        }
    }
    Txt {
        visible: !node.editing && node.content.length === 0
        x: root.padX; y: root.padTop
        text: "Double-click to write"
        font.italic: true; muted: true
        color: root.isNote ? root.ink : Theme.textMuted
        opacity: root.isNote ? 0.55 : 1
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
                color: root.ink
                font.family: Theme.sans
                font.pixelSize: 13
                selectionColor: Theme.alpha(Theme.accent, 0.45)
                selectedTextColor: root.ink
                selectByMouse: true
                renderType: Text.QtRendering
                persistentSelection: true
                property string original: ""
                Component.onCompleted: {
                    original = node.content
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
                function cancel() {
                    save.stop()
                    if (node.content !== original) board.setNodeData(node.nodeId, "content", original)
                    board.editingId = ""
                    Cam.focusRequested()
                }
                Keys.onEscapePressed: finish()
                Keys.onPressed: e => { if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && (e.modifiers & Qt.ControlModifier)) { finish(); e.accepted = true } }
                onActiveFocusChanged: if (!activeFocus && node.editing) finish()
                Connections { target: Cam; function onEditAccept() { ed.finish() } function onEditCancel() { ed.cancel() } }
            }
        }
    }
}
