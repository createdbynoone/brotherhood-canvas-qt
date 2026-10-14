import QtQuick

// Single-line input. Label lives outside (above); placeholder never replaces a label.
Rectangle {
    id: root
    property alias text: input.text
    property string placeholder: ""
    property string icon: ""
    property bool secret: false
    property bool mono: false
    property alias inputItem: input
    property bool error: false
    property bool clearable: false
    signal accepted()
    signal edited()

    implicitHeight: 32
    implicitWidth: 200
    radius: Theme.rControl
    color: Theme.alpha(Theme.bg, 0.7)
    border.color: error ? Theme.alpha(Theme.danger, 0.7) : input.activeFocus ? Theme.alpha(Theme.accent, 0.7) : hover.hovered ? Theme.hairlineStrong : Theme.hairline
    Behavior on border.color { ColorAnimation { duration: Theme.fast } }

    function forceFocus() { input.forceActiveFocus() }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 10; anchors.rightMargin: 8
        spacing: 7
        Icon { visible: root.icon.length > 0; name: root.icon; size: 14; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
        TextInput {
            id: input
            width: parent.width - (root.icon.length > 0 ? 21 : 0) - (clearBtn.visible ? 22 : 0)
            anchors.verticalCenter: parent.verticalCenter
            font.family: root.mono ? Theme.mono : Theme.sans
            font.pixelSize: 13
            color: Theme.text
            selectionColor: Theme.alpha(Theme.accent, 0.45)
            selectedTextColor: Theme.text
            echoMode: root.secret ? TextInput.Password : TextInput.Normal
            clip: true
            selectByMouse: true
            onAccepted: root.accepted()
            onTextEdited: root.edited()
            Txt {
                visible: input.text.length === 0 && !input.preeditText
                text: root.placeholder
                muted: true
                font.family: input.font.family
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Item {
            id: clearBtn
            visible: root.clearable && input.text.length > 0
            width: 14; height: 14
            anchors.verticalCenter: parent.verticalCenter
            Icon { anchors.centerIn: parent; name: "x-circle"; weight: "fill"; size: 14; color: Theme.textMuted }
            TapHandler { onTapped: { input.text = ""; root.edited() } }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }
    HoverHandler { id: hover }
}
