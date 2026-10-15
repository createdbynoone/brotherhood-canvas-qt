import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects

// Boards of the open vault: search, create, rename (double click), reorder (drag), delete.
// Glass like Studio's inspector: a blurred copy of the canvas behind it plus a tint that keeps text readable.
Item {
    id: root
    signal settingsClicked()
    property Item blurSource: null          // the canvas whose pixels are blurred behind the panel

    ShaderEffectSource {
        id: backdrop
        anchors.fill: parent
        sourceItem: root.blurSource
        sourceRect: root.blurSource ? Qt.rect(root.x - root.blurSource.x, root.y - root.blurSource.y, root.width, root.height) : Qt.rect(0, 0, 0, 0)
        visible: false
        live: root.visible && root.x > -root.width
    }
    MultiEffect {
        anchors.fill: parent
        visible: root.blurSource !== null
        source: backdrop
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 48
        blur: 1.0
        maskEnabled: true
        maskSource: maskShape
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
    Rectangle {
        id: maskShape
        anchors.fill: parent
        radius: Theme.rPanel
        layer.enabled: true
        visible: false
    }
    Rectangle {
        anchors.fill: parent
        radius: Theme.rPanel
        color: Theme.alpha(Theme.surface, root.blurSource ? 0.72 : 1)
        border.color: Theme.hairlineStrong
    }
    Rectangle {   // the glass edge
        anchors.fill: parent
        anchors.margins: 1
        radius: Theme.rPanel
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.06)
    }

    MouseArea { anchors.fill: parent; z: -1; acceptedButtons: Qt.AllButtons; onWheel: w => w.accepted = true }   // the sidebar floats over the canvas: swallow input

    property string filter: ""
    property string renamingId: ""
    property string pendingDelete: ""

    function relative(iso) {
        const t = Date.parse(iso)
        if (isNaN(t)) return ""
        const s = Math.max(0, (Date.now() - t) / 1000)
        if (s < 60) return "just now"
        if (s < 3600) return Math.floor(s / 60) + " min ago"
        if (s < 86400) return Math.floor(s / 3600) + " h ago"
        if (s < 86400 * 7) return Math.floor(s / 86400) + " d ago"
        return new Date(t).toLocaleDateString(Qt.locale(), "d MMM yyyy")
    }

    ConfirmDialog {
        id: confirm
        property string boardId: ""
        title: "Delete this board?"
        message: "The board and its connections are removed. Files stay in the vault."
        confirmText: "Delete"
        destructive: true
        onConfirmed: canvas.deleteBoard(boardId)
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Item {
            width: parent.width; height: 28
            Txt { text: "Boards"; variant: "heading"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
            Txt { text: board.count + (board.count === 1 ? " item" : " items"); variant: "caption"; muted: true; anchors.left: parent.left; anchors.leftMargin: 70; anchors.verticalCenter: parent.verticalCenter; visible: false }
            Btn {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                kind: "secondary"; size: "s"; icon: "plus"; text: "New"; tip: "New board"; hint: "⌘N"
                onClicked: { const id = canvas.newBoard(); if (id.length > 0) Qt.callLater(() => { root.renamingId = id }) }
            }
        }
        Field {
            id: search
            width: parent.width
            icon: "magnifying-glass"; placeholder: "Search boards"; clearable: true
            onEdited: root.filter = text
        }

        ListView {
            id: list
            width: parent.width
            height: parent.height - 28 - 32 - 10 * 2 - footer.height - 10
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: 2
            model: canvas.boards
            ScrollBar.vertical: StudioScrollBar {}
            property int dragFrom: -1
            property int dragTo: -1

            delegate: Item {
                id: rowItem
                required property int index
                required property string boardId
                required property string name
                required property int nodeCount
                required property string updatedAt
                readonly property bool current: boardId === canvas.currentBoardId
                readonly property bool matches: root.filter.length === 0 || name.toLowerCase().indexOf(root.filter.toLowerCase()) >= 0
                readonly property bool renaming: root.renamingId === boardId
                width: list.width
                height: matches ? 52 : 0
                visible: matches
                opacity: list.dragFrom === index ? 0.35 : 1

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.rControl + 2
                    color: rowItem.current ? Theme.accentSoft : rowHover.hovered ? Theme.raised : "transparent"
                    border.color: rowItem.current ? Theme.alpha(Theme.accent, 0.35) : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                }
                Rectangle {
                    visible: rowItem.current
                    x: 0; anchors.verticalCenter: parent.verticalCenter
                    width: 3; height: 22; radius: 1.5; color: Theme.accent
                }
                Column {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 14; anchors.rightMargin: 36
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Txt {
                        visible: !rowItem.renaming
                        width: parent.width; text: rowItem.name; variant: "strong"; elide: Text.ElideRight
                        color: rowItem.current ? Theme.text : Theme.text
                    }
                    Loader {
                        active: rowItem.renaming
                        width: parent.width; height: active ? 24 : 0
                        sourceComponent: Field {
                            implicitHeight: 24
                            text: rowItem.name
                            Component.onCompleted: { forceFocus(); inputItem.selectAll() }
                            onAccepted: { canvas.renameBoard(rowItem.boardId, text); root.renamingId = "" }
                            inputItem.Keys.onEscapePressed: root.renamingId = ""
                            inputItem.onActiveFocusChanged: if (!inputItem.activeFocus && root.renamingId === rowItem.boardId) { canvas.renameBoard(rowItem.boardId, text); root.renamingId = "" }
                        }
                    }
                    Txt {
                        visible: !rowItem.renaming
                        text: rowItem.nodeCount + (rowItem.nodeCount === 1 ? " item" : " items") + "  ·  " + root.relative(rowItem.updatedAt)
                        variant: "caption"; muted: true
                    }
                }
                Btn {
                    visible: rowHover.hovered && !rowItem.renaming && list.dragFrom < 0
                    anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                    kind: "ghost"; size: "xs"; icon: "trash"; tip: "Delete board"
                    onClicked: { confirm.boardId = rowItem.boardId; confirm.open() }
                }

                HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { enabled: !rowItem.renaming; onTapped: canvas.openBoard(rowItem.boardId); onDoubleTapped: root.renamingId = rowItem.boardId }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: { rowMenu.boardId = rowItem.boardId; rowMenu.popup() }
                }
                DragHandler {
                    id: dh
                    target: null
                    enabled: !rowItem.renaming && root.filter.length === 0
                    yAxis.enabled: true; xAxis.enabled: false
                    dragThreshold: 8
                    cursorShape: Qt.ClosedHandCursor
                    onActiveChanged: {
                        if (active) { list.dragFrom = rowItem.index; list.dragTo = rowItem.index }
                        else {
                            if (list.dragFrom >= 0 && list.dragTo !== list.dragFrom) canvas.moveBoard(list.dragFrom, list.dragTo)
                            list.dragFrom = -1; list.dragTo = -1
                        }
                    }
                    onCentroidChanged: {
                        if (!active) return
                        const y = rowItem.mapToItem(list.contentItem, centroid.position.x, centroid.position.y).y
                        list.dragTo = Math.max(0, Math.min(list.count - 1, Math.floor(y / 54)))
                    }
                }
            }
            // Drop marker while reordering
            Rectangle {
                visible: list.dragFrom >= 0 && list.dragTo !== list.dragFrom
                parent: list.contentItem
                x: 0; width: list.width; height: 2; radius: 1
                y: (list.dragTo > list.dragFrom ? (list.dragTo + 1) * 54 : list.dragTo * 54) - 2
                color: Theme.accent
                z: 10
            }
            Txt {
                visible: root.filter.length > 0 && canvas.boards.matchCount(root.filter) === 0
                anchors.horizontalCenter: parent.horizontalCenter; y: 24; text: "No board matches"; dim: true
            }
        }
    }

    StudioMenu {
        id: rowMenu
        property string boardId: ""
        MenuRow { text: "Open"; glyph: "arrow-square-out"; onTriggered: canvas.openBoard(rowMenu.boardId) }
        MenuRow { text: "Rename"; glyph: "pencil-simple"; onTriggered: root.renamingId = rowMenu.boardId }
        MenuDivider {}
        MenuRow { text: "Delete"; glyph: "trash"; danger: true; onTriggered: { confirm.boardId = rowMenu.boardId; confirm.open() } }
    }

    Item {
        id: footer
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 12
        height: 44
        Icon { name: "vault"; size: 18; color: Theme.textDim; anchors.left: parent.left; anchors.leftMargin: 2; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 3 }
        Column {
            anchors.left: parent.left; anchors.leftMargin: 28; anchors.right: gear.left; anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 3
            spacing: 1
            Txt { width: parent.width; text: canvas.vaultName; variant: "strong"; font.pixelSize: 12; elide: Text.ElideRight }
        }
        Btn { id: gear; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 3; kind: "ghost"; size: "s"; icon: "gear"; tip: "Settings"; hint: "⌘,"; onClicked: root.settingsClicked() }
    }
}
