import QtQuick
import qs.Common
import qs.Widgets
import "../../core/Constants.js" as Constants

Rectangle {
    id: root

    property string iconName: ""
    property bool active: false

    signal clicked()

    width: Constants.subToolbarBtnSize
    height: Constants.subToolbarBtnSize
    radius: Theme.cornerRadius - 2
    color: root.active ? Theme.withAlpha(Theme.primary, 0.15) : (buttonMouse.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : "transparent")
    border.color: root.active ? Theme.primary : "transparent"
    border.width: 1

    DankIcon {
        anchors.centerIn: parent
        name: root.iconName
        size: Constants.subToolbarIconSize
        color: root.active ? Theme.primary : Theme.surfaceText
    }

    MouseArea {
        id: buttonMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
