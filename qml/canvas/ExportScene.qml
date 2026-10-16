import QtQuick

// The board as the app draws it, for export: the same NodeItem / EdgeItem / background shader, but laid out flat at one
// fixed scale and with nothing culled. It runs in its own QML engine (see SceneExport), so its Cam singleton is private:
// the live view is never moved, and selection, hover and editing chrome stay out of the picture.
Item {
    id: scene
    property rect box: Qt.rect(0, 0, 100, 100)     // world rectangle to draw
    property real s: 1                             // logical pixels per world unit
    property var only: []                          // node ids to draw (empty = all)
    property var onlyEdges: []                     // edge ids to draw when `only` is set
    property string pattern: "dots"
    readonly property bool filtered: only.length > 0

    width: Math.ceil(box.width * s); height: Math.ceil(box.height * s)

    Component.onCompleted: {
        Theme.reduceMotion = true
        Theme.brand = brandFamily
        Theme.marker = markerFamily
        Cam.exporting = true
        Cam.zoom = s
    }

    Rectangle { anchors.fill: parent; color: Theme.bg }
    ShaderEffect {
        anchors.fill: parent
        visible: scene.pattern !== "none"
        property vector2d size: Qt.vector2d(width, height)
        property vector2d offset: Qt.vector2d(-scene.box.x * scene.s, -scene.box.y * scene.s)
        property real zoom: scene.s
        property real kind: scene.pattern === "dots" ? 1 : scene.pattern === "lines" ? 2 : scene.pattern === "cross" ? 3 : 0
        property color color: Theme.alpha(Theme.text, scene.pattern === "dots" ? 0.20 : scene.pattern === "cross" ? 0.22 : 0.07)
        fragmentShader: "qrc:/shaders/pattern.frag.qsb"
    }

    Item {
        x: -scene.box.x * scene.s; y: -scene.box.y * scene.s
        scale: scene.s
        transformOrigin: Item.TopLeft
        Repeater {
            model: board.edges
            delegate: EdgeItem { visible: !scene.filtered || scene.onlyEdges.indexOf(edgeId) >= 0 }
        }
        Repeater {
            model: board
            delegate: NodeItem { visible: !scene.filtered || scene.only.indexOf(nodeId) >= 0 }
        }
    }
}
