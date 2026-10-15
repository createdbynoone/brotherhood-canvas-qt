import QtQuick
import QtQuick.Controls.Basic

// The window once a vault is open: title bar, canvas, and everything that floats above it.
Item {
    id: ws
    property bool styleOpen: false

    // True when (sx, sy), in window (scene) coordinates, is title-bar space where a native drag may start.
    function dragAt(sx, sy) {
        const p = ws.mapFromItem(null, sx, sy)
        if (p.y > titleBar.height) return false
        if (p.y < 0) return true
        const c = titleBar.childAt(p.x, p.y)
        return !c || c.dragThrough === true
    }

    Component.onCompleted: {
        if (startOpen === "settings") settings.open()
        else if (startOpen === "palette") openPalette()
        else if (startOpen === "export") exportDialog.open()
    }

    Connections { target: app; function onToast(m, k) { toasts.show(m, k) } }
    Connections { target: canvas; function onToast(m, k) { toasts.show(m, k) } }
    Connections { target: board; function onToast(m, k) { toasts.show(m, k) } }
    Connections {
        target: board
        function onSelectionChanged() { if (board.selectedCount !== 1) ws.styleOpen = false }
    }

    Binding { target: Cam; property: "insetLeft"; value: app.sidebarOpen ? 12 + sidebar.width + 12 : 0 }

    // ── Commands ─────────────────────────────────────────────────────────
    property var commands: []
    function buildCommands() {
        const c = [
            { title: "New board", group: "Boards", hint: "⌘N", icon: "plus", run: () => canvas.newBoard() },
            { title: "Add title", group: "Add", hint: "T", icon: "text-h-one", run: () => { const p = cv.centerWorld(); canvas.addText(p.x, p.y, "title") } },
            { title: "Add note", group: "Add", hint: "N", icon: "note", run: () => { const p = cv.centerWorld(); canvas.addText(p.x, p.y, "note") } },
            { title: "Add text", group: "Add", hint: "X", icon: "text-t", run: () => { const p = cv.centerWorld(); canvas.addText(p.x, p.y, "text") } },
            { title: "Paste", group: "Edit", hint: "⌘V", icon: "clipboard", run: () => { const p = cv.centerWorld(); canvas.paste(p.x, p.y) } },
            { title: "Select all", group: "Edit", hint: "⌘A", icon: "selection-plus", run: () => board.selectAll() },
            { title: "Undo", group: "Edit", hint: "⌘Z", icon: "arrow-u-up-left", run: () => board.undo() },
            { title: "Redo", group: "Edit", hint: "⇧⌘Z", icon: "arrow-u-up-right", run: () => board.redo() },
            { title: "Fit all", group: "View", hint: "F", icon: "frame-corners", run: () => cv.fitAll() },
            { title: "Zoom to selection", group: "View", hint: "⇧F", icon: "selection", run: () => cv.fitSelection() },
            { title: "Actual size", group: "View", hint: "⌘0", icon: "magnifying-glass", run: () => cv.resetZoom() },
            { title: "Toggle sidebar", group: "View", hint: "⌘B", icon: "sidebar-simple", run: () => app.sidebarOpen = !app.sidebarOpen },
            { title: "Toggle minimap", group: "View", icon: "map-trifold", run: () => app.minimap = !app.minimap },
            { title: "Background: dots", group: "View", icon: "dots-nine", run: () => board.background = "dots" },
            { title: "Background: lines", group: "View", icon: "grid-four", run: () => board.background = "lines" },
            { title: "Background: cross", group: "View", icon: "plus", run: () => board.background = "cross" },
            { title: "Background: none", group: "View", icon: "square", run: () => board.background = "none" },
            { title: "Export board", group: "File", hint: "⇧⌘E", icon: "export", run: () => exportDialog.open() },
            { title: "Show vault in Finder", group: "File", icon: "folder-open", run: () => app.openPath(canvas.vaultPath) },
            { title: "Settings", group: "App", hint: "⌘,", icon: "gear", run: () => settings.open() },
            { title: "Check for updates", group: "App", icon: "download-simple", run: () => app.checkForUpdate() }
        ]
        if (board.selectedCount > 1) {
            c.push({ title: "Align left", group: "Arrange", icon: "align-left", run: () => board.align("left") },
                   { title: "Align right", group: "Arrange", icon: "align-right", run: () => board.align("right") },
                   { title: "Align top", group: "Arrange", icon: "align-top", run: () => board.align("top") },
                   { title: "Align bottom", group: "Arrange", icon: "align-bottom", run: () => board.align("bottom") },
                   { title: "Align centers", group: "Arrange", icon: "align-center-horizontal", run: () => board.align("hcenter") },
                   { title: "Align middles", group: "Arrange", icon: "align-center-vertical", run: () => board.align("vcenter") },
                   { title: "Distribute horizontally", group: "Arrange", icon: "arrows-out-line-horizontal", run: () => board.distribute("h") },
                   { title: "Distribute vertically", group: "Arrange", icon: "arrows-out-line-vertical", run: () => board.distribute("v") },
                   { title: "Tidy into a grid", group: "Arrange", icon: "squares-four", run: () => board.tidy() })
        }
        for (const b of canvas.boards.list()) {
            if (b.id === canvas.currentBoardId) continue
            const id = b.id
            c.push({ title: "Go to " + b.name, group: "Boards", icon: "squares-four", run: () => canvas.openBoard(id) })
        }
        commands = c
    }
    function openPalette() { buildCommands(); palette.show() }
    function iconFor(t) { return t === "image" ? "image" : t === "video" ? "film-strip" : t === "pdf" ? "file-pdf" : t === "note" ? "note" : t === "title" ? "text-h-one" : "text-t" }

    Shortcut { sequences: ["Ctrl+K"]; onActivated: ws.openPalette() }
    Shortcut { sequences: ["Ctrl+N"]; onActivated: { const id = canvas.newBoard(); if (id.length > 0) sidebar.renamingId = id } }
    Shortcut { sequences: ["Ctrl+B"]; onActivated: app.sidebarOpen = !app.sidebarOpen }
    Shortcut { sequences: ["Ctrl+,"]; onActivated: settings.open() }
    Shortcut { sequences: ["Ctrl+Shift+E"]; onActivated: exportDialog.open() }

    // ── Canvas ───────────────────────────────────────────────────────────
    CanvasView {
        id: cv
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.top: titleBar.bottom
        blocked: lightbox.open
        floating: [sidebar, toolbar, stylePanel, minimap]
        onStyleRequested: ws.styleOpen = !ws.styleOpen
        onPreviewRequested: id => lightbox.show(id)
        onContextRequested: info => ws.showMenu(info)
    }

    function showMenu(info) {
        const p = cv.mapToItem(ws, info.sx, info.sy)
        ctx.world = Qt.point(Cam.wx(info.sx), Cam.wy(info.sy))
        if (info.kind === "node") { ctx.refresh(); nodeMenu.popup(cv, info.sx, info.sy) }
        else if (info.kind === "edge") { ctx.edge = info.id; edgeMenu.popup(cv, info.sx, info.sy) }
        else paneMenu.popup(cv, info.sx, info.sy)
    }
    QtObject {
        id: ctx
        property point world
        property string edge: ""
        property var info: ({})
        property bool many: board.selectedCount > 1
        function refresh() { info = board.selectedCount === 1 ? board.nodeInfo(board.selectedId) : ({}) }
        readonly property bool hasFile: info.filePath !== undefined && info.filePath.length > 0
    }

    StudioMenu {
        id: nodeMenu
        MenuRow { visible: ctx.many; height: ctx.many ? implicitHeight : 0; enabled: false; text: board.selectedCount + " selected" }
        MenuRow { visible: !ctx.many && (ctx.info.type === "text" || ctx.info.type === "note" || ctx.info.type === "title"); height: visible ? implicitHeight : 0; text: "Edit text"; glyph: "pencil-simple"; hint: "Return"; onTriggered: board.editingId = board.selectedId }
        MenuRow { visible: !ctx.many && ctx.info.type !== "title"; height: visible ? implicitHeight : 0; text: "Edit label"; glyph: "tag"; onTriggered: cv.editNodeLabel(board.selectedId) }
        MenuRow { visible: !ctx.many; height: visible ? implicitHeight : 0; text: "Style"; glyph: "palette"; onTriggered: ws.styleOpen = true }
        MenuDivider { visible: !ctx.many; height: visible ? implicitHeight : 0 }
        MenuRow { text: "Copy"; glyph: "copy"; hint: "⌘C"; onTriggered: canvas.copySelection() }
        MenuRow { text: "Cut"; glyph: "scissors"; hint: "⌘X"; onTriggered: canvas.cutSelection() }
        MenuRow { text: "Paste"; glyph: "clipboard"; hint: "⌘V"; enabled: canvas.canPaste(); onTriggered: canvas.paste(ctx.world.x, ctx.world.y) }
        MenuRow { text: "Duplicate"; glyph: "copy-simple"; hint: "⌘D"; onTriggered: board.duplicateSelected() }
        MenuDivider {}
        MenuRow { text: "Bring to front"; glyph: "arrow-line-up"; hint: "⌘]"; onTriggered: board.bringToFront() }
        MenuRow { text: "Send to back"; glyph: "arrow-line-down"; hint: "⌘["; onTriggered: board.sendToBack() }
        MenuRow { text: board.hasSelectionLocked ? "Unlock position" : "Lock position"; glyph: board.hasSelectionLocked ? "lock-open" : "lock"; hint: "⌘L"; onTriggered: board.setLocked(!board.hasSelectionLocked) }
        MenuDivider { visible: ctx.hasFile; height: visible ? implicitHeight : 0 }
        MenuRow { visible: ctx.hasFile; height: visible ? implicitHeight : 0; text: "Show in Finder"; glyph: "folder-open"; onTriggered: canvas.revealNode(board.selectedId) }
        MenuRow { visible: ctx.hasFile; height: visible ? implicitHeight : 0; text: "Open with default app"; glyph: "arrow-square-out"; onTriggered: canvas.openNodeFile(board.selectedId) }
        MenuDivider {}
        MenuRow { text: "Delete"; glyph: "trash"; danger: true; hint: "Del"; onTriggered: board.deleteSelected() }
    }
    StudioMenu {
        id: edgeMenu
        MenuRow { text: "Edit label"; glyph: "tag"; onTriggered: cv.editEdgeLabel(ctx.edge) }
        MenuDivider {}
        MenuRow { text: "Delete connection"; glyph: "trash"; danger: true; hint: "Del"; onTriggered: board.deleteEdge(ctx.edge) }
    }
    StudioMenu {
        id: paneMenu
        MenuRow { text: "Paste"; glyph: "clipboard"; hint: "⌘V"; enabled: canvas.canPaste(); onTriggered: canvas.paste(ctx.world.x, ctx.world.y) }
        MenuRow { text: "Select all"; glyph: "selection-plus"; hint: "⌘A"; onTriggered: board.selectAll() }
        MenuDivider {}
        MenuRow { text: "Add title here"; glyph: "text-h-one"; onTriggered: canvas.addText(ctx.world.x, ctx.world.y, "title") }
        MenuRow { text: "Add note here"; glyph: "note"; onTriggered: canvas.addText(ctx.world.x, ctx.world.y, "note") }
        MenuRow { text: "Add text here"; glyph: "text-t"; onTriggered: canvas.addText(ctx.world.x, ctx.world.y, "text") }
        MenuDivider {}
        MenuRow { text: "Dots"; checkable: true; checked: board.background === "dots"; glyph: "dots-nine"; onTriggered: board.background = "dots" }
        MenuRow { text: "Lines"; checkable: true; checked: board.background === "lines"; glyph: "grid-four"; onTriggered: board.background = "lines" }
        MenuRow { text: "Cross"; checkable: true; checked: board.background === "cross"; glyph: "plus"; onTriggered: board.background = "cross" }
        MenuRow { text: "No pattern"; checkable: true; checked: board.background === "none"; glyph: "square"; onTriggered: board.background = "none" }
    }

    // ── Floating pieces ──────────────────────────────────────────────────
    Sidebar {
        id: sidebar
        z: 10
        blurSource: cv
        width: 264
        x: app.sidebarOpen ? 12 : -width - 24
        y: titleBar.height + 12
        height: parent.height - y - 12
        Behavior on x { NumberAnimation { duration: Theme.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveLayout } }
        onSettingsClicked: settings.open()
    }
    Toolbar {
        id: toolbar
        view: cv
        room: parent.width - Cam.insetLeft - 24
        x: Cam.insetLeft + 12 + Math.max(0, (room - width) / 2)
        anchors.bottom: parent.bottom; anchors.bottomMargin: 16
        onExportClicked: exportDialog.open()
    }
    Minimap {
        id: minimap
        visible: app.minimap && board.count > 0 && ws.width >= 1180
        anchors.right: parent.right; anchors.rightMargin: 16
        anchors.bottom: parent.bottom; anchors.bottomMargin: 16
    }
    // Round toggle on the sidebar's edge, vertically centred; it rides along with the panel (as Studio's inspector does)
    Rectangle {
        id: sideToggle
        z: 11
        width: 40; height: 40; radius: 20
        x: Math.max(16, sidebar.x + sidebar.width + 12)
        y: titleBar.height + (parent.height - titleBar.height - height) / 2
        color: sideHover.hovered ? Theme.elevated : Theme.alpha(Theme.surface, 0.9)
        border.color: Theme.hairlineStrong
        Icon {
            anchors.centerIn: parent
            name: "caret-left"; weight: "bold"; size: 13
            color: sideHover.hovered ? Theme.text : Theme.textDim
            rotation: app.sidebarOpen ? 0 : 180
            Behavior on rotation { NumberAnimation { duration: Theme.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveLayout } }
        }
        HoverHandler { id: sideHover; cursorShape: Qt.PointingHandCursor }
        MouseArea { anchors.fill: parent; onClicked: app.sidebarOpen = !app.sidebarOpen }
    }
    StylePanel {
        id: stylePanel
        visible: ws.styleOpen && board.selectedCount === 1
        x: parent.width - width - 16
        y: titleBar.height + 16
        onClosed: ws.styleOpen = false
    }

    // ── Title bar ────────────────────────────────────────────────────────
    Rectangle {
        id: titleBar
        width: parent.width; height: 52
        color: Theme.bg
        z: 20
        Hairline { anchors.bottom: parent.bottom; property bool dragThrough: true }

        Row {
            property bool dragThrough: true
            anchors.centerIn: parent
            spacing: 10
            Txt { text: board.boardName; variant: "strong"; font.pixelSize: 14; elide: Text.ElideRight; width: Math.min(implicitWidth, 360); anchors.verticalCenter: parent.verticalCenter }
            Txt { text: board.count + (board.count === 1 ? " item" : " items"); variant: "caption"; muted: true; anchors.verticalCenter: parent.verticalCenter }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: Theme.s16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Btn {
                visible: app.updateAvailable
                kind: "primary"; size: "s"
                text: app.updating ? "Updating" : "Update v" + app.updateVersion
                busy: app.updating
                anchors.verticalCenter: parent.verticalCenter
                onClicked: app.installUpdate()
            }
            Rectangle {
                width: paletteRow.implicitWidth + 56; height: 28
                radius: Theme.rControl
                color: palHover.hovered ? Theme.elevated : Theme.raised
                border.color: palHover.hovered ? Theme.hairlineStrong : Theme.hairline
                anchors.verticalCenter: parent.verticalCenter
                Row {
                    id: paletteRow
                    anchors.centerIn: parent
                    spacing: 8
                    Icon { name: "magnifying-glass"; size: 14; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                    Txt { text: "Search"; variant: "small"; dim: true; anchors.verticalCenter: parent.verticalCenter }
                    Txt { text: "⌘K"; variant: "mono"; muted: true; anchors.verticalCenter: parent.verticalCenter }
                }
                HoverHandler { id: palHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: ws.openPalette() }
            }
        }
    }

    Lightbox { id: lightbox; anchors.fill: parent; z: 40 }
    CommandPalette {
        id: palette
        anchors.fill: parent; z: 50
        commands: ws.commands
        extra: q => board.search(q).map(r => ({ title: r.title, group: "On this board", icon: ws.iconFor(r.type), run: () => { board.selectIds([r.id]); cv.fitSelection() } }))
    }
    SettingsDialog { id: settings }
    ExportDialog { id: exportDialog }
    ToastHost { id: toasts; anchors.fill: parent; anchors.bottomMargin: 84; z: 60 }
}
