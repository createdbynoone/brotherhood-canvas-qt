import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Shapes

// The infinite canvas. One pointer handler owns every gesture and asks the model what is under the cursor,
// so a few hundred passive node items stay cheap. Camera and hover state live in the Cam singleton.
FocusScope {
    id: view
    clip: true

    signal contextRequested(var info)             // { kind: node|edge|pane, id, sx, sy }
    signal previewRequested(string id)
    signal styleRequested()

    property bool dropping: false
    readonly property bool interacting: input.mode !== "" && input.moved && input.mode !== "edge"
    property real ptrX: width / 2                  // last pointer position, for paste
    property real ptrY: height / 2
    property bool spaceDown: false

    onWidthChanged: { Cam.viewW = width; syncOrigin() }
    onHeightChanged: { Cam.viewH = height; syncOrigin() }
    onYChanged: syncOrigin()
    function syncOrigin() { const p = mapToItem(null, 0, 0); Cam.originX = p.x; Cam.originY = p.y }

    // ── Camera ───────────────────────────────────────────────────────────
    function clampZoom(z) { return Math.max(0.05, Math.min(4, z)) }
    function commitCamera() { commit.restart() }
    Timer { id: commit; interval: 200; onTriggered: board.setViewport(Cam.panX, Cam.panY, Cam.zoom) }

    function zoomAt(sx, sy, factor) {
        camAnim.stop()
        const nz = clampZoom(Cam.zoom * factor), k = nz / Cam.zoom
        Cam.panX = sx - (sx - Cam.panX) * k
        Cam.panY = sy - (sy - Cam.panY) * k
        Cam.zoom = nz
        commitCamera()
    }
    function panBy(dx, dy) { camAnim.stop(); Cam.panX += dx; Cam.panY += dy; commitCamera() }
    function visibleCenter() { return Qt.point(Cam.insetLeft + (width - Cam.insetLeft) / 2, height / 2) }
    function zoomStep(f) { const c = visibleCenter(); zoomAt(c.x, c.y, f) }
    function animateTo(px, py, z) {
        if (Theme.reduceMotion) { Cam.panX = px; Cam.panY = py; Cam.zoom = z; commitCamera(); return }
        camAnim.stop()
        aX.to = px; aY.to = py; aZ.to = z
        camAnim.start()
    }
    ParallelAnimation {
        id: camAnim
        onFinished: view.commitCamera()
        NumberAnimation { id: aX; target: Cam; property: "panX"; duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve }
        NumberAnimation { id: aY; target: Cam; property: "panY"; duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve }
        NumberAnimation { id: aZ; target: Cam; property: "zoom"; duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve }
    }
    function fitRect(r, maxZoom) {
        if (!r || (r.width <= 0 && r.height <= 0)) return
        const left = Cam.insetLeft + 48, top = 56, right = 48, bottom = 96
        const aw = Math.max(80, width - left - right), ah = Math.max(80, height - top - bottom)
        const z = clampZoom(Math.min(aw / Math.max(r.width, 1), ah / Math.max(r.height, 1), maxZoom === undefined ? 1.25 : maxZoom))
        animateTo(left + aw / 2 - (r.x + r.width / 2) * z, top + ah / 2 - (r.y + r.height / 2) * z, z)
    }
    function fitAll() { if (board.count > 0) fitRect(board.bounds) }
    function fitSelection() { if (board.selectedCount > 0) fitRect(board.selectionBounds, 1.6) }
    function resetZoom() { zoomStep(1 / Cam.zoom) }
    function centerWorld() { const c = visibleCenter(); return Qt.point(Cam.wx(c.x), Cam.wy(c.y)) }
    function revealRect(r) {   // bring freshly added content into view without zooming
        const sx0 = Cam.sx(r.x), sy0 = Cam.sy(r.y), sx1 = Cam.sx(r.x + r.width), sy1 = Cam.sy(r.y + r.height)
        const l = Cam.insetLeft + 24
        if (sx0 >= l && sy0 >= 56 && sx1 <= width - 24 && sy1 <= height - 100) return
        fitRect(r, Math.max(Cam.zoom, 0.6))
    }
    function applyViewport() {
        camAnim.stop()
        if (board.count === 0 && board.vx === 0 && board.vy === 0 && board.zoom === 1) {
            Cam.zoom = 1; Cam.panX = Cam.insetLeft + (width - Cam.insetLeft) / 2; Cam.panY = height / 2
        } else { Cam.zoom = board.zoom; Cam.panX = board.vx; Cam.panY = board.vy }
        Cam.hoverId = ""; Cam.hoverKind = ""; Cam.hoverEdgeId = ""; Cam.playingId = ""
        Cam.resetCull()
    }
    Connections { target: board; function onViewportLoaded() { Qt.callLater(view.applyViewport) } }
    Connections { target: Cam; function onFocusRequested() { view.forceActiveFocus() } function onCulled(l, t, r, b) { board.setCull(l, t, r, b) } }
    Connections { target: canvas; function onPlaced(r) { view.revealRect(r) } }
    Component.onCompleted: { Cam.viewW = width; Cam.viewH = height; syncOrigin(); Qt.callLater(applyViewport); forceActiveFocus() }

    // ── Background pattern (GPU) ─────────────────────────────────────────
    ShaderEffect {
        anchors.fill: parent
        property vector2d size: Qt.vector2d(width, height)
        property vector2d offset: Qt.vector2d(Cam.panX, Cam.panY)
        property real zoom: Cam.zoom
        property real kind: board.background === "dots" ? 1 : board.background === "lines" ? 2 : board.background === "cross" ? 3 : 0
        property color color: Theme.alpha(Theme.text, board.background === "dots" ? 0.20 : board.background === "cross" ? 0.22 : 0.07)
        fragmentShader: "qrc:/shaders/pattern.frag.qsb"
    }

    // ── World ────────────────────────────────────────────────────────────
    Item {
        id: world
        x: Cam.panX; y: Cam.panY
        scale: Cam.zoom
        transformOrigin: Item.TopLeft

        Repeater { id: edgeRep; model: board.visibleEdges; delegate: EdgeItem {} }
        Repeater { id: nodeRep; model: board.visibleNodes; delegate: NodeItem {} }

        // Alignment guides
        Repeater {
            model: board.guides
            delegate: Rectangle {
                required property var modelData
                x: Math.min(modelData.x1, modelData.x2); y: Math.min(modelData.y1, modelData.y2)
                width: Math.max(Math.abs(modelData.x2 - modelData.x1), 1 / Cam.zoom)
                height: Math.max(Math.abs(modelData.y2 - modelData.y1), 1 / Cam.zoom)
                color: Theme.alpha(Theme.accent, 0.85)
                z: 100000
            }
        }
        // Connection being dragged
        Shape {
            visible: Cam.connecting
            z: 100001
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                id: pv
                readonly property var anchor: Cam.connecting ? board.handlePoint(input.connFrom, input.connSide) : Qt.point(0, 0)
                readonly property var c: Cam.connecting ? board.curveFor(anchor.x, anchor.y, input.connSide, input.connX, input.connY, "") : [0, 0, 0, 0]
                fillColor: "transparent"
                strokeColor: Theme.accent
                strokeWidth: 2
                capStyle: ShapePath.RoundCap
                strokeStyle: ShapePath.DashLine
                dashPattern: [3, 2]
                startX: anchor.x; startY: anchor.y
                PathCubic { x: input.connX; y: input.connY; control1X: pv.c[0]; control1Y: pv.c[1]; control2X: pv.c[2]; control2Y: pv.c[3] }
            }
        }
    }

    // ── Screen-space chrome ──────────────────────────────────────────────
    Rectangle {   // group selection bounds
        readonly property rect r: board.selectionBounds
        visible: board.selectedCount > 1 && !(input.mode === "marquee")
        x: Cam.sx(r.x) - 6; y: Cam.sy(r.y) - 6
        width: r.width * Cam.zoom + 12; height: r.height * Cam.zoom + 12
        radius: 8
        color: Theme.alpha(Theme.accent, 0.04)
        border.color: Theme.alpha(Theme.accent, 0.45)
    }
    Rectangle {   // marquee
        visible: input.mode === "marquee" && input.moved
        x: Math.min(input.px0, input.lastX); y: Math.min(input.py0, input.lastY)
        width: Math.abs(input.lastX - input.px0); height: Math.abs(input.lastY - input.py0)
        color: Theme.accentSoft
        border.color: Theme.alpha(Theme.accent, 0.7)
        radius: 4
    }

    // Empty board
    Column {
        visible: board.count === 0 && !view.dropping
        x: Cam.insetLeft + (parent.width - Cam.insetLeft - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        opacity: 0.9
        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "upload-simple"; size: 30; color: Theme.textMuted }
        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: "Drop images, videos, PDFs or text files here"; dim: true }
        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: "or press T for a title, N for a note, X for text"; variant: "small"; muted: true }
    }

    // Drop highlight
    Rectangle {
        visible: view.dropping
        anchors.fill: parent; anchors.margins: 10
        radius: Theme.rPanel
        color: Theme.alpha(Theme.accent, 0.05)
        border.color: Theme.alpha(Theme.accent, 0.8); border.width: 2
        Txt { anchors.centerIn: parent; text: "Drop to add to this board"; variant: "title"; color: Theme.accent }
        z: 5
    }

    ContextBar {
        id: ctxBar
        z: 6
        shown: board.selectedCount > 0 && !view.interacting && board.editingId === "" && !Cam.connecting
        onStyleClicked: view.styleRequested()
        onLabelClicked: { labelEditor.node = board.selectedId; const r = board.rectOf(board.selectedId); labelEditor.anchorX = Cam.sx(r.x + r.width / 2); labelEditor.anchorY = Cam.sy(r.y) - 52; labelEditor.open(board.nodeInfo(board.selectedId).label) }
    }
    EdgeBar {
        id: edgeBar
        z: 6
        shown: board.selectedEdge !== "" && !view.interacting
        onLabelClicked: view.editEdgeLabel(board.selectedEdge)
    }
    EditBar { z: 8 }
    InlineEditor {
        id: labelEditor
        z: 8
        property string node: ""
        placeholder: "Label"
        onCommitted: text => board.setNodeData(node, "label", text.trim().length > 0 ? text.trim() : null)
    }
    InlineEditor {
        id: edgeLabelEditor
        z: 8
        property string edge: ""
        placeholder: "Connection label"
        onCommitted: text => board.setEdgeProp(edge, "label", text.trim())
    }
    function editEdgeLabel(id) {
        const m = board.edgeMid(id)
        edgeLabelEditor.edge = id
        edgeLabelEditor.anchorX = Cam.sx(m.x); edgeLabelEditor.anchorY = Cam.sy(m.y) - 50
        edgeLabelEditor.open(board.edgeInfo(id).label)
    }
    function editNodeLabel(id) {
        const r = board.rectOf(id)
        labelEditor.node = id
        labelEditor.anchorX = Cam.sx(r.x + r.width / 2); labelEditor.anchorY = Cam.sy(r.y) - 52
        labelEditor.open(board.nodeInfo(id).label)
    }

    // ── Files dropped from Finder ────────────────────────────────────────
    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        onEntered: drag => { if (drag.hasUrls) view.dropping = true; else drag.accepted = false }
        onExited: view.dropping = false
        onDropped: drop => {
            view.dropping = false
            if (drop.hasUrls) { canvas.importUrls(drop.urls, Cam.wx(drop.x), Cam.wy(drop.y)); drop.accept() }
        }
    }

    // ── Pointer ──────────────────────────────────────────────────────────
    function doubleClickAt(sx, sy) {
        const h = board.hit(Cam.wx(sx), Cam.wy(sy), Cam.zoom)
        if (h.kind === "node") {
            if (h.type === "image" || h.type === "video") { Cam.playingId = ""; view.previewRequested(h.id) }
            else if (h.type === "pdf" || h.type === "file") canvas.openNodeFile(h.id)
            else { board.selectOnly(h.id); board.editingId = h.id }
        } else if (h.kind === "edge") view.editEdgeLabel(h.id)
    }
    Connections { target: Cam; function onDoubleClicked(x, y) { view.doubleClickAt(x, y) } }
    function cutEdgeAt(sx, sy) {
        for (const id of [board.selectedEdge, Cam.hoverEdgeId]) {
            if (id === "") continue
            const m = board.edgeMid(id)
            if (Math.hypot(Cam.sx(m.x) - sx, Cam.sy(m.y) - sy) <= 13) return id
        }
        return ""
    }
    function updateHover(sx, sy) {
        const ce = cutEdgeAt(sx, sy)
        if (ce !== "") { Cam.hoverKind = "cut"; Cam.hoverEdgeId = ce; Cam.hoverId = ""; Cam.hoverSide = ""; return }
        const h = board.hit(Cam.wx(sx), Cam.wy(sy), Cam.zoom)
        Cam.hoverKind = h.kind
        Cam.hoverId = (h.kind === "node" || h.kind === "handle" || h.kind === "resize") ? h.id : ""
        Cam.hoverSide = h.side ? h.side : ""
        Cam.hoverEdgeId = h.kind === "edge" ? h.id : ""
        Cam.hoverHandle = h.kind === "resize" ? h.handle : -1
    }
    function resizeCursor(i) {
        return (i === 0 || i === 4) ? Qt.SizeFDiagCursor : (i === 2 || i === 6) ? Qt.SizeBDiagCursor : (i === 1 || i === 5) ? Qt.SizeVerCursor : Qt.SizeHorCursor
    }

    MouseArea {
        id: input
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        preventStealing: true
        cursorShape: {
            if (mode === "pan" || mode === "rpan") return moved ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            if (mode === "move" && moved) return Qt.ClosedHandCursor
            if (Cam.tool === "pan" || view.spaceDown) return Qt.OpenHandCursor
            if (mode === "connect") return Qt.CrossCursor
            switch (Cam.hoverKind) {
            case "handle": return Qt.CrossCursor
            case "resize": return view.resizeCursor(Cam.hoverHandle)
            case "edge": case "cut": return Qt.PointingHandCursor
            case "node": return Qt.ArrowCursor
            default: return Qt.ArrowCursor
            }
        }

        property string mode: ""
        property bool moved: false
        property real px0: 0
        property real py0: 0
        property real lastX: 0
        property real lastY: 0
        property var pressHit: ({ kind: "none" })
        property string toggleOnRelease: ""
        property string collapseOnRelease: ""
        property string connFrom: ""
        property string connSide: ""
        property real connX: 0
        property real connY: 0

        onPressed: m => {
            camAnim.stop()
            view.forceActiveFocus()
            px0 = m.x; py0 = m.y; lastX = m.x; lastY = m.y; moved = false; toggleOnRelease = ""; collapseOnRelease = ""
            const wx = Cam.wx(m.x), wy = Cam.wy(m.y)
            if (board.editingId !== "") {      // a click inside the node being edited belongs to its text editor
                const r = board.rectOf(board.editingId)
                if (wx >= r.x && wx <= r.x + r.width && wy >= r.y && wy <= r.y + r.height) { m.accepted = false; return }
            }
            if (m.button === Qt.MiddleButton || (m.button === Qt.LeftButton && (Cam.tool === "pan" || view.spaceDown))) { mode = "pan"; return }
            if (m.button === Qt.RightButton) {
                pressHit = board.hit(wx, wy, Cam.zoom)
                if (pressHit.kind === "node" || pressHit.kind === "handle") { pressHit = { kind: "node", id: pressHit.id }; if (!board.isSelected(pressHit.id)) board.selectOnly(pressHit.id) }
                else if (pressHit.kind === "edge") board.selectEdge(pressHit.id)
                mode = "rpan"
                return
            }
            const shift = (m.modifiers & Qt.ShiftModifier) !== 0, meta = (m.modifiers & Qt.ControlModifier) !== 0
            const cut = view.cutEdgeAt(m.x, m.y)
            if (cut !== "") { board.deleteEdge(cut); view.updateHover(m.x, m.y); mode = "done"; return }
            const h = board.hit(wx, wy, Cam.zoom)
            pressHit = h
            if (h.kind === "resize") { board.beginResize(h.id, h.handle); mode = "resize" }
            else if (h.kind === "handle") {
                if (!board.isSelected(h.id)) board.selectOnly(h.id)
                connFrom = h.id; connSide = h.side; connX = wx; connY = wy
                Cam.connectFrom = h.id; Cam.connectTarget = ""; Cam.connecting = true
                mode = "connect"
            } else if (h.kind === "node") {
                if (shift || meta) { if (!board.isSelected(h.id)) board.toggleSelected(h.id); else toggleOnRelease = h.id }
                else if (!board.isSelected(h.id)) board.selectOnly(h.id)
                else if (board.selectedCount > 1) collapseOnRelease = h.id
                board.beginMove(h.id)
                mode = "move"
            } else if (h.kind === "edge") { board.selectEdge(h.id); mode = "edge" }
            else {
                if (!shift) board.clearSelection()
                board.beginMarquee(shift)
                mode = "marquee"
            }
        }

        onPositionChanged: m => {
            view.ptrX = m.x; view.ptrY = m.y
            if (!pressed) { view.updateHover(m.x, m.y); return }
            if (mode === "" || mode === "done") return
            const dx = m.x - px0, dy = m.y - py0
            if (mode === "pan" || mode === "rpan") {
                if (!moved && Math.hypot(dx, dy) < 4) return
                moved = true
                view.panBy(m.x - lastX, m.y - lastY)
                lastX = m.x; lastY = m.y
                return
            }
            if (!moved && Math.hypot(dx, dy) < 3) return
            moved = true
            const wx = Cam.wx(m.x), wy = Cam.wy(m.y)
            if (mode === "move") board.moveBy(dx / Cam.zoom, dy / Cam.zoom, Cam.zoom, (m.modifiers & Qt.AltModifier) === 0)
            else if (mode === "resize") board.resizeBy(dx / Cam.zoom, dy / Cam.zoom, (m.modifiers & Qt.ShiftModifier) !== 0)
            else if (mode === "marquee") board.marquee(Cam.wx(px0), Cam.wy(py0), wx, wy)
            else if (mode === "connect") {
                connX = wx; connY = wy
                const h = board.hit(wx, wy, Cam.zoom)
                Cam.connectTarget = (h.kind === "handle" || h.kind === "node") && h.id !== connFrom ? h.id : ""
            }
            lastX = m.x; lastY = m.y
        }

        onReleased: m => {
            const wasMode = mode, wasMoved = moved
            mode = ""
            if (wasMode === "move") {
                board.endMove()
                if (!wasMoved) {
                    if (toggleOnRelease !== "") board.toggleSelected(toggleOnRelease)
                    else if (collapseOnRelease !== "") board.selectOnly(collapseOnRelease)
                    else if (pressHit.type === "video" && !(m.modifiers & (Qt.ShiftModifier | Qt.ControlModifier))) {
                        const it = nodeRep.itemAt(board.visibleNodes.rowOf(pressHit.id))
                        if (it) it.primaryAction()
                    }
                }
            } else if (wasMode === "resize") board.endResize()
            else if (wasMode === "connect") {
                const wx = Cam.wx(m.x), wy = Cam.wy(m.y)
                const h = board.hit(wx, wy, Cam.zoom)
                if (wasMoved && h.id !== connFrom) {
                    if (h.kind === "handle") board.connectNodes(connFrom, connSide, h.id, h.side)
                    else if (h.kind === "node") board.connectToNode(connFrom, connSide, h.id, wx, wy)
                }
                Cam.connecting = false; Cam.connectTarget = ""
            } else if (wasMode === "rpan" && !wasMoved) {
                view.contextRequested({ kind: pressHit.kind === "node" ? "node" : pressHit.kind === "edge" ? "edge" : "pane", id: pressHit.id ? pressHit.id : "", sx: m.x, sy: m.y })
            }
            view.updateHover(m.x, m.y)
        }
        onCanceled: { mode = ""; Cam.connecting = false; board.endMove(); board.endResize() }
        onExited: { if (!pressed) { Cam.hoverId = ""; Cam.hoverKind = ""; Cam.hoverEdgeId = "" } }

        onDoubleClicked: m => { if (m.button === Qt.LeftButton) view.doubleClickAt(m.x, m.y) }

        // Scroll pans, Cmd/Ctrl+scroll and pinch zoom. A two-finger scroll on a trackpad also emits tiny
        // magnify events, so scrolling stamps `lastScrollMs` and the pinch handler ignores that window.
        onWheel: w => {
            view.lastScrollMs = Date.now()
            if (Date.now() - view.lastPinchMs < 160) { w.accepted = true; return }   // pinch tail: no stray pan
            if ((w.modifiers & Qt.ControlModifier) || (w.modifiers & Qt.MetaModifier)) {
                const d = w.pixelDelta.y !== 0 ? w.pixelDelta.y * 0.012 : w.angleDelta.y * 0.0016
                view.zoomAt(w.x, w.y, Math.exp(Math.max(-0.25, Math.min(0.25, d))))
            } else if (w.pixelDelta.x !== 0 || w.pixelDelta.y !== 0) view.panBy(w.pixelDelta.x, w.pixelDelta.y)
            else view.panBy(w.angleDelta.x / 2, w.angleDelta.y / 2)
            w.accepted = true
        }
    }

    property var floating: []                // panels drawn over the board (set by Workspace)
    property bool blocked: false             // set while the lightbox is open
    property real lastScrollMs: 0
    property real lastPinchMs: 0
    // Pinch arrives from AppKit as magnification deltas (see Mac::installMagnify). It only counts when it is a
    // deliberate gesture: not part of a scroll, not while a button is down, and past a small dead zone.
    property real pinchSum: 0
    property bool pinchOn: false
    Connections {
        target: app
        function onMagnified(x, y, mag, phase) {
            if (view.blocked) return          // a viewer (lightbox) is open: the pinch belongs to it
            for (const it of view.floating.concat([ctxBar, edgeBar])) {      // pinching over a floating panel is not for the board
                if (!it || !it.visible) continue
                const q = it.mapFromItem(null, x, y)
                if (q.x >= 0 && q.y >= 0 && q.x <= it.width && q.y <= it.height) return
            }
            if (phase & 1) { view.pinchSum = 0; view.pinchOn = false }
            if ((phase & 24) && !(phase & 6)) { view.pinchOn = false; view.pinchSum = 0; return }
            if (input.pressed || (!view.pinchOn && Date.now() - view.lastScrollMs < 200)) return
            if (!view.pinchOn) {
                view.pinchSum += mag
                if (Math.abs(view.pinchSum) < 0.04) return
                view.pinchOn = true; mag = view.pinchSum
            }
            view.lastPinchMs = Date.now()
            const p = view.mapFromItem(null, x, y)
            view.zoomAt(p.x, p.y, Math.max(0.8, Math.min(1.25, 1 + mag)))
        }
    }

    // ── Keyboard ─────────────────────────────────────────────────────────
    Keys.onReleased: e => { if (e.key === Qt.Key_Space && !e.isAutoRepeat) { spaceDown = false; e.accepted = true } }
    Keys.onPressed: e => {
        const cmd = (e.modifiers & Qt.ControlModifier) !== 0, shift = (e.modifiers & Qt.ShiftModifier) !== 0
        const k = e.key
        e.accepted = true
        if (k === Qt.Key_Space) { if (!e.isAutoRepeat) spaceDown = true; return }
        if (k === Qt.Key_Delete || k === Qt.Key_Backspace) { board.deleteSelected(); return }
        if (k === Qt.Key_Escape) {
            if (Cam.connecting) { input.mode = ""; Cam.connecting = false } else if (Cam.tool !== "select") Cam.tool = "select"; else board.clearSelection()
            return
        }
        if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            const t = board.selectedType
            if (board.selectedCount === 1 && (t === "text" || t === "note" || t === "title")) board.editingId = board.selectedId
            else if (board.selectedEdge !== "") view.editEdgeLabel(board.selectedEdge)
            else e.accepted = false
            return
        }
        if (cmd) {
            switch (k) {
            case Qt.Key_A: board.selectAll(); return
            case Qt.Key_C: canvas.copySelection(); return
            case Qt.Key_X: canvas.cutSelection(); return
            case Qt.Key_V: canvas.paste(Cam.wx(ptrX), Cam.wy(ptrY)); return
            case Qt.Key_D: board.duplicateSelected(); return
            case Qt.Key_Z: if (shift) board.redo(); else board.undo(); return
            case Qt.Key_BracketRight: board.bringToFront(); return
            case Qt.Key_BracketLeft: board.sendToBack(); return
            case Qt.Key_0: view.resetZoom(); return
            case Qt.Key_Plus: case Qt.Key_Equal: view.zoomStep(1.25); return
            case Qt.Key_Minus: view.zoomStep(0.8); return
            case Qt.Key_L: board.setLocked(!board.hasSelectionLocked); return
            default: e.accepted = false; return
            }
        }
        if (k === Qt.Key_Left || k === Qt.Key_Right || k === Qt.Key_Up || k === Qt.Key_Down) {
            if (board.selectedCount === 0) { e.accepted = false; return }
            const step = shift ? 10 : 1
            const dx = k === Qt.Key_Left ? -step : k === Qt.Key_Right ? step : 0, dy = k === Qt.Key_Up ? -step : k === Qt.Key_Down ? step : 0
            board.beginMove(board.selectedIds()[0]); board.moveBy(dx, dy, Cam.zoom, false); board.endMove()
            return
        }
        const c = view.centerWorld()
        switch (k) {
        case Qt.Key_F: if (shift) view.fitSelection(); else view.fitAll(); break
        case Qt.Key_H: Cam.tool = "pan"; break
        case Qt.Key_V: Cam.tool = "select"; break
        case Qt.Key_T: canvas.addText(c.x, c.y, "title"); break
        case Qt.Key_N: canvas.addText(c.x, c.y, "note"); break
        case Qt.Key_X: canvas.addText(c.x, c.y, "text"); break
        case Qt.Key_Plus: case Qt.Key_Equal: view.zoomStep(1.25); break
        case Qt.Key_Minus: view.zoomStep(0.8); break
        default: e.accepted = false
        }
    }
}
