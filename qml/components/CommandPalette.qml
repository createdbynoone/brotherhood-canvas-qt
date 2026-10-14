import QtQuick

// ⌘K: every action in the app, searchable. commands: [{ title, group, hint, icon, run }]
Item {
    id: root
    property bool open: false
    property var commands: []
    property string query: ""
    property var extra: function(q) { return [] }          // commands that depend on what was typed (node search)
    property var results: {
        const q = query.trim().toLowerCase()
        if (q.length === 0) return commands
        return commands.filter(c => {
            const t = (c.title + " " + (c.group || "")).toLowerCase()
            let i = 0
            for (const ch of q) { i = t.indexOf(ch, i); if (i < 0) return false; i++ }   // subsequence match
            return true
        }).concat(q.length >= 2 ? extra(query.trim()) : [])
    }

    visible: opacity > 0.001
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }

    function show() { query = ""; field.text = ""; list.currentIndex = 0; open = true; field.forceFocus() }
    function hide() { open = false }
    function runCurrent() {
        if (list.currentIndex < 0 || list.currentIndex >= results.length) return
        const c = results[list.currentIndex]
        hide()
        Qt.callLater(c.run)
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        TapHandler { onTapped: root.hide() }
    }

    Rectangle {
        id: panel
        width: 560
        height: Math.min(field.height + 1 + Math.max(list.contentHeight, 56) + 8, 420)
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.open ? parent.height * 0.16 : parent.height * 0.16 + 10
        Behavior on y { NumberAnimation { duration: Theme.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
        radius: Theme.rPanel
        color: Theme.surface
        border.color: Theme.hairlineStrong
        clip: true

        Field {
            id: field
            x: 10; y: 10
            width: parent.width - 20
            implicitHeight: 40
            icon: "magnifying-glass"
            placeholder: "Search actions"
            onEdited: { root.query = text; list.currentIndex = 0 }
            onAccepted: root.runCurrent()
            inputItem.Keys.onPressed: event => {
                if (event.key === Qt.Key_Down) { list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1); event.accepted = true }
                else if (event.key === Qt.Key_Up) { list.currentIndex = Math.max(0, list.currentIndex - 1); event.accepted = true }
                else if (event.key === Qt.Key_Escape) { root.hide(); event.accepted = true }
            }
        }
        Hairline { y: field.y + field.height + 9 }
        ListView {
            id: list
            y: field.y + field.height + 10
            width: parent.width
            height: parent.height - y - 4
            model: root.results
            currentIndex: 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            delegate: Item {
                required property var modelData
                required property int index
                width: list.width
                height: 38
                Rectangle {
                    anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
                    radius: Theme.rControl
                    color: ListView.isCurrentItem || rowHover.hovered ? Theme.elevated : "transparent"
                }
                Row {
                    anchors.left: parent.left; anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    Icon { name: modelData.icon || "lightning"; size: 16; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                    Txt { text: modelData.title; variant: "strong"; anchors.verticalCenter: parent.verticalCenter }
                    Txt { text: modelData.group || ""; variant: "caption"; muted: true; anchors.verticalCenter: parent.verticalCenter }
                }
                Txt {
                    anchors.right: parent.right; anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.hint || ""; variant: "mono"; muted: true
                }
                HoverHandler { id: rowHover; onHoveredChanged: if (hovered) list.currentIndex = index }
                TapHandler { onTapped: { list.currentIndex = index; root.runCurrent() } }
            }
            Txt {
                visible: list.count === 0
                anchors.centerIn: parent
                text: "No matching action"
                dim: true
            }
        }
    }
}
