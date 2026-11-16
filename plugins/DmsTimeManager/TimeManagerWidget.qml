import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginComponent {
    id: root

    // ── Settings (from pluginData) ──
    property int defaultTimerMinutes: pluginData.defaultTimerMinutes || 25
    property int pomodoroWorkMinutes: pluginData.pomodoroWorkMinutes || 25
    property int pomodoroShortBreakMinutes: pluginData.pomodoroShortBreakMinutes || 5
    property int pomodoroLongBreakMinutes: pluginData.pomodoroLongBreakMinutes || 15
    property int pomodoroSessionsBeforeLongBreak: pluginData.pomodoroSessionsBeforeLongBreak || 4
    property string soundPath: pluginData.soundPath || ""
    property bool useSystemSound: pluginData.useSystemSound !== false
    property bool showNotifications: pluginData.showNotifications !== false
    property bool autoStartBreaks: pluginData.autoStartBreaks || false
    property bool autoDND: pluginData.autoDND || false
    property bool showPillIcon: pluginData.showPillIcon !== false
    property string displayMode: pluginData.displayMode || "time"

    // ── Cross-instance state ──
    PluginGlobalVar {
        id: globalRemainingMs
        varName: "dtmRemainingMs"
        defaultValue: 0
    }

    PluginGlobalVar {
        id: globalTotalMs
        varName: "dtmTotalMs"
        defaultValue: 0
    }

    PluginGlobalVar {
        id: globalIsRunning
        varName: "dtmIsRunning"
        defaultValue: false
    }

    PluginGlobalVar {
        id: globalMode
        varName: "dtmMode"
        defaultValue: "timer"
    }

    PluginGlobalVar {
        id: globalPomodoroPhase
        varName: "dtmPomodoroPhase"
        defaultValue: "work"
    }

    PluginGlobalVar {
        id: globalPomodoroSession
        varName: "dtmPomodoroSession"
        defaultValue: 1
    }

    PluginGlobalVar {
        id: globalWallBase
        varName: "dtmWallBase"
        defaultValue: 0
    }

    PluginGlobalVar {
        id: globalWallAccum
        varName: "dtmWallAccum"
        defaultValue: 0
    }

    // ── Derived state ──
    readonly property string currentMode: globalMode.value || "timer"
    readonly property bool isRunning: globalIsRunning.value
    readonly property bool isPaused: !isRunning && globalRemainingMs.value > 0 && globalRemainingMs.value < globalTotalMs.value
    readonly property bool isFinished: !isRunning && globalRemainingMs.value === 0 && globalTotalMs.value > 0
    readonly property bool isIdle: globalTotalMs.value === 0
    readonly property string pomodoroPhase: globalPomodoroPhase.value || "work"
    readonly property int pomodoroSession: globalPomodoroSession.value || 1

    readonly property color pillColor: {
        if (isRunning) return Theme.primary;
        if (isPaused || isFinished) return Theme.warning;
        return Theme.surfaceText;
    }

    readonly property real pillProgress: {
        if (isIdle || globalTotalMs.value === 0) return 0;
        if (currentMode === "stopwatch")
            return Math.min(1, globalRemainingMs.value / globalTotalMs.value);
        return 1 - (globalRemainingMs.value / globalTotalMs.value);
    }

    readonly property var modeIcons: ({
        "timer": "timer",
        "stopwatch": "timer_10",
        "pomodoro": "timelapse"
    })

    readonly property var modeNames: ({
        "timer": "Timer",
        "stopwatch": "Stopwatch",
        "pomodoro": "Pomodoro"
    })

    // ── Time formatting ──
    function formatTime(ms) {
        var totalSeconds = Math.floor(ms / 1000);
        var hours = Math.floor(totalSeconds / 3600);
        var minutes = Math.floor((totalSeconds % 3600) / 60);
        var seconds = totalSeconds % 60;
        return ("0" + hours).slice(-2) + ":" +
               ("0" + minutes).slice(-2) + ":" +
               ("0" + seconds).slice(-2);
    }

    function formatTimeShort(ms) {
        var totalSeconds = Math.floor(ms / 1000);
        var hours = Math.floor(totalSeconds / 3600);
        var minutes = Math.floor((totalSeconds % 3600) / 60);
        var seconds = totalSeconds % 60;
        if (hours > 0)
            return hours + ":" + ("0" + minutes).slice(-2) + ":" + ("0" + seconds).slice(-2);
        return minutes + ":" + ("0" + seconds).slice(-2);
    }

    // ── Wall-clock sync ──
    function syncRemainingFromWall() {
        if (!isRunning || globalWallBase.value === 0) return;

        var elapsed = Date.now() - globalWallBase.value;
        var totalElapsed = globalWallAccum.value + elapsed;

        if (currentMode === "stopwatch") {
            var swVal = Math.min(globalTotalMs.value, totalElapsed);
            globalRemainingMs.set(swVal);
            if (swVal >= globalTotalMs.value) {
                globalIsRunning.set(false);
            }
        } else {
            var consumed = totalElapsed;
            var remaining = Math.max(0, globalTotalMs.value - consumed);
            globalRemainingMs.set(remaining);
            if (remaining <= 0) {
                globalIsRunning.set(false);
                globalRemainingMs.set(0);
                handleTimeout();
            }
        }
    }

    // ── Core actions ──
    function cycleMode() {
        var modes = ["timer", "stopwatch", "pomodoro"];
        var idx = modes.indexOf(currentMode);
        var next = modes[(idx + 1) % modes.length];
        resetStop();
        globalMode.set(next);
        if (pluginService)
            pluginService.savePluginData(pluginId, "lastMode", next);
    }

    function setMode(mode) {
        resetStop();
        globalMode.set(mode);
        if (pluginService)
            pluginService.savePluginData(pluginId, "lastMode", mode);
    }

    function startPause() {
        if (currentMode === "stopwatch") {
            if (isIdle || isFinished) {
                resetStop();
                globalTotalMs.set(86400000);
                globalWallBase.set(Date.now());
                globalWallAccum.set(0);
                globalRemainingMs.set(0);
                globalIsRunning.set(true);
                return;
            }
            if (isRunning) {
                globalWallAccum.set(globalWallAccum.value + (Date.now() - globalWallBase.value));
                globalWallBase.set(0);
                globalIsRunning.set(false);
                syncRemainingFromWall();
            } else {
                globalWallBase.set(Date.now());
                globalIsRunning.set(true);
            }
            return;
        }

        if (isIdle) {
            var minutes = currentMode === "timer" ? defaultTimerMinutes
                        : (pomodoroPhase === "work" ? pomodoroWorkMinutes
                           : (pomodoroPhase === "shortBreak" ? pomodoroShortBreakMinutes
                              : pomodoroLongBreakMinutes));
            startTimer(minutes);
            return;
        }

        if (isFinished) {
            resetStop();
            return;
        }

        if (isRunning) {
            globalWallAccum.set(globalWallAccum.value + (Date.now() - globalWallBase.value));
            globalWallBase.set(0);
            globalIsRunning.set(false);
            syncRemainingFromWall();
        } else {
            globalWallBase.set(Date.now());
            globalIsRunning.set(true);
        }
    }

    function startTimer(minutes) {
        var ms = minutes * 60 * 1000;
        globalTotalMs.set(ms);
        globalWallAccum.set(0);
        globalWallBase.set(Date.now());
        globalRemainingMs.set(ms);
        globalIsRunning.set(true);
        root.closePopout();
    }

    function resetStop() {
        globalIsRunning.set(false);
        globalRemainingMs.set(0);
        globalTotalMs.set(0);
        globalWallBase.set(0);
        globalWallAccum.set(0);
    }

    function adjustTime(deltaSeconds) {
        if ((isPaused || isIdle) && currentMode === "timer") {
            var newVal = Math.max(0, Math.min(globalRemainingMs.value + deltaSeconds * 1000, 86400000));
            globalRemainingMs.set(newVal);
            globalTotalMs.set(newVal);
        }
    }

    function playAlarm() {
        if (soundPath !== "")
            Proc.runCommand("dtm-alarm", ["paplay", soundPath], null, 0);
        else
            Proc.runCommand("dtm-alarm", ["canberra-gtk-play", "-i", "message",
                "-d", "DmsTimeManager"], null, 0);
    }

    function handleTimeout() {
        playAlarm();

        if (showNotifications)
            Proc.runCommand("dtm-notify", ["notify-send", "-i", "appointment-soon", "-u", "critical",
                "DmsTimeManager",
                currentMode === "timer" ? "Timer finished!" :
                currentMode === "pomodoro" ? (pomodoroPhase === "work" ? "Work session complete!" : "Break over!") :
                "Stopwatch finished"], null, 0);

        if (currentMode === "pomodoro")
            advancePomodoroPhase();
    }

    function advancePomodoroPhase() {
        if (pomodoroPhase === "work") {
            var newSession = pomodoroSession + 1;
            globalPomodoroSession.set(newSession);
            globalPomodoroPhase.set(
                newSession % pomodoroSessionsBeforeLongBreak === 0 ? "longBreak" : "shortBreak"
            );
            if (autoStartBreaks) {
                var breakMins = newSession % pomodoroSessionsBeforeLongBreak === 0
                    ? pomodoroLongBreakMinutes : pomodoroShortBreakMinutes;
                startTimer(breakMins);
            }
        } else {
            globalPomodoroPhase.set("work");
            if (autoStartBreaks)
                startTimer(pomodoroWorkMinutes);
        }
    }

    function skipPhase() {
        if (currentMode === "pomodoro" && pomodoroPhase !== "work") {
            advancePomodoroPhase();
        }
    }

    // ── Auto DND ──
    onIsRunningChanged: {
        if (autoDND)
            SessionData.isDND = isRunning;
    }

    Connections {
        target: globalRemainingMs
        function onValueChanged() {
            if (autoDND && globalRemainingMs.value === 0 && !isRunning)
                SessionData.isDND = false;
        }
    }

    // ── High-frequency refresh timer ──
    Timer {
        id: refreshTimer
        interval: 200
        repeat: true
        running: globalIsRunning.value
        onTriggered: syncRemainingFromWall()
    }

    // ── Restore last mode on load ──
    Component.onCompleted: {
        var savedMode = pluginService ? pluginService.loadPluginData(pluginId, "lastMode") : null;
        if (savedMode && ["timer", "stopwatch", "pomodoro"].indexOf(savedMode) >= 0)
            globalMode.set(savedMode);
    }

    // ──────────────────────────────────────────────
    //  Pill actions
    // ──────────────────────────────────────────────
    pillClickAction: null
    pillRightClickAction: function () { resetStop(); }

    // ──────────────────────────────────────────────
    //  horizontalBarPill
    // ──────────────────────────────────────────────
    horizontalBarPill: Component {
        Item {
            implicitWidth: pillInner.implicitWidth + Theme.spacingS
            implicitHeight: pillInner.implicitHeight

            Row {
                id: pillInner
                spacing: Theme.spacingS

                DankIcon {
                    id: modeIcon
                    name: root.modeIcons[root.currentMode] || "timer"
                    size: Theme.iconSizeSmall
                    color: root.pillColor
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showPillIcon

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cycleMode()
                    }
                }

                Item {
                    width: 72
                    height: 8
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.displayMode === "progress" && !root.isIdle

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: root.pillColor
                        opacity: 0.2
                    }

                    Rectangle {
                        width: parent.width * root.pillProgress
                        height: parent.height
                        radius: 4
                        color: root.pillColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.startPause()
                        onWheel: function (wheelEvent) {
                            var delta = wheelEvent.angleDelta.y > 0 ? 60 : -60;
                            root.adjustTime(delta);
                        }
                    }
                }

                StyledText {
                    id: timeText
                    text: root.formatTime(globalRemainingMs.value)
                    color: root.pillColor
                    font.pixelSize: Theme.fontSizeMedium
                    isMonospace: true
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.displayMode !== "progress" || root.isIdle

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.startPause()
                        onWheel: function (wheelEvent) {
                            var delta = wheelEvent.angleDelta.y > 0 ? 60 : -60;
                            root.adjustTime(delta);
                        }
                    }
                }
            }
        }
    }

    // ──────────────────────────────────────────────
    //  verticalBarPill
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
                    name: root.modeIcons[root.currentMode] || "timer"
                    size: Theme.iconSizeSmall
                    color: root.pillColor
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showPillIcon

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cycleMode()
                    }
                }

                Item {
                    id: contentV
                    width: Math.max(progressBarV.width, timeTextV.width)
                    height: root.displayMode === "progress" && !root.isIdle
                        ? progressBarV.height : timeTextV.height
                    anchors.horizontalCenter: parent.horizontalCenter

                    Item {
                        id: progressBarV
                        width: 8
                        height: 48
                        anchors.centerIn: parent
                        visible: root.displayMode === "progress" && !root.isIdle

                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: root.pillColor
                            opacity: 0.2
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: parent.height * root.pillProgress
                            radius: 4
                            color: root.pillColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.startPause()
                            onWheel: function (wheelEvent) {
                                var delta = wheelEvent.angleDelta.y > 0 ? 60 : -60;
                                root.adjustTime(delta);
                            }
                        }
                    }

                    StyledText {
                        id: timeTextV
                        text: root.formatTime(globalRemainingMs.value)
                        color: root.pillColor
                        font.pixelSize: Theme.fontSizeSmall
                        isMonospace: true
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.displayMode !== "progress" || root.isIdle

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.startPause()
                            onWheel: function (wheelEvent) {
                                var delta = wheelEvent.angleDelta.y > 0 ? 60 : -60;
                                root.adjustTime(delta);
                            }
                        }
                    }
                }
            }
        }
    }

    // ──────────────────────────────────────────────
    //  Popout
    // ──────────────────────────────────────────────
    popoutWidth: 420
    popoutHeight: 540

    popoutContent: Component {
        PopoutComponent {
            id: popout
            headerText: "DmsTimeManager"
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingM

                Row {
                    spacing: Theme.spacingS
                    anchors.horizontalCenter: parent.horizontalCenter

                    Repeater {
                        model: [
                            { key: "timer",      label: "Timer" },
                            { key: "stopwatch",  label: "Stopwatch" },
                            { key: "pomodoro",   label: "Pomodoro" }
                        ]

                        delegate: Rectangle {
                            required property var modelData

                            width: 120
                            height: 36
                            radius: Theme.cornerRadius
                            color: root.currentMode === modelData.key
                                ? Theme.primary : Theme.surfaceContainerHigh

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                DankIcon {
                                    name: root.modeIcons[modelData.key] || "timer"
                                    size: 16
                                    color: root.currentMode === modelData.key
                                        ? Theme.onPrimary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: modelData.label
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: root.currentMode === modelData.key
                                        ? Theme.onPrimary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setMode(modelData.key)
                            }
                        }
                    }
                }

                StyledText {
                    text: root.formatTimeShort(globalRemainingMs.value)
                    font.pixelSize: 48
                    font.weight: Font.Bold
                    isMonospace: true
                    color: root.pillColor
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    text: root.currentMode === "pomodoro"
                        ? ("Session " + root.pomodoroSession
                           + " \u2014 "
                           + (root.pomodoroPhase === "work" ? "Focus"
                              : root.pomodoroPhase === "shortBreak" ? "Short Break"
                              : "Long Break"))
                        : ""
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.currentMode === "pomodoro"
                }

                Row {
                    spacing: Theme.spacingS
                    anchors.horizontalCenter: parent.horizontalCenter

                    DankButton {
                        text: root.isRunning ? "Pause"
                            : (root.isIdle ? "Start" : "Resume")
                        iconName: root.isRunning ? "pause" : "play_arrow"
                        backgroundColor: Theme.primary
                        textColor: Theme.onPrimary
                        onClicked: root.startPause()
                    }

                    DankButton {
                        text: "Reset"
                        iconName: "stop"
                        backgroundColor: Theme.surfaceContainerHigh
                        textColor: Theme.error
                        onClicked: root.resetStop()
                    }
                }

                // ── Display mode segmented button ──
                Row {
                    spacing: 0
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        width: 100
                        height: 32
                        radius: Theme.cornerRadius
                        color: root.displayMode === "time" ? Theme.primary : Theme.surfaceContainerHigh

                        StyledText {
                            anchors.centerIn: parent
                            text: "Time Text"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: root.displayMode === "time" ? Font.Bold : Font.Normal
                            color: root.displayMode === "time" ? Theme.onPrimary : Theme.surfaceText
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.displayMode = "time";
                                if (pluginService)
                                    pluginService.savePluginData(pluginId, "displayMode", "time");
                            }
                        }
                    }

                    Rectangle {
                        width: 100
                        height: 32
                        radius: Theme.cornerRadius
                        color: root.displayMode === "progress" ? Theme.primary : Theme.surfaceContainerHigh

                        StyledText {
                            anchors.centerIn: parent
                            text: "Progress Bar"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: root.displayMode === "progress" ? Font.Bold : Font.Normal
                            color: root.displayMode === "progress" ? Theme.onPrimary : Theme.surfaceText
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.displayMode = "progress";
                                if (pluginService)
                                    pluginService.savePluginData(pluginId, "displayMode", "progress");
                            }
                        }
                    }
                }

                // ── Timer presets ──
                Flow {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.currentMode === "timer" && root.isIdle

                    Repeater {
                        model: [5, 10, 15, 20, 25, 30]
                        delegate: DankButton {
                            required property int modelData

                            text: modelData + "m"
                            width: (parent.width - Theme.spacingS * 2) / 3
                            backgroundColor: Theme.primaryContainer
                            textColor: Theme.onPrimaryContainer
                            onClicked: root.startTimer(modelData)
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.currentMode === "timer" && root.isIdle

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
                            var mins = parseInt(customInput.text);
                            if (!isNaN(mins) && mins > 0) {
                                root.startTimer(mins);
                                customInput.text = "";
                            }
                        }
                    }
                }

                Row {
                    spacing: Theme.spacingS
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.currentMode === "pomodoro"
                        && root.pomodoroPhase !== "work"
                        && !root.isIdle

                    DankButton {
                        text: "Skip to Next Phase"
                        iconName: "skip_next"
                        backgroundColor: Theme.tertiaryContainer
                        textColor: Theme.onTertiaryContainer
                        onClicked: root.skipPhase()
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.2
                }

                StyledText {
                    width: parent.width
                    text: "\u2022 Click the icon in the bar to cycle Timer / Stopwatch / Pomodoro\n"
                        + "\u2022 Left-click time to Start/Pause \u2022 Right-click to Reset\n"
                        + "\u2022 Scroll when paused to adjust time"
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
        function status() : string {
            if (root.isIdle) return "idle";
            if (root.isFinished) return "finished";
            if (root.isPaused) return "paused";
            return "running";
        }

        function getStatus() : string {
            return JSON.stringify({
                state: status(),
                mode: root.currentMode,
                remainingMs: globalRemainingMs.value,
                totalMs: globalTotalMs.value,
                formatted: root.formatTime(globalRemainingMs.value),
                pomodoroPhase: root.pomodoroPhase,
                pomodoroSession: root.pomodoroSession
            });
        }

        function toggle() : string {
            root.startPause();
            return status();
        }

        function pause() : string {
            if (root.isRunning) {
                globalWallAccum.set(globalWallAccum.value + (Date.now() - globalWallBase.value));
                globalWallBase.set(0);
                globalIsRunning.set(false);
                return "paused";
            }
            return "already_paused";
        }

        function resume() : string {
            if (root.isPaused) {
                globalWallBase.set(Date.now());
                globalIsRunning.set(true);
                return "running";
            }
            if (root.isIdle) {
                root.startPause();
                return "running";
            }
            return "already_running";
        }

        function reset() : string {
            root.resetStop();
            return "reset";
        }

        function mode(m: string) : string {
            if (["timer", "stopwatch", "pomodoro"].indexOf(m) >= 0) {
                root.setMode(m);
                return "mode_set_to_" + m;
            }
            return "invalid_mode";
        }

        function startTimer(minutes: string) : string {
            var m = parseInt(minutes);
            if (isNaN(m) || m <= 0) return "ERROR: invalid_minutes";
            if (root.currentMode !== "timer" && root.currentMode !== "pomodoro")
                return "ERROR: wrong_mode";
            root.setMode(root.currentMode === "pomodoro" ? "pomodoro" : "timer");
            root.startTimer(m);
            return "started_" + m + "m";
        }

        target: "timeManager"
        enabled: true
    }
}
