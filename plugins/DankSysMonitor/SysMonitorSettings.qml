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
        description: "How often to poll CPU/RAM"
        defaultValue: 2000
        minimum: 500
        maximum: 10000
        unit: "ms"
    }

    SliderSetting {
        settingKey: "numCores"
        label: "CPU Cores to Show"
        description: "Number of per-core icons in the bar"
        defaultValue: 4
        minimum: 1
        maximum: 32
    }

    ToggleSetting {
        settingKey: "showTemp"
        label: "Show CPU Temp in Popout"
        defaultValue: true
    }

    StringSetting {
        settingKey: "iconFontFamily"
        label: "Icon Font Family"
        description: "Leave blank to inherit the theme font. Set explicitly if the band glyphs render as boxes."
        placeholder: "e.g. Symbols Nerd Font Mono"
        defaultValue: ""
    }
}