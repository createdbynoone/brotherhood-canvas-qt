import QtQuick

// The access key is asked once per Mac; afterwards a token file opens the app directly.
Rectangle {
    id: root
    color: Theme.bg

    property double lockUntil: app.lockUntil
    property double now: Date.now()
    property bool wrong: false
    property bool checking: false
    readonly property bool locked: lockUntil > now
    readonly property int secondsLeft: Math.max(0, Math.ceil((lockUntil - now) / 1000))

    function submit() {
        if (locked || checking || field.text.length === 0) return
        checking = true
        app.verifyKey(field.text)
    }

    Connections {
        target: app
        function onKeyResult(ok, until) {
            root.checking = false
            if (!ok) { root.wrong = true; root.lockUntil = until; field.text = ""; shake.restart() }
        }
    }

    // Countdown ticks only while a lockout is active: an idle lock screen runs no timer at all.
    Timer {
        interval: 250; repeat: true; running: root.locked
        onTriggered: root.now = Date.now()
        onRunningChanged: root.now = Date.now()
    }

    Column {
        anchors.centerIn: parent
        spacing: 28

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16
            BrandMark { size: 52; anchors.horizontalCenter: parent.horizontalCenter }
            Column {
                spacing: 6
                anchors.horizontalCenter: parent.horizontalCenter
                Wordmark { size: 17; anchors.horizontalCenter: parent.horizontalCenter }
                Txt { text: "Enter the key to unlock"; variant: "small"; dim: true; anchors.horizontalCenter: parent.horizontalCenter }
            }
        }

        Column {
            spacing: 10
            width: 300
            anchors.horizontalCenter: parent.horizontalCenter
            Field {
                id: field
                width: parent.width
                implicitHeight: 40
                secret: true
                mono: true
                error: root.wrong
                enabled: !root.locked && !root.checking
                placeholder: "Access key"
                onAccepted: root.submit()
                onEdited: root.wrong = false
                transform: Translate { id: shiftX }
                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: shiftX; property: "x"; to: -7; duration: 55 }
                    NumberAnimation { target: shiftX; property: "x"; to: 7; duration: 70 }
                    NumberAnimation { target: shiftX; property: "x"; to: -4; duration: 60 }
                    NumberAnimation { target: shiftX; property: "x"; to: 0; duration: 50 }
                }
            }
            Btn {
                width: parent.width
                kind: "primary"; size: "l"; text: root.checking ? "Checking" : "Unlock"; busy: root.checking
                enabled: !root.locked && !root.checking && field.text.length > 0
                onClicked: root.submit()
            }
            Txt {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                variant: "small"
                text: root.locked ? "Too many attempts. Try again in " + root.secondsLeft + "s" : root.wrong ? "That key is not right" : " "
                color: root.locked ? Theme.warn : Theme.danger
            }
        }
    }
    Component.onCompleted: field.forceFocus()
}
