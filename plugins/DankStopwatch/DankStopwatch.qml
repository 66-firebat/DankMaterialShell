import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    popoutWidth: 420
    popoutHeight: 520

    property bool showCentiseconds: pluginData.showCentiseconds !== false
    property bool compactMode: pluginData.compactMode === true
    property bool showIcon: pluginData.showIcon !== false
    property bool showLapCountInPill: pluginData.showLapCountInPill === true
    property int updateInterval: parseInt(pluginData.updateInterval, 10) || 100

    readonly property bool hasTime: elapsedMs.value > 0 || accumulatedMs.value > 0
    readonly property bool paused: !running.value && accumulatedMs.value > 0
    readonly property string statusLabel: running.value ? "Running" : (paused ? "Paused" : "Ready")
    readonly property color accentColor: running.value ? Theme.primary : (paused ? Theme.surfaceVariantText : Theme.primary)

    PluginGlobalVar {
        id: running
        varName: "running"
        defaultValue: false
    }

    PluginGlobalVar {
        id: startedAt
        varName: "startedAt"
        defaultValue: 0
    }

    PluginGlobalVar {
        id: accumulatedMs
        varName: "accumulatedMs"
        defaultValue: 0
    }

    PluginGlobalVar {
        id: elapsedMs
        varName: "elapsedMs"
        defaultValue: 0
    }

    Timer {
        id: ticker
        interval: Math.max(50, root.updateInterval)
        repeat: true
        running: running.value
        onTriggered: root.refreshElapsed()
    }

    ListModel {
        id: lapsModel
    }

    function nowMs() {
        return Date.now();
    }

    function refreshElapsed() {
        if (running.value) {
            elapsedMs.set(accumulatedMs.value + nowMs() - startedAt.value);
        } else {
            elapsedMs.set(accumulatedMs.value);
        }
    }

    function startStopwatch() {
        accumulatedMs.set(0);
        elapsedMs.set(0);
        startedAt.set(nowMs());
        running.set(true);
    }

    function pauseStopwatch() {
        if (!running.value)
            return;
        refreshElapsed();
        accumulatedMs.set(elapsedMs.value);
        running.set(false);
    }

    function resumeStopwatch() {
        if (running.value)
            return;
        startedAt.set(nowMs());
        running.set(true);
    }

    function resetStopwatch() {
        running.set(false);
        startedAt.set(0);
        accumulatedMs.set(0);
        elapsedMs.set(0);
        lapsModel.clear();
        copiedPulse.stop();
        copiedPulse.running = false;
    }

    function primaryAction() {
        if (running.value) {
            pauseStopwatch();
        } else if (paused) {
            resumeStopwatch();
        } else {
            startStopwatch();
        }
    }

    function primaryActionText() {
        if (running.value)
            return "Pause";
        if (paused)
            return "Resume";
        return "Start";
    }

    function primaryActionIcon() {
        if (running.value)
            return "pause";
        if (paused)
            return "play_arrow";
        return "play_arrow";
    }

    function addLap() {
        if (!running.value)
            return;
        refreshElapsed();
        const previousElapsed = lapsModel.count > 0 ? lapsModel.get(0).elapsed : 0;
        const currentElapsed = elapsedMs.value;
        lapsModel.insert(0, {
            "number": lapsModel.count + 1,
            "elapsed": currentElapsed,
            "time": formatTime(currentElapsed, true),
            "delta": "+" + formatTime(Math.max(0, currentElapsed - previousElapsed), true)
        });
    }

    function clearLaps() {
        lapsModel.clear();
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function copyCurrentTime() {
        refreshElapsed();
        const text = formatTime(elapsedMs.value, true);
        Quickshell.execDetached(["sh", "-c", "printf %s " + shellQuote(text) + " | dms cl copy"]);
        copiedPulse.restart();
        if (typeof ToastService !== "undefined")
            ToastService.showInfo("Dank Stopwatch", "Copied " + text);
    }

    function formatTime(milliseconds, forceDetailed) {
        const safeMs = Math.max(0, Math.floor(milliseconds));
        const totalSeconds = Math.floor(safeMs / 1000);
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;
        const centiseconds = Math.floor((safeMs % 1000) / 10);

        if (hours > 0)
            return hours + ":" + pad2(minutes) + ":" + pad2(seconds);

        const base = pad2(minutes) + ":" + pad2(seconds);
        if ((forceDetailed || root.showCentiseconds) && root.showCentiseconds)
            return base + "." + pad2(centiseconds);
        return base;
    }

    function compactTime() {
        const text = formatTime(elapsedMs.value, false);
        if (!compactMode)
            return text;
        return text.replace(/^00:/, "0:");
    }

    function pad2(value) {
        return value < 10 ? "0" + value : String(value);
    }

    Timer {
        id: copiedPulse
        interval: 1200
        repeat: false
    }

    onUpdateIntervalChanged: {
        ticker.interval = Math.max(50, root.updateInterval);
    }

    Component.onCompleted: refreshElapsed()

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                visible: root.showIcon
                name: running.value ? "timer" : "timer"
                color: root.accentColor
                size: Theme.iconSize - 6
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: 6
                height: 6
                radius: 3
                color: root.accentColor
                opacity: running.value ? 1.0 : (root.paused ? 0.65 : 0.35)
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.compactTime()
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.showLapCountInPill && lapsModel.count > 0
                text: "L" + lapsModel.count
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeXSmall
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 2

            DankIcon {
                visible: root.showIcon
                name: running.value ? "timer" : "timer"
                color: root.accentColor
                size: Theme.iconSize - 6
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: {
                    const time = root.compactTime();
                    if (time.length > 5)
                        return time.substring(0, 5);
                    return time;
                }
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeXSmall
                font.weight: Font.DemiBold
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: "Stopwatch"
            detailsText: root.statusLabel + (lapsModel.count > 0 ? " • " + lapsModel.count + " laps" : "")
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingM

                Rectangle {
                    width: parent.width
                    height: heroColumn.implicitHeight + Theme.spacingL * 2
                    radius: Theme.cornerRadius * 2
                    color: Qt.rgba(Theme.surfaceContainerHigh.r, Theme.surfaceContainerHigh.g, Theme.surfaceContainerHigh.b, 0.74)
                    border.width: 1
                    border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, running.value ? 0.45 : 0.22)

                    Behavior on border.color {
                        ColorAnimation { duration: 180 }
                    }

                    Column {
                        id: heroColumn
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        spacing: Theme.spacingM

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM

                            Rectangle {
                                width: 44
                                height: 44
                                radius: 22
                                color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
                                anchors.verticalCenter: parent.verticalCenter

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "timer"
                                    size: 24
                                    color: root.accentColor
                                }
                            }

                            Column {
                                width: parent.width - 44 - Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                StyledText {
                                    width: parent.width
                                    text: root.formatTime(elapsedMs.value, true)
                                    color: Theme.surfaceText
                                    font.pixelSize: 38
                                    font.weight: Font.Bold
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                StyledText {
                                    width: parent.width
                                    text: root.statusLabel
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }

                        Row {
                            id: controlsRow
                            width: parent.width
                            spacing: Theme.spacingS

                            readonly property real actionWidth: (width - spacing * 2) / 3

                            DankButton {
                                width: controlsRow.actionWidth
                                height: 40
                                text: root.primaryActionText()
                                iconName: root.primaryActionIcon()
                                onClicked: root.primaryAction()
                            }

                            DankButton {
                                width: controlsRow.actionWidth
                                height: 40
                                text: "Lap"
                                iconName: "flag"
                                enabled: running.value
                                opacity: enabled ? 1.0 : 0.45
                                onClicked: root.addLap()
                            }

                            DankButton {
                                width: controlsRow.actionWidth
                                height: 40
                                text: "Reset"
                                iconName: "refresh"
                                enabled: root.hasTime || lapsModel.count > 0
                                opacity: enabled ? 0.82 : 0.38
                                onClicked: root.resetStopwatch()
                            }
                        }

                        Row {
                            id: secondaryRow
                            width: parent.width
                            spacing: Theme.spacingS

                            readonly property real actionWidth: (width - spacing) / 2

                            DankButton {
                                width: secondaryRow.actionWidth
                                height: 36
                                text: copiedPulse.running ? "Copied" : "Copy Time"
                                iconName: copiedPulse.running ? "check" : "content_copy"
                                onClicked: root.copyCurrentTime()
                            }

                            DankButton {
                                width: secondaryRow.actionWidth
                                height: 36
                                text: "Clear Laps"
                                iconName: "delete_sweep"
                                enabled: lapsModel.count > 0
                                opacity: enabled ? 0.72 : 0.35
                                onClicked: root.clearLaps()
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 220
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.72)
                    border.width: 1
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.35)
                    clip: true

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Laps"
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.DemiBold
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: lapsModel.count + ""
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.35)
                        }

                        Item {
                            width: parent.width
                            height: parent.height - y

                            StyledText {
                                anchors.centerIn: parent
                                visible: lapsModel.count === 0
                                text: "No laps yet"
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            Flickable {
                                anchors.fill: parent
                                visible: lapsModel.count > 0
                                contentHeight: lapColumn.implicitHeight
                                boundsBehavior: Flickable.StopAtBounds
                                clip: true

                                Column {
                                    id: lapColumn
                                    width: parent.width
                                    spacing: Theme.spacingXS

                                    Repeater {
                                        model: lapsModel

                                        Rectangle {
                                            required property int number
                                            required property string time
                                            required property string delta
                                            required property int index

                                            width: lapColumn.width
                                            height: 40
                                            radius: Theme.cornerRadius
                                            color: index % 2 === 0
                                                   ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.18)
                                                   : "transparent"

                                            Row {
                                                anchors.fill: parent
                                                anchors.leftMargin: Theme.spacingS
                                                anchors.rightMargin: Theme.spacingS
                                                spacing: Theme.spacingS

                                                StyledText {
                                                    width: 48
                                                    text: "#" + number
                                                    color: Theme.surfaceVariantText
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                StyledText {
                                                    width: parent.width - 48 - 76 - Theme.spacingS * 2
                                                    text: time
                                                    color: Theme.surfaceText
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    font.weight: Font.DemiBold
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                StyledText {
                                                    width: 76
                                                    text: delta
                                                    color: Theme.primary
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    horizontalAlignment: Text.AlignRight
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
