import QtQuick

// Overview of the whole board. Click or drag to move the camera.
Rectangle {
    id: root
    width: 188; height: 124
    radius: Theme.rCard
    color: Theme.alpha(Theme.surface, 0.94)
    border.color: Theme.hairlineStrong
    clip: true

    // World rectangle shown by the map: every node plus whatever the camera currently sees
    readonly property rect nodesBox: board.bounds
    readonly property real vx0: -Cam.panX / Cam.zoom
    readonly property real vy0: -Cam.panY / Cam.zoom
    readonly property real vw: Cam.viewW / Cam.zoom
    readonly property real vh: Cam.viewH / Cam.zoom
    readonly property real minX: Math.min(vx0, nodesBox.width > 0 ? nodesBox.x : vx0) - 40
    readonly property real minY: Math.min(vy0, nodesBox.height > 0 ? nodesBox.y : vy0) - 40
    readonly property real maxX: Math.max(vx0 + vw, nodesBox.width > 0 ? nodesBox.x + nodesBox.width : vx0 + vw) + 40
    readonly property real maxY: Math.max(vy0 + vh, nodesBox.height > 0 ? nodesBox.y + nodesBox.height : vy0 + vh) + 40
    readonly property real k: Math.min((width - 16) / (maxX - minX), (height - 16) / (maxY - minY))
    readonly property real ox: (width - (maxX - minX) * k) / 2
    readonly property real oy: (height - (maxY - minY) * k) / 2

    Repeater {
        model: board
        delegate: Rectangle {
            required property real posX
            required property real posY
            required property real boxW
            required property real boxH
            required property bool selected
            required property string nodeType
            x: root.ox + (posX - root.minX) * root.k
            y: root.oy + (posY - root.minY) * root.k
            width: Math.max(2, boxW * root.k); height: Math.max(2, boxH * root.k)
            radius: 1.5
            visible: nodeType !== "title" || width > 3
            color: selected ? Theme.accent : Theme.alpha(Theme.text, nodeType === "title" ? 0.28 : 0.42)
        }
    }
    Rectangle {   // the camera
        x: root.ox + (root.vx0 - root.minX) * root.k
        y: root.oy + (root.vy0 - root.minY) * root.k
        width: root.vw * root.k; height: root.vh * root.k
        radius: 3
        color: Theme.alpha(Theme.accent, 0.06)
        border.color: Theme.alpha(Theme.accent, 0.8)
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        function go(m) {
            const wx = root.minX + (m.x - root.ox) / root.k, wy = root.minY + (m.y - root.oy) / root.k
            const c = Qt.point(Cam.insetLeft + (Cam.viewW - Cam.insetLeft) / 2, Cam.viewH / 2)
            Cam.panX = c.x - wx * Cam.zoom; Cam.panY = c.y - wy * Cam.zoom
            board.setViewport(Cam.panX, Cam.panY, Cam.zoom)
        }
        onPressed: m => go(m)
        onPositionChanged: m => { if (pressed) go(m) }
        onWheel: w => w.accepted = true
        cursorShape: Qt.PointingHandCursor
    }
}
