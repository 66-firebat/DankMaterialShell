import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dankStopwatch"

    StyledText {
        width: parent.width
        text: "Dank Stopwatch Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Tune the compact DankBar pill without changing the stopwatch behavior."
        wrapMode: Text.WordWrap
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }

    StyledRect {
        width: parent.width
        height: displayColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: displayColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Display"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            ToggleSetting {
                settingKey: "showCentiseconds"
                label: "Show centiseconds"
                description: "Display mm:ss.cs before the stopwatch reaches one hour"
                defaultValue: true
            }

            ToggleSetting {
                settingKey: "compactMode"
                label: "Compact mode"
                description: "Trim leading zero minutes in the DankBar pill"
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "showIcon"
                label: "Show icon"
                description: "Show the stopwatch icon in horizontal and vertical bar pills"
                defaultValue: true
            }

            ToggleSetting {
                settingKey: "showLapCountInPill"
                label: "Show lap count in pill"
                description: "Show a small lap count next to the compact time"
                defaultValue: false
            }
        }
    }

    StyledRect {
        width: parent.width
        height: behaviorColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: behaviorColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Timing"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            SelectionSetting {
                settingKey: "updateInterval"
                label: "Update interval"
                description: "Lower values feel smoother; higher values use slightly less CPU"
                options: [
                    { label: "50 ms", value: "50" },
                    { label: "100 ms", value: "100" },
                    { label: "250 ms", value: "250" }
                ]
                defaultValue: "100"
            }
        }
    }
}
