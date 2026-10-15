import QtQuick
import QtQuick.Dialogs

// The tool dock at the bottom: pointer tools, add content, history, zoom, background, export.
Rectangle {
    id: root
    property Item view
    property real room: 100000          // width the dock may use; a narrow window drops the secondary tools
    readonly property bool slim: room < 620
    signal exportClicked()

    FileDialog {
        id: media
        title: "Add to this board"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["Images, video, PDF and text (*.png *.jpg *.jpeg *.gif *.webp *.heic *.tiff *.mp4 *.mov *.m4v *.webm *.pdf *.txt *.md)", "All files (*)"]
        onAccepted: { const c = root.view.centerWorld(); canvas.importUrls(selectedFiles, c.x - 120, c.y - 90) }
    }

    width: row.implicitWidth + 16
    height: 48
    radius: Theme.rPanel
    color: Theme.alpha(Theme.surface, 0.96)
    border.color: Theme.hairlineStrong

    component Sep: Rectangle { width: 1; height: 20; color: Theme.hairline; anchors.verticalCenter: parent.verticalCenter }
    component Tool: Rectangle {
        id: t
        property string icon: ""
        property string tip: ""
        property string hint: ""
        property bool on: false
        property bool enabled_: true
        signal clicked()
        width: 34; height: 34; radius: Theme.rControl
        anchors.verticalCenter: parent.verticalCenter
        color: on ? Theme.accentSoft : th.hovered && enabled_ ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
        opacity: enabled_ ? 1 : 0.35
        Icon { anchors.centerIn: parent; name: t.icon; size: 18; color: t.on ? Theme.accent : th.hovered ? Theme.text : Theme.textDim }
        HoverHandler { id: th; cursorShape: Qt.PointingHandCursor }
        TapHandler { enabled: t.enabled_; onTapped: t.clicked() }
        Tip { target: t; text: t.tip; hint: t.hint }
    }

    StudioMenu {
        id: zoomMenu
        MenuRow { text: "Fit all"; hint: "F"; glyph: "frame-corners"; onTriggered: root.view.fitAll() }
        MenuRow { text: "Zoom to selection"; hint: "⇧F"; glyph: "selection"; enabled: board.selectedCount > 0; onTriggered: root.view.fitSelection() }
        MenuRow { text: "Actual size"; hint: "⌘0"; glyph: "magnifying-glass"; onTriggered: root.view.resetZoom() }
    }
    StudioMenu {
        id: bgMenu
        MenuRow { text: "Dots"; glyph: "dots-nine"; checkable: true; checked: board.background === "dots"; onTriggered: board.background = "dots" }
        MenuRow { text: "Lines"; glyph: "grid-four"; checkable: true; checked: board.background === "lines"; onTriggered: board.background = "lines" }
        MenuRow { text: "Cross"; glyph: "plus"; checkable: true; checked: board.background === "cross"; onTriggered: board.background = "cross" }
        MenuRow { text: "None"; glyph: "square"; checkable: true; checked: board.background === "none"; onTriggered: board.background = "none" }
    }

    Row {
        id: row
        x: 8; anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Tool { icon: "cursor"; tip: "Select"; hint: "V"; on: Cam.tool === "select"; onClicked: Cam.tool = "select" }
        Tool { icon: "hand"; tip: "Pan"; hint: "H"; on: Cam.tool === "pan"; onClicked: Cam.tool = "pan" }
        Sep {}
        Tool { icon: "text-h-one"; tip: "Add title"; hint: "T"; onClicked: { const c = root.view.centerWorld(); canvas.addText(c.x, c.y, "title") } }
        Tool { icon: "note"; tip: "Add note"; hint: "N"; onClicked: { const c = root.view.centerWorld(); canvas.addText(c.x, c.y, "note") } }
        Tool { icon: "text-t"; tip: "Add text"; hint: "X"; onClicked: { const c = root.view.centerWorld(); canvas.addText(c.x, c.y, "text") } }
        Tool { icon: "image"; tip: "Add images, video or PDF"; onClicked: media.open() }
        Sep {}
        Tool { visible: !root.slim; icon: "arrow-u-up-left"; tip: "Undo"; hint: "⌘Z"; enabled_: board.canUndo; onClicked: board.undo() }
        Tool { visible: !root.slim; icon: "arrow-u-up-right"; tip: "Redo"; hint: "⇧⌘Z"; enabled_: board.canRedo; onClicked: board.redo() }
        Sep { visible: !root.slim }
        Tool { visible: !root.slim; icon: "magnifying-glass-minus"; tip: "Zoom out"; hint: "-"; onClicked: root.view.zoomStep(0.8) }
        Rectangle {
            width: 52; height: 34; radius: Theme.rControl
            anchors.verticalCenter: parent.verticalCenter
            color: zh.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
            Txt { anchors.centerIn: parent; text: Math.round(Cam.zoom * 100) + "%"; variant: "mono"; dim: true }
            HoverHandler { id: zh; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: zoomMenu.popup(parent, 0, -zoomMenu.implicitHeight - 8) }
            Tip { target: parent; text: "Zoom"; }
        }
        Tool { visible: !root.slim; icon: "magnifying-glass-plus"; tip: "Zoom in"; hint: "+"; onClicked: root.view.zoomStep(1.25) }
        Tool { icon: "frame-corners"; tip: "Fit all"; hint: "F"; enabled_: board.count > 0; onClicked: root.view.fitAll() }
        Sep {}
        Tool { visible: !root.slim; icon: "dots-nine"; tip: "Background"; onClicked: bgMenu.popup(parent, 0, -bgMenu.implicitHeight - 8) }
        Tool { visible: !root.slim; icon: "map-trifold"; tip: "Minimap"; on: app.minimap; onClicked: app.minimap = !app.minimap }
        Tool { icon: "export"; tip: "Export board"; enabled_: board.count > 0 && !canvas.exporting; onClicked: root.exportClicked() }
    }
    MouseArea { anchors.fill: parent; z: -1; acceptedButtons: Qt.AllButtons; hoverEnabled: true; onWheel: w => w.accepted = true }
}
