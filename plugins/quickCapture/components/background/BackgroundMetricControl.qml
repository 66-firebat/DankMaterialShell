import QtQuick
import qs.Common
import qs.Widgets
import "../core/Constants.js" as Constants

Item {
    id: root

    property string iconName: ""
    property string valueText: ""
    property bool compact: false

    signal hovered(var controlItem)
    signal exited()
    signal wheeled(int delta)

    implicitWidth: compact ? Constants.btnSize : metricRow.implicitWidth
    implicitHeight: compact ? 40 : Constants.btnSize
    width: implicitWidth
    height: implicitHeight

    Row {
        id: metricRow
        visible: !root.compact
        spacing: Theme.spacingXS
        anchors.verticalCenter: parent.verticalCenter

        DankIcon {
            name: root.iconName
            size: Constants.backgroundIconSize
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: root.valueText
            width: 40
            horizontalAlignment: Text.AlignRight
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Column {
        visible: root.compact
        spacing: Constants.spacingCompact
        anchors.centerIn: parent

        DankIcon {
            name: root.iconName
            size: Constants.iconSize
            color: Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: root.valueText
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered(root)
        onExited: root.exited()
        onWheel: (wheel) => root.wheeled(wheel.angleDelta.y)
    }
}
