import QtQuick

// Free-standing heading in the brand face, uppercase. Double click edits.
Item {
    id: root
    property Item node
    clip: true
    readonly property int px: node.fontSize

    Text {
        visible: !node.editing
        anchors.fill: parent
        anchors.margins: 6
        text: node.content.length > 0 ? node.content : "Title"
        opacity: node.content.length > 0 ? 1 : 0.3
        color: Theme.text
        font.family: Theme.headingFamily
        font.weight: Theme.headingWeight
        font.pixelSize: root.px
        font.capitalization: Font.AllUppercase
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.Wrap
        fontSizeMode: Text.Fit             // the brand face is wide: shrink instead of cutting the title
        minimumPixelSize: 10
        renderType: Text.QtRendering
    }
    Loader {
        anchors.fill: parent
        active: node.editing
        sourceComponent: Item {
            TextEdit {
                id: ed
                anchors.fill: parent
                anchors.margins: 6
                wrapMode: TextEdit.Wrap
                color: Theme.text
                font.family: Theme.headingFamily
                font.weight: Theme.headingWeight
                font.pixelSize: root.px
                font.capitalization: Font.AllUppercase
                horizontalAlignment: TextEdit.AlignHCenter
                verticalAlignment: TextEdit.AlignVCenter
                selectionColor: Theme.alpha(Theme.accent, 0.45)
                selectedTextColor: Theme.text
                selectByMouse: true
                renderType: Text.QtRendering
                Component.onCompleted: { original = node.content; text = node.content; board.beginGesture(); forceActiveFocus(); selectAll() }
                Component.onDestruction: board.endGesture()
                onTextChanged: if (activeFocus) save.restart()
                Timer { id: save; interval: 500; onTriggered: board.setNodeData(node.nodeId, "content", ed.text) }
                property string original: ""
                function cancel() {
                    save.stop()
                    if (node.content !== original) board.setNodeData(node.nodeId, "content", original)
                    board.editingId = ""
                    Cam.focusRequested()
                }
                function finish() {
                    save.stop()
                    board.setNodeData(node.nodeId, "content", ed.text)
                    board.editingId = ""
                    Cam.focusRequested()
                }
                Keys.onEscapePressed: finish()
                Keys.onReturnPressed: finish()
                Keys.onEnterPressed: finish()
                onActiveFocusChanged: if (!activeFocus && node.editing) finish()
                Connections { target: Cam; function onEditAccept() { ed.finish() } function onEditCancel() { ed.cancel() } }
            }
        }
    }
}
