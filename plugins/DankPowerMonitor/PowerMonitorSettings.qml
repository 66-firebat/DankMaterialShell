import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "dankPowerMonitor"

    StyledText {
        width: parent.width
        text: "Power Monitor Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    SliderSetting {
        settingKey: "fontSize"
        label: "Readout Font Size"
        description: "Size of the watts/temp readout text"
        defaultValue: Math.max(8, Math.round(Theme.fontSizeMedium) - 2)
        minimum: 8
        maximum: 32
        unit: "px"
    }

    SliderSetting {
        settingKey: "barFontSize"
        label: "Bar Font Size"
        description: "Size of the block bar cells"
        defaultValue: Math.round(Theme.fontSizeMedium)
        minimum: 8
        maximum: 40
        unit: "px"
    }

    SliderSetting {
        settingKey: "updateInterval"
        label: "Sample Interval"
        description: "How often power and temperature are sampled (drives the live bar cells)"
        defaultValue: 1000
        minimum: 250
        maximum: 5000
        unit: "ms"
    }

    SliderSetting {
        settingKey: "readoutInterval"
        label: "Readout Interval"
        description: "How often the watts/temp text refreshes (minimum 5 s; bar cells keep updating live)"
        defaultValue: 5000
        minimum: 5000
        maximum: 60000
        unit: "ms"
    }

    SliderSetting {
        settingKey: "animationDuration"
        label: "Animation Duration"
        description: "Duration of the color cross-fade when a cell updates"
        defaultValue: 800
        minimum: 0
        maximum: 5000
        unit: "ms"
    }

    SelectionSetting {
        settingKey: "animationEasing"
        label: "Animation Easing"
        description: "Easing curve used for cell color transitions"
        defaultValue: "OutQuad"
        options: [
            {
                "value": "Linear",
                "label": "Linear"
            },
            {
                "value": "InQuad",
                "label": "In Quad"
            },
            {
                "value": "OutQuad",
                "label": "Out Quad"
            },
            {
                "value": "InOutQuad",
                "label": "In Out Quad"
            },
            {
                "value": "OutCubic",
                "label": "Out Cubic"
            },
            {
                "value": "InOutCubic",
                "label": "In Out Cubic"
            }
        ]
    }
}
