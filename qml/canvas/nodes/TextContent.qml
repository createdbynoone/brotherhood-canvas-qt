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

    // What was typed is what is shown: one row per source line. Blank lines stay as gaps (Markdown would merge them),
    // a single Enter stays a line break, and list items hang from a narrow marker instead of Qt's wide list indent.
    // Whole-document Markdown (tables, code, quotes, rules, images) or a very long text falls back to the plain renderer.
    readonly property bool complex: {
        const c = node.content
        return c.length > 6000 || /```|^\s*\|.*\|\s*$|^\s*>|^\s*!\[|^\s*([-*_])(\s*\1){2,}\s*$/m.test(c)
    }
    readonly property var rows: {
        if (complex) return []
        const out = []
        for (const line of node.content.split("\n")) {
            if (line.trim().length === 0) { out.push({ k: "gap" }); continue }
            let m = /^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$/.exec(line)
            if (m) { out.push({ k: "h", h: m[1].length, t: m[2] }); continue }
            m = /^(\s*)([-*+]|\d+[.)])\s+(.*)$/.exec(line)
            if (m) { out.push({ k: "li", lvl: Math.min(3, Math.floor(m[1].replace(/\t/g, "    ").length / 2)), m: /\d/.test(m[2]) ? m[2] : "\u2022", t: m[3] }); continue }
            out.push({ k: "p", t: line })
        }
        return out
    }

    Column {
        visible: !root.complex && !node.editing && node.content.length > 0
        x: root.padX; y: root.padTop
        width: parent.width - root.padX * 2
        spacing: 3
        Repeater {
            model: root.rows
            delegate: Item {
                id: ln
                required property var modelData
                readonly property bool heading: modelData.k === "h"
                readonly property real indent: modelData.k === "li" ? modelData.lvl * 14 : 0
                readonly property real markW: modelData.k === "li" ? 17 : 0
                width: parent.width
                height: modelData.k === "gap" ? 11 : body.implicitHeight
                Text {
                    visible: ln.modelData.k === "li"
                    x: ln.indent; width: ln.markW
                    text: ln.modelData.m || ""
                    color: root.ink; opacity: 0.75
                    font.family: Theme.sans; font.pixelSize: 13; lineHeight: 1.25
                    renderType: Text.QtRendering
                }
                Text {
                    id: body
                    visible: ln.modelData.k !== "gap"
                    x: ln.indent + ln.markW
                    width: ln.width - x
                    text: ln.modelData.t || ""
                    textFormat: ln.heading ? Text.PlainText : Text.MarkdownText
                    wrapMode: Text.Wrap
                    color: root.ink
                    // notes draw headings in the marker face (uppercase); text cards in the UI face, bold
                    font.family: ln.heading && root.isNote ? Theme.markerFamily : Theme.sans
                    font.weight: ln.heading && (!root.isNote || Theme.marker.length === 0) ? Font.Bold : Font.Normal
                    font.capitalization: ln.heading && root.isNote ? Font.AllUppercase : Font.MixedCase
                    font.pixelSize: ln.heading ? (root.isNote ? (modelData.h === 1 ? 30 : modelData.h === 2 ? 23 : 18) : (modelData.h === 1 ? 22 : modelData.h === 2 ? 18 : 15)) : 13
                    lineHeight: ln.heading && root.isNote ? 1.0 : 1.25
                    renderType: Text.QtRendering
                }
            }
        }
    }
    Text {
        id: rendered
        visible: root.complex && !node.editing && node.content.length > 0
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
        active: node.editing && !Cam.exporting
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
