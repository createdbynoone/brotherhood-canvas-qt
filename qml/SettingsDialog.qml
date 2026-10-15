import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs

// One settings window (⌘,): vault, canvas behaviour, playback, shortcuts, security, updates.
Popup {
    id: root
    modal: true
    parent: Overlay.overlay
    anchors.centerIn: Overlay.overlay
    width: 600
    height: Math.min(660, (Overlay.overlay ? Overlay.overlay.height : 700) - 80)
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    Overlay.modal: Rectangle { color: Theme.scrim }
    background: Rectangle { radius: Theme.rPanel; color: Theme.surface; border.color: Theme.hairlineStrong }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.base } }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.fast } }

    FolderDialog { id: openPicker; title: "Choose a vault folder"; onAccepted: { root.close(); canvas.openVault(app.localPath(selectedFolder)) } }
    FolderDialog { id: createPicker; title: "Choose where the new vault goes"; onAccepted: { root.close(); canvas.createVault(app.localPath(selectedFolder)) } }

    component Section: Column {
        property string heading: ""
        default property alias rows: body.data
        width: parent.width
        spacing: 4
        Txt { text: heading; variant: "overline"; muted: true; bottomPadding: 6 }
        Rectangle {
            width: parent.width
            height: body.implicitHeight
            radius: Theme.rCard
            color: Theme.raised
            border.color: Theme.hairline
            Column { id: body; width: parent.width }
        }
    }
    component Row_: Item {
        property string label: ""
        property string value: ""
        property bool mono: false
        default property alias actions: act.data
        width: parent.width
        height: 44
        Txt { id: l; text: label; anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter }
        Row {
            id: act
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Txt {
                visible: value.length > 0
                text: value
                variant: mono ? "mono" : "small"
                dim: true
                elide: Text.ElideMiddle
                width: Math.min(implicitWidth, 280)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Hairline { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 14; opacity: 0.8 }
    }

    contentItem: Column {
        Item {
            width: parent.width; height: 56
            Txt { text: "Settings"; variant: "title"; anchors.left: parent.left; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter }
            Btn { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; kind: "ghost"; size: "s"; icon: "x"; onClicked: root.close() }
        }
        Hairline {}
        Flickable {
            width: parent.width; height: parent.height - 57
            contentWidth: width
            contentHeight: sections.implicitHeight + 40
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: StudioScrollBar {}
            Column {
                id: sections
                x: 20; y: 20
                width: parent.width - 40
                spacing: 22

                Section {
                    heading: "Vault"
                    Row_ {
                        label: "Open vault"; value: canvas.vaultName
                        Btn { kind: "secondary"; size: "xs"; text: "Show in Finder"; onClicked: app.openPath(canvas.vaultPath) }
                    }
                    Row_ { label: "Location"; value: app.abbreviate(canvas.vaultPath); mono: true }
                    Row_ {
                        label: "Switch vault"
                        Btn { kind: "secondary"; size: "xs"; text: "Open another"; onClicked: openPicker.open() }
                        Btn { kind: "ghost"; size: "xs"; text: "Create new"; onClicked: createPicker.open() }
                    }
                    Row_ { label: "A vault is a plain folder: boards as JSON, files in attachments. Back it up like any folder"; height: 38 }
                }
                Section {
                    heading: "Interface"
                    Row_ {
                        label: "Scale"
                        Segment {
                            height_: 26; fontSize: 11; hPad: 9
                            options: [100, 90, 80, 70, 60, 50].map(v => ({ key: v, label: v + "%" }))
                            current: app.uiScale
                            onPicked: key => app.uiScale = key
                        }
                    }
                    Row_ {
                        visible: app.uiScale !== app.activeUiScale
                        height: visible ? 44 : 0
                        label: "Restart to apply " + app.uiScale + "%"
                        Btn { kind: "primary"; size: "xs"; text: "Restart now"; onClicked: app.restart() }
                    }
                    Row_ { label: "A smaller scale fits more on screen and lets the window shrink further"; height: 38 }
                }
                Section {
                    heading: "Canvas"
                    Row_ { label: "Snap to alignment guides"; Toggle { checked: app.snap; onToggled: v => { app.snap = v; board.snapEnabled = v } } }
                    Row_ { label: "Show minimap"; Toggle { checked: app.minimap; onToggled: v => app.minimap = v } }
                    Row_ { label: "Hold Option while dragging to move without snapping"; height: 38 }
                }
                Section {
                    heading: "Playback"
                    Row_ {
                        label: "Video volume"
                        Slide { width: 180; from: 0; to: 1; step: 0.01; value: app.volume; active: true; unit: ""; readout: false; onMoved: v => app.volume = v }
                        Txt { text: Math.round(app.volume * 100) + "%"; variant: "mono"; dim: true; width: 40; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                Section {
                    heading: "Shortcuts"
                    Repeater {
                        model: [
                            ["Command palette", "⌘K"], ["New board", "⌘N"], ["Toggle sidebar", "⌘B"],
                            ["Select / Pan tool", "V / H  (hold Space to pan)"], ["Add title, note, text", "T  N  X"],
                            ["Fit all / selection", "F  /  ⇧F"], ["Zoom", "⌘+  ⌘-  ⌘0  or pinch"],
                            ["Copy, cut, paste, duplicate", "⌘C  ⌘X  ⌘V  ⌘D"], ["Undo / redo", "⌘Z  /  ⇧⌘Z"],
                            ["Bring forward / send back", "⌘]  /  ⌘["], ["Lock position", "⌘L"], ["Nudge selection", "Arrows  (⇧ for 10)"]
                        ]
                        delegate: Row_ { required property var modelData; label: modelData[0]; value: modelData[1]; mono: true; height: 38 }
                    }
                }
                Section {
                    heading: "Security"
                    Row_ { label: "Access key"; Btn { kind: "secondary"; size: "xs"; text: "Ask again next launch"; onClicked: app.forgetKey() } }
                    Row_ { label: "The key is asked once on this Mac and remembered in a private file"; height: 38 }
                }
                Section {
                    heading: "Updates"
                    Row_ { label: "Version"; value: "v" + app.version; mono: true }
                    Row_ {
                        label: "Latest release"
                        value: app.updateAvailable ? "v" + app.updateVersion + " available" : "Up to date"
                        Btn { kind: "secondary"; size: "xs"; text: "Check"; enabled: !app.checkingUpdate; onClicked: app.checkForUpdate() }
                        Btn { visible: app.updateAvailable; kind: "primary"; size: "xs"; text: app.updating ? "Downloading" : "Install and restart"; busy: app.updating; enabled: !app.updating; onClicked: app.installUpdate() }
                    }
                }
            }
        }
    }
}
