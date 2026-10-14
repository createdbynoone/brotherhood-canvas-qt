import QtQuick

// Pill segmented control with a sliding indicator. options: [{ key, label }].
Item {
    id: root
    property var options: []
    property var current
    property int height_: 28
    property int fontSize: 12
    property int hPad: 11
    property int gap: 0
    property int inset: 2
    property bool heading: false          // brand face, uppercase, no tracking (the mode switch)
    signal picked(var key)

    readonly property int currentIndex: {
        for (let i = 0; i < options.length; i++) if (options[i].key === current) return i
        return -1
    }
    implicitWidth: row.implicitWidth + inset * 2
    implicitHeight: height_

    Rectangle {
        anchors.fill: parent
        radius: Theme.rControl
        color: Theme.surface
        border.color: Theme.hairline
    }
    Rectangle {   // sliding indicator
        id: indicator
        readonly property Item item: root.currentIndex >= 0 ? rep.itemAt(root.currentIndex) : null
        visible: item !== null
        x: item ? item.x : inset
        y: root.inset
        width: item ? item.width : 0
        height: root.height_ - root.inset * 2
        radius: Math.max(4, Theme.rControl - 2)
        color: Theme.elevated
        border.color: Theme.hairlineStrong
        Behavior on x { NumberAnimation { duration: Math.round(Theme.slow * 0.8); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveLayout } }
        Behavior on width { NumberAnimation { duration: Math.round(Theme.slow * 0.8); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveLayout } }
    }
    Row {
        id: row
        x: 0; y: 0
        height: parent.height
        leftPadding: root.inset
        spacing: root.gap
        Repeater {
            id: rep
            model: root.options
            delegate: Item {
                required property var modelData
                required property int index
                readonly property bool on: index === root.currentIndex
                width: label.implicitWidth + root.hPad * 2
                height: root.height_ - root.inset * 2
                y: root.inset
                Txt {
                    id: label
                    anchors.centerIn: parent
                    text: modelData.label
                    font.pixelSize: root.fontSize
                    font.family: root.heading ? Theme.headingFamily : Theme.sans
                    font.weight: root.heading ? Theme.headingWeight : Font.Medium
                    font.capitalization: root.heading ? Font.AllUppercase : Font.MixedCase
                    font.letterSpacing: 0
                    color: parent.on ? Theme.text : (hover.hovered ? Theme.text : Theme.textDim)
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                }
                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.picked(modelData.key) }
            }
        }
    }
}
