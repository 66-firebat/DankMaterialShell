import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "dankSysMonitor"

    StyledText {
        width: parent.width
        text: "System Monitor Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    SliderSetting {
        settingKey: "updateInterval"
        label: "Refresh Interval"
        description: "How often to poll CPU/RAM (colors cross-fade between samples)"
        defaultValue: 3000
        minimum: 300
        maximum: 10000
        unit: "ms"
    }

    ToggleSetting {
        settingKey: "showTemp"
        label: "Show CPU Temp in Popout"
        defaultValue: true
    }
}
