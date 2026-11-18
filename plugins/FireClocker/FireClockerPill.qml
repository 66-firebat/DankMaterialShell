import QtQuick
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

// FireClocker bar pill. Shares its timer with the desktop card through
// FireClockerCore (PluginService.globalVars), so both surfaces stay in sync.
PluginComponent {
    id: root

    // ── Settings ──
    property int pillFontSize: pluginData.pillFontSize || Math.round(Theme.fontSizeMedium)
    property bool showPillIcon: pluginData.showPillIcon !== false
    property string pillDisplayMode: pluginData.pillDisplayMode || "time"

    FireClockerCore {
        id: core
        defaultTimerMinutes: pluginData.defaultTimerMinutes || 25
        pomodoroWorkMinutes: pluginData.pomodoroWorkMinutes || 25
        pomodoroShortBreakMinutes: pluginData.pomodoroShortBreakMinutes || 5
        pomodoroLongBreakMinutes: pluginData.pomodoroLongBreakMinutes || 15
        pomodoroSessionsBeforeLongBreak: pluginData.pomodoroSessionsBeforeLongBreak || 4
        autoStartBreaks: pluginData.autoStartBreaks !== false
        soundPath: pluginData.soundPath || ""
        useSystemSound: pluginData.useSystemSound !== false
        showNotifications: pluginData.showNotifications !== false
        notifyMissedWhileAway: pluginData.notifyMissedWhileAway !== false
        autoDND: pluginData.autoDND === true
    }

    pillClickAction: null
    pillRightClickAction: function () { core.resetStop(); }

    // ──────────────────────────────────────────────
    //  Horizontal pill
    // ──────────────────────────────────────────────
    horizontalBarPill: Component {
        Item {
            implicitWidth: pillInner.implicitWidth + Theme.spacingS
            implicitHeight: pillInner.implicitHeight

            Row {
                id: pillInner
                spacing: Theme.spacingS

                DankIcon {
                    name: core.modeIcons[core.currentMode] || "timer"
                    size: Theme.iconSizeSmall
                    color: core.modeColor
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showPillIcon

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: core.cycleMode()
                    }
                }

                Item {
                    width: 72
                    height: 8
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.pillDisplayMode === "progress" && !core.isIdle

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: core.modeColor
                        opacity: 0.2
                    }

                    Rectangle {
                        width: parent.width * core.progress
                        height: parent.height
                        radius: 4
                        color: core.modeColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: core.startPause()
                        onWheel: wheelEvent => core.adjustTime(wheelEvent.angleDelta.y > 0 ? 60 : -60)
                    }
                }

                StyledText {
                    text: core.formatTime(core.remainingMs)
                    color: core.modeColor
                    font.pixelSize: root.pillFontSize
                    isMonospace: true
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.pillDisplayMode !== "progress" || core.isIdle

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: core.startPause()
                        onWheel: wheelEvent => core.adjustTime(wheelEvent.angleDelta.y > 0 ? 60 : -60)
                    }
                }
            }
        }
    }

    // ──────────────────────────────────────────────
    //  Vertical pill
    // ──────────────────────────────────────────────
    verticalBarPill: Component {
        Item {
            implicitWidth: Math.max(modeIconV.width + Theme.spacingS, contentV.width + Theme.spacingS)
            implicitHeight: (root.showPillIcon ? modeIconV.height + Theme.spacingXS : 0)
                + contentV.height + Theme.spacingXS

            Column {
                spacing: Theme.spacingXS
                anchors.centerIn: parent

                DankIcon {
                    id: modeIconV
                    name: core.modeIcons[core.currentMode] || "timer"
                    size: Theme.iconSizeSmall
                    color: core.modeColor
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showPillIcon

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: core.cycleMode()
                    }
                }

                Item {
                    id: contentV
                    width: Math.max(progressBarV.width, timeTextV.width)
                    height: root.pillDisplayMode === "progress" && !core.isIdle
                        ? progressBarV.height : timeTextV.height
                    anchors.horizontalCenter: parent.horizontalCenter

                    Item {
                        id: progressBarV
                        width: 8
                        height: 48
                        anchors.centerIn: parent
                        visible: root.pillDisplayMode === "progress" && !core.isIdle

                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: core.modeColor
                            opacity: 0.2
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: parent.height * core.progress
                            radius: 4
                            color: core.modeColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: core.startPause()
                            onWheel: wheelEvent => core.adjustTime(wheelEvent.angleDelta.y > 0 ? 60 : -60)
                        }
                    }

                    StyledText {
                        id: timeTextV
                        text: core.formatTime(core.remainingMs)
                        color: core.modeColor
                        font.pixelSize: root.pillFontSize
                        isMonospace: true
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.pillDisplayMode !== "progress" || core.isIdle

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: core.startPause()
                            onWheel: wheelEvent => core.adjustTime(wheelEvent.angleDelta.y > 0 ? 60 : -60)
                        }
                    }
                }
            }
        }
    }

    // ──────────────────────────────────────────────
    //  Popout
    // ──────────────────────────────────────────────
    popoutWidth: 400
    popoutHeight: 520

    popoutContent: Component {
        PopoutComponent {
            id: popout
            headerText: "FireClocker"

            Column {
                width: parent.width
                spacing: Theme.spacingM

                Row {
                    spacing: Theme.spacingS
                    anchors.horizontalCenter: parent.horizontalCenter

                    Repeater {
                        model: [
                            { key: "timer", label: "Timer" },
                            { key: "stopwatch", label: "Stopwatch" },
                            { key: "pomodoro", label: "Pomodoro" }
                        ]

                        delegate: Rectangle {
                            required property var modelData

                            width: 112
                            height: 34
                            radius: Theme.cornerRadius
                            color: core.currentMode === modelData.key
                                ? Theme.primary : Theme.surfaceContainerHigh

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                DankIcon {
                                    name: core.modeIcons[modelData.key] || "timer"
                                    size: 16
                                    color: core.currentMode === modelData.key ? Theme.onPrimary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: modelData.label
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: core.currentMode === modelData.key ? Theme.onPrimary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: core.setMode(modelData.key)
                            }
                        }
                    }
                }

                StyledText {
                    text: core.formatTimeShort(core.remainingMs)
                    font.pixelSize: 44
                    font.weight: Font.Bold
                    isMonospace: true
                    color: core.modeColor
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    text: core.currentMode === "pomodoro"
                        ? ("Session " + core.pomodoroSession + " \u2014 " + core.phaseLabel)
                        : ""
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: core.currentMode === "pomodoro"
                }

                Row {
                    spacing: Theme.spacingS
                    anchors.horizontalCenter: parent.horizontalCenter

                    DankButton {
                        text: core.isRunning ? "Pause" : (core.isIdle ? "Start" : "Resume")
                        iconName: core.isRunning ? "pause" : "play_arrow"
                        backgroundColor: Theme.primary
                        textColor: Theme.onPrimary
                        onClicked: core.startPause()
                    }

                    DankButton {
                        text: "Reset"
                        iconName: "stop"
                        backgroundColor: Theme.surfaceContainerHigh
                        textColor: Theme.error
                        onClicked: core.resetStop()
                    }
                }

                // Display mode for the bar pill
                Row {
                    spacing: 0
                    anchors.horizontalCenter: parent.horizontalCenter

                    Repeater {
                        model: [
                            { key: "time", label: "Time Text" },
                            { key: "progress", label: "Progress Bar" }
                        ]

                        delegate: Rectangle {
                            required property var modelData

                            width: 100
                            height: 32
                            radius: Theme.cornerRadius
                            color: root.pillDisplayMode === modelData.key
                                ? Theme.primary : Theme.surfaceContainerHigh

                            StyledText {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: root.pillDisplayMode === modelData.key ? Font.Bold : Font.Normal
                                color: root.pillDisplayMode === modelData.key ? Theme.onPrimary : Theme.surfaceText
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.pillDisplayMode = modelData.key;
                                    if (pluginService)
                                        pluginService.savePluginData(pluginId, "pillDisplayMode", modelData.key);
                                }
                            }
                        }
                    }
                }

                // Timer presets
                Flow {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: core.currentMode === "timer" && core.isIdle

                    Repeater {
                        model: [5, 10, 15, 20, 25, 30]

                        delegate: DankButton {
                            required property int modelData

                            text: modelData + "m"
                            width: (parent.width - Theme.spacingS * 2) / 3
                            backgroundColor: Theme.primaryContainer
                            textColor: Theme.onPrimaryContainer
                            onClicked: {
                                core.startTimer(modelData);
                                root.closePopout();
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: core.currentMode === "timer" && core.isIdle

                    DankTextField {
                        id: customInput
                        placeholderText: "Minutes..."
                        width: parent.width - setBtn.width - parent.spacing
                        validator: IntValidator { bottom: 1; top: 1440 }
                        onAccepted: setBtn.clicked()
                    }

                    DankButton {
                        id: setBtn
                        text: "Set"
                        iconName: "play_arrow"
                        backgroundColor: Theme.primary
                        textColor: Theme.onPrimary
                        onClicked: {
                            const mins = parseInt(customInput.text);
                            if (!isNaN(mins) && mins > 0) {
                                core.startTimer(mins);
                                customInput.text = "";
                                root.closePopout();
                            }
                        }
                    }
                }

                Row {
                    spacing: Theme.spacingS
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: core.currentMode === "pomodoro" && core.pomodoroPhase !== "work" && !core.isIdle

                    DankButton {
                        text: "Skip to Next Phase"
                        iconName: "skip_next"
                        backgroundColor: Theme.tertiaryContainer
                        textColor: Theme.onTertiaryContainer
                        onClicked: core.skipPhase()
                    }
                }

                StyledText {
                    width: parent.width
                    text: "\u2022 The desktop card shows the same timer as this pill\n"
                        + "\u2022 Click the icon to cycle Timer / Stopwatch / Pomodoro\n"
                        + "\u2022 Left-click time to Start/Pause \u2022 Right-click to Reset"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.4
                }
            }
        }
    }

    // ──────────────────────────────────────────────
    //  IPC
    // ──────────────────────────────────────────────
    IpcHandler {
        function status(): string {
            if (core.isIdle) return "idle";
            if (core.isFinished) return "finished";
            if (core.isPaused) return "paused";
            return "running";
        }

        function getStatus(): string {
            return JSON.stringify({
                state: status(),
                mode: core.currentMode,
                remainingMs: core.remainingMs,
                totalMs: core.totalMs,
                formatted: core.formatTime(core.remainingMs),
                pomodoroPhase: core.pomodoroPhase,
                pomodoroSession: core.pomodoroSession,
                finishedWhileAway: core.finishedWhileAway
            });
        }

        function toggle(): string {
            core.startPause();
            return status();
        }

        function pause(): string {
            if (core.isRunning) {
                core.setVar("wallAccum", core.wallAccum + (Date.now() - core.wallBase));
                core.setVar("wallBase", 0);
                core.setVar("isRunning", false);
                return "paused";
            }
            return "already_paused";
        }

        function resume(): string {
            if (core.isPaused) {
                core.setVar("wallBase", Date.now());
                core.setVar("isRunning", true);
                return "running";
            }
            if (core.isIdle) {
                core.startPause();
                return "running";
            }
            return "already_running";
        }

        function reset(): string {
            core.resetStop();
            return "reset";
        }

        function mode(m: string): string {
            if (["timer", "stopwatch", "pomodoro"].indexOf(m) >= 0) {
                core.setMode(m);
                return "mode_set_to_" + m;
            }
            return "invalid_mode";
        }

        function startTimer(minutes: string): string {
            const m = parseInt(minutes);
            if (isNaN(m) || m <= 0) return "ERROR: invalid_minutes";
            core.startTimer(m);
            return "started_" + m + "m";
        }

        function clearState(): string {
            core.clearState();
            return "state_cleared";
        }

        target: "fireclocker"
        enabled: true
    }
}
