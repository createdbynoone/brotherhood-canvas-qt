import QtQuick

// An image (or any texture provider, e.g. a video output) drawn through one shader that rounds the corners and
// crops to cover. No offscreen layer and no mask item: the cost is a single draw call per picture.
Item {
    id: root
    property url source
    property real radius: 12
    property real aa: 1                    // one screen pixel in this item's units
    property real dim: 0
    property bool cover: true
    property Item external: null          // use this item's texture instead of the image
    property real externalAspect: 1
    readonly property int status: img.status
    readonly property real aspect: external ? externalAspect : (img.implicitWidth > 0 && img.implicitHeight > 0 ? img.implicitWidth / img.implicitHeight : 1)

    Image {
        id: img
        visible: false
        source: root.external ? "" : root.source
        asynchronous: true
        mipmap: true
        smooth: true
        retainWhileLoading: true
        fillMode: Image.Stretch
        cache: true
    }
    ShaderEffect {
        anchors.fill: parent
        visible: root.external !== null || img.status === Image.Ready
        property variant source: root.external ? root.external : img
        property vector2d size: Qt.vector2d(Math.max(1, width), Math.max(1, height))
        property real radius: Math.min(root.radius, Math.min(width, height) / 2)
        property real aa: root.aa
        property real aspect: root.aspect
        property real fit: root.cover ? 1 : 0
        property real dim: root.dim
        fragmentShader: "qrc:/shaders/rounded.frag.qsb"
    }
}
