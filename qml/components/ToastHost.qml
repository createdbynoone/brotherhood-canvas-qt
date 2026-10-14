import QtQuick

// Transient feedback: a toast confirms an action that finished somewhere else (a file saved, an
// export done). Errors stay a little longer. kind: 0 info, 1 ok, 2 error.
Item {
    id: root
    function show(message, kind) { toasts.append({ message: message, kind: kind === undefined ? 0 : kind }) }

    ListView {
        id: view
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: 420
        height: Math.min(contentHeight, 240)
        interactive: false
        spacing: 8
        verticalLayoutDirection: ListView.BottomToTop
        model: ListModel { id: toasts }

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.base }
                NumberAnimation { property: "y"; from: view.height + 12; duration: Theme.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve }
            }
        }
        remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.base } }
        displaced: Transition { NumberAnimation { property: "y"; duration: Theme.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }

        delegate: Item {
            id: item
            required property string message
            required property int kind
            required property int index
            width: view.width
            height: 40

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                height: 40
                width: Math.min(row.implicitWidth + 28, parent.width)
                radius: Theme.rCard
                color: Theme.elevated
                border.color: Theme.hairlineStrong
                Row {
                    id: row
                    anchors.centerIn: parent
                    spacing: 9
                    Icon {
                        name: item.kind === 1 ? "check-circle" : item.kind === 2 ? "warning-circle" : "info"
                        weight: "fill"; size: 16
                        color: item.kind === 1 ? Theme.ok : item.kind === 2 ? Theme.danger : Theme.textDim
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Txt { text: item.message; variant: "small"; elide: Text.ElideRight; width: Math.min(implicitWidth, 340); anchors.verticalCenter: parent.verticalCenter }
                }
            }
            Timer { interval: item.kind === 2 ? 5200 : 3200; running: true; onTriggered: toasts.remove(item.index) }
        }
    }
}
