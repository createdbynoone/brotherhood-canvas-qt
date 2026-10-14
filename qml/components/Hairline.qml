import QtQuick

Rectangle {
    property bool vertical: false
    color: Theme.hairline
    implicitWidth: vertical ? 1 : 0
    implicitHeight: vertical ? 0 : 1
    width: vertical ? 1 : parent ? parent.width : 0
    height: vertical ? (parent ? parent.height : 0) : 1
}
