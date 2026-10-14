import QtQuick

// Selection ring, connection handles, resize grips and the lock marker. Sized by 1/zoom so they keep their size on
// screen. Only instantiated for the selected, hovered or connection-target node, so the zoom never touches the rest.
Item {
    id: chrome
    property Item owner
    readonly property real inv: 1 / Cam.zoom
    anchors.fill: parent
    z: 5

    // Title: an outline only while selected or hovered
    Rectangle {
        visible: owner.isTitle && !owner.editing
        anchors.fill: parent
        radius: 6
        color: "transparent"
        border.width: chrome.inv * 1.5
        border.color: owner.selected ? Theme.alpha(Theme.accent, 0.5) : Theme.hairlineStrong
    }
    // Selection ring (outside the border)
    Rectangle {
        visible: owner.selected || owner.dropTarget
        anchors.fill: parent
        anchors.margins: -chrome.inv * 1.5
        radius: owner.radiusPx + chrome.inv * 1.5
        color: "transparent"
        border.width: chrome.inv * 2
        border.color: Theme.accent
        opacity: owner.dropTarget && !owner.selected ? 0.7 : 1
    }
    // Lock marker
    Rectangle {
        visible: owner.locked
        x: parent.width - width - chrome.inv * 8; y: chrome.inv * 8
        width: chrome.inv * 22; height: width; radius: width / 2
        color: Theme.alpha(Theme.bg, 0.8)
        Icon { anchors.centerIn: parent; name: "lock"; weight: "fill"; size: 12; color: Theme.textDim; scale: chrome.inv; transformOrigin: Item.Center }
    }
    // Connection handles: one centred on each side
    Repeater {
        model: owner.showHandles && !owner.tiny ? ["top", "right", "bottom", "left"] : []
        delegate: Rectangle {
            required property string modelData
            readonly property bool hot: Cam.hoverId === owner.nodeId && Cam.hoverKind === "handle" && Cam.hoverSide === modelData
            width: chrome.inv * (hot ? 16 : 12); height: width; radius: width / 2
            x: modelData === "left" ? -width / 2 : modelData === "right" ? owner.width - width / 2 : owner.width / 2 - width / 2
            y: modelData === "top" ? -height / 2 : modelData === "bottom" ? owner.height - height / 2 : owner.height / 2 - height / 2
            color: hot ? Theme.accent : Theme.bg
            border.width: chrome.inv * 2
            border.color: Theme.accent
        }
    }
    // Resize grips on the corners (the sides resize from the border line): single, unlocked selection only
    Repeater {
        model: owner.single && !owner.locked && !owner.editing && !owner.tiny ? [0, 2, 4, 6] : []
        delegate: Rectangle {
            required property int modelData
            readonly property int grip: modelData
            readonly property real s: chrome.inv * 9
            width: s; height: s; radius: s * 0.28
            color: Theme.accent
            border.width: chrome.inv * 1.5; border.color: Theme.bg
            x: (grip === 0 || grip === 6) ? -s / 2 : (grip === 2 || grip === 4) ? owner.width - s / 2 : owner.width / 2 - s / 2
            y: (grip === 0 || grip === 2) ? -s / 2 : (grip === 4 || grip === 6) ? owner.height - s / 2 : owner.height / 2 - s / 2
        }
    }
}
