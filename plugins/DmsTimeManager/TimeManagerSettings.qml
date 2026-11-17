import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root

    pluginId: "timeManager"

    StyledText {
        width: parent.width
        text: "Timer"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    SliderSetting {
        settingKey: "defaultTimerMinutes"
        label: "Default Time"
        description: "Minutes when starting a blank timer"
        defaultValue: 25
        minimum: 1
        maximum: 120
        unit: "min"
    }

    StyledText {
        width: parent.width
        text: "Pomodoro"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
        topPadding: Theme.spacingM
    }

    SliderSetting {
        settingKey: "pomodoroWorkMinutes"
        label: "Work Duration"
        defaultValue: 25
        minimum: 1
        maximum: 120
        unit: "min"
    }

    SliderSetting {
        settingKey: "pomodoroShortBreakMinutes"
        label: "Short Break"
        defaultValue: 5
        minimum: 1
        maximum: 30
        unit: "min"
    }

    SliderSetting {
        settingKey: "pomodoroLongBreakMinutes"
        label: "Long Break"
        defaultValue: 15
        minimum: 1
        maximum: 60
        unit: "min"
    }

    SliderSetting {
        settingKey: "pomodoroSessionsBeforeLongBreak"
        label: "Sessions Before Long Break"
        defaultValue: 4
        minimum: 1
        maximum: 10
    }

    ToggleSetting {
        settingKey: "autoStartBreaks"
        label: "Auto-start Next Phase"
        description: "Automatically start the next pomodoro phase when the current one ends"
        defaultValue: true
    }

    StyledText {
        width: parent.width
        text: "Sound"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
        topPadding: Theme.spacingM
    }

    StringSetting {
        settingKey: "soundPath"
        label: "Custom Sound Path"
        description: "Full path to an audio file played on timeout. Leave empty for system sound."
        placeholder: "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.alsa.wav"
        defaultValue: ""
    }

    ToggleSetting {
        settingKey: "useSystemSound"
        label: "Use System Alarm Sound"
        description: "Play a system alarm sound when the timer finishes"
        defaultValue: true
    }

    StyledText {
        width: parent.width
        text: "Notifications"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
        topPadding: Theme.spacingM
    }

    ToggleSetting {
        settingKey: "showNotifications"
        label: "Show Desktop Notification"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "autoDND"
        label: "Auto Do Not Disturb"
        description: "Toggle Do Not Disturb mode when the timer is running"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "notifyMissedWhileAway"
        label: "Notify If Finished While Restarting"
        description: "Send a notification when a countdown expired while DMS was not running (the alarm sound is skipped in that case)"
        defaultValue: true
    }

    StyledText {
        width: parent.width
        text: "Display"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
        topPadding: Theme.spacingM
    }

    ToggleSetting {
        settingKey: "showPillIcon"
        label: "Show Icon in Bar"
        description: "Show the mode icon next to the time in the bar"
        defaultValue: true
    }

    SliderSetting {
        settingKey: "barFontSize"
        label: "Bar Font Size"
        description: "Size of the time text in the bar pill (horizontal and vertical bars)"
        defaultValue: Math.round(Theme.fontSizeMedium)
        minimum: 8
        maximum: 40
        unit: "px"
    }

    SliderSetting {
        settingKey: "popoutFontSize"
        label: "Popout Font Size"
        description: "Size of the large time display inside the popout"
        defaultValue: 48
        minimum: 20
        maximum: 96
        unit: "px"
    }

    SelectionSetting {
        settingKey: "displayMode"
        label: "Bar Display"
        description: "Show numeric time or a progress bar in the bar"
        options: [
            { label: "Time Text", value: "time" },
            { label: "Progress Bar", value: "progress" }
        ]
        defaultValue: "time"
    }
}
