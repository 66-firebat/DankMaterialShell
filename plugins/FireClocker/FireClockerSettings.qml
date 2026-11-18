import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root

    pluginId: "fireclocker"

    StyledText {
        width: parent.width
        text: "Desktop Card"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    SliderSetting {
        settingKey: "cardScalePct"
        label: "Card Scale"
        description: "Size of the semicircle widget. Drives the actual widget size, so drag-resize is disabled."
        defaultValue: 100
        minimum: 40
        maximum: 300
        unit: "%"
    }

    SliderSetting {
        settingKey: "surfaceOpacityPct"
        label: "Surface Opacity"
        description: "Opacity of the arc (track and progress). The card itself has no background."
        defaultValue: 85
        minimum: 0
        maximum: 100
        unit: "%"
    }

    SliderSetting {
        settingKey: "contentOpacityPct"
        label: "Content Opacity"
        description: "Opacity of the buttons, mode icon and time text"
        defaultValue: 100
        minimum: 0
        maximum: 100
        unit: "%"
    }

    SliderSetting {
        settingKey: "arcThicknessPx"
        label: "Arc Thickness"
        description: "Stroke width of the semicircle, scaled with the card"
        defaultValue: 7
        minimum: 2
        maximum: 16
        unit: "px"
    }

    ToggleSetting {
        settingKey: "showTimeAlways"
        label: "Always Show Time"
        description: "Show the remaining time next to the buttons instead of only on hover"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "showModeIcon"
        label: "Show Mode Icon"
        description: "Show the clickable mode icon on the flat edge (click cycles Timer / Stopwatch / Pomodoro)"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "hoverExpand"
        label: "Expand On Hover"
        description: "Grow the widget on hover to reveal the time and the control panel"
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "panelPosition"
        label: "Panel Position"
        description: "Which side of the semicircle the hover panel opens on. \"Above\" keeps the gauge in place when the widget sits near the bottom edge."
        options: [
            { label: "Above", value: "above" },
            { label: "Below", value: "below" }
        ]
        defaultValue: "above"
    }

    StyledText {
        width: parent.width
        text: "Bar Pill"
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
        settingKey: "pillFontSize"
        label: "Bar Font Size"
        description: "Size of the time text in the bar pill"
        defaultValue: Math.round(Theme.fontSizeMedium)
        minimum: 8
        maximum: 40
        unit: "px"
    }

    SelectionSetting {
        settingKey: "pillDisplayMode"
        label: "Bar Display"
        description: "Show numeric time or a progress bar in the bar"
        options: [
            { label: "Time Text", value: "time" },
            { label: "Progress Bar", value: "progress" }
        ]
        defaultValue: "time"
    }

    StyledText {
        width: parent.width
        text: "Timer"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
        topPadding: Theme.spacingM
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
        text: "Alerts"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
        topPadding: Theme.spacingM
    }

    ToggleSetting {
        settingKey: "useSystemSound"
        label: "Play Alarm Sound"
        description: "Play the system alarm sound (or the custom file below) when a countdown finishes"
        defaultValue: true
    }

    StringSetting {
        settingKey: "soundPath"
        label: "Custom Sound Path"
        description: "Full path to an audio file played on timeout. Leave empty for the system sound."
        placeholder: "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.alsa.wav"
        defaultValue: ""
    }

    ToggleSetting {
        settingKey: "showNotifications"
        label: "Show Desktop Notification"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "notifyMissedWhileAway"
        label: "Notify If Finished While Restarting"
        description: "Send a notification when a countdown expired while DMS was not running (the alarm sound is skipped in that case)"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "autoDND"
        label: "Auto Do Not Disturb"
        description: "Enable Do Not Disturb while the timer is running"
        defaultValue: false
    }
}
