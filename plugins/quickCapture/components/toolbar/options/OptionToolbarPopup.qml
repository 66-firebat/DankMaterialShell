import QtQuick

Item {
    id: root
    z: 2000
    anchors.fill: parent

    default property alias content: menuContent.data

    property bool visibleState: false
    property real menuX: 0
    property real menuY: 0
    property real panelWidth: 0
    property real panelHeight: 0
    property string toolbarPosition: "top"

    visible: opacity > 0
    opacity: 0

    states: [
        State {
            name: "visible"
            when: root.visibleState
            PropertyChanges { target: root; opacity: 1.0 }
            PropertyChanges { target: menuContent; scale: 1.0 }
        }
    ]

    transitions: [
        Transition {
            NumberAnimation { target: root; property: "opacity"; duration: 120; easing.type: Easing.OutQuad }
            NumberAnimation { target: menuContent; property: "scale"; duration: 120; easing.type: Easing.OutQuad }
        }
    ]

    function open(x, y) {
        root.menuX = x;
        root.menuY = y;
        root.visibleState = true;
    }

    function close() {
        root.visibleState = false;
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: (mouse) => {
            root.close();
            mouse.accepted = false;
        }
    }

    OptionToolbarPanel {
        id: menuContent
        popupRoot: root
        width: root.panelWidth
        height: root.panelHeight
    }
}
