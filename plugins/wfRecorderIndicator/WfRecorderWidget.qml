import QtQuick
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property bool ready: false

    Process {
        id: hideOnStart
        command: ["/home/fireshark/fire_profile/configuration_modules/DankMaterialShell/core/bin/dms", "ipc", "call", "widget", "hide", "wfRecorderIndicator"]
        running: true
        onExited: root.ready = true
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            opacity: root.ready ? 1 : 0

            DankIcon {
                name: "fiber_manual_record"
                size: Theme.iconSize
                color: "#ef4444"
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: "REC"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        DankIcon {
            name: "fiber_manual_record"
            size: Theme.iconSize
            color: "#ef4444"
            opacity: root.ready ? 1 : 0
        }
    }
}
