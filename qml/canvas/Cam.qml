pragma Singleton
import QtQuick

// Shared camera and pointer state for the one open canvas. Node, edge and overlay items read it directly,
// so none of them needs a reference to the view that owns the input handling.
QtObject {
    property real zoom: 1
    property real panX: 0                 // where world (0,0) sits on screen, px
    property real panY: 0
    property real viewW: 800
    property real viewH: 600
    property real originX: 0              // where the canvas sits in the window (test driver, popups)
    property real originY: 0
    property real insetLeft: 0            // width covered by the floating sidebar
    property bool exporting: false        // true only inside the export scene (its own engine): no selection, hover or editing chrome
    property string tool: "select"        // select | pan
    property string hoverId: ""           // node under the pointer
    property string hoverKind: ""         // node | handle | resize | edge | none
    property string hoverSide: ""         // handle side under the pointer
    property string hoverEdgeId: ""
    property string playingId: ""         // the one video that is playing
    property int hoverHandle: -1          // resize grip under the pointer
    property bool connecting: false
    property string connectFrom: ""
    property string connectTarget: ""     // node the connection would land on
    signal focusRequested()
    signal editAccept()                        // the floating check button: keep what was typed
    signal editCancel()                        // the floating x button: drop it
    signal doubleClicked(real x, real y)       // canvas coordinates; the test driver raises it, real input comes from MouseArea

    // Culling uses a padded rectangle that is only recomputed when the view nears its edge, so a pan or zoom does not
    // re-evaluate the visibility binding of every node and edge on every event (that was the cost with 1000+ items).
    property real cullL: -1e9
    property real cullT: -1e9
    property real cullR: 1e9
    property real cullB: 1e9
    function updateCull() {
        const l = -panX / zoom, t = -panY / zoom, r = (viewW - panX) / zoom, b = (viewH - panY) / zoom
        const w = r - l, h = b - t
        if (l > cullL + 0.07 * w && t > cullT + 0.07 * h && r < cullR - 0.07 * w && b < cullB - 0.07 * h && (cullR - cullL) < w * 2.2) return
        cullL = l - 0.25 * w; cullT = t - 0.25 * h; cullR = r + 0.25 * w; cullB = b + 0.25 * h
        culled(cullL, cullT, cullR, cullB)
    }
    function resetCull() { cullL = 1e9; cullR = -1e9; updateCull() }
    signal culled(real l, real t, real r, real b)
    onPanXChanged: updateCull()
    onPanYChanged: updateCull()
    onZoomChanged: { updateCull(); const s = Math.round(Math.log(zoom) / Math.LN2 * 2) / 2; if (s !== zoomStep) zoomStep = s }
    onViewWChanged: updateCull()
    onViewHChanged: updateCull()
    // Zoom snapped to half-octaves: what only needs to know the rough scale (level of detail, picture size) binds to
    // this, so it re-evaluates a handful of times across a whole zoom gesture instead of on every wheel event.
    property real zoomStep: 0
    readonly property real zoomQ: Math.pow(2, zoomStep)
    function sx(wx) { return wx * zoom + panX }
    function sy(wy) { return wy * zoom + panY }
    function wx(sx) { return (sx - panX) / zoom }
    function wy(sy) { return (sy - panY) / zoom }
}
