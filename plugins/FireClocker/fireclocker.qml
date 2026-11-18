import QtQuick
import qs.Common
import qs.Services
import qs.Modules.Plugins
import qs.Widgets

// FireClocker desktop card.
//
// Semicircle gauge (`∩`, flat edge at the bottom) with the controls sitting on
// the flat edge. Progress fills symmetrically outward from 12 o'clock in both
// directions. There is no card surface: only the arc track, the buttons and
// (optionally) the time are drawn, so the desktop/wallpaper shows through.
//
// `cardScalePct` drives the real widget size through the desktop surface's
// transient requestResize() hook, so the widget can stay tiny by default.
DesktopPluginComponent {
    id: root

    // ── Base design at scale 1.0 ─────────────────────────────────────────────
    readonly property real baseW: 136
    readonly property real baseH: 78
    readonly property real panelH: 142
    readonly property real expandW: baseW
    readonly property real expandH: baseH + panelH

    // ── Settings (instance config, falling back to the plugin's global settings) ──
    property int cardScalePct: 100
    property int surfaceOpacityPct: 85
    property int contentOpacityPct: 100
    property int arcThicknessPx: 7
    property bool showTimeAlways: false
    property bool showModeIcon: true
    property bool hoverExpand: true
    // "above" | "below" — which side of the gauge the hover panel opens on.
    property string panelPosition: "above"

    // Forwarded to the core. Kept as real properties (not getData() calls in the
    // core's bindings) because getData() closes over instanceData, which QML
    // cannot track as a binding dependency.
    property int defaultTimerMinutes: 25
    property int pomodoroWorkMinutes: 25
    property int pomodoroShortBreakMinutes: 5
    property int pomodoroLongBreakMinutes: 15
    property int pomodoroSessionsBeforeLongBreak: 4
    property bool autoStartBreaks: true
    property string soundPath: ""
    property bool useSystemSound: true
    property bool showNotifications: true
    property bool notifyMissedWhileAway: true
    property bool autoDND: false

    readonly property real scale: Math.max(0.4, Math.min(3.0, cardScalePct / 100))
    readonly property real surfaceAlpha: Math.max(0, Math.min(1, surfaceOpacityPct / 100))
    readonly property real contentAlpha: Math.max(0, Math.min(1, contentOpacityPct / 100))

    property bool expanded: false

    function syncSettings() {
        cardScalePct = Math.round(Number(root.getData("cardScalePct", 100)) || 100);
        surfaceOpacityPct = Math.round(Number(root.getData("surfaceOpacityPct", 85)));
        contentOpacityPct = Math.round(Number(root.getData("contentOpacityPct", 100)));
        arcThicknessPx = Math.round(Number(root.getData("arcThicknessPx", 7)));
        showTimeAlways = root.getData("showTimeAlways", false) === true;
        showModeIcon = root.getData("showModeIcon", true) !== false;
        hoverExpand = root.getData("hoverExpand", true) !== false;
        panelPosition = String(root.getData("panelPosition", "above"));

        defaultTimerMinutes = Math.round(Number(root.getData("defaultTimerMinutes", 25)) || 25);
        pomodoroWorkMinutes = Math.round(Number(root.getData("pomodoroWorkMinutes", 25)) || 25);
        pomodoroShortBreakMinutes = Math.round(Number(root.getData("pomodoroShortBreakMinutes", 5)) || 5);
        pomodoroLongBreakMinutes = Math.round(Number(root.getData("pomodoroLongBreakMinutes", 15)) || 15);
        pomodoroSessionsBeforeLongBreak = Math.round(Number(root.getData("pomodoroSessionsBeforeLongBreak", 4)) || 4);
        autoStartBreaks = root.getData("autoStartBreaks", true) !== false;
        soundPath = String(root.getData("soundPath", ""));
        useSystemSound = root.getData("useSystemSound", true) !== false;
        showNotifications = root.getData("showNotifications", true) !== false;
        notifyMissedWhileAway = root.getData("notifyMissedWhileAway", true) !== false;
        autoDND = root.getData("autoDND", false) === true;
    }

    // Size is owned by `scale`, not by drag-resize.
    // `resizable` is read by DesktopWidgetContent to decide whether to offer drag
    // handles; it is not declared on DesktopPluginComponent, so declare it here.
    property bool resizable: false
    minWidth: baseW * scale
    minHeight: baseH * scale
    widgetWidth: baseW * scale
    widgetHeight: baseH * scale

    function applySize() {
        if (!root.requestResize)
            return;
        root.requestResize((expanded ? expandW : baseW) * scale, (expanded ? expandH : baseH) * scale);
    }

    onExpandedChanged: applySize()
    onCardScalePctChanged: applySize()
    onRequestResizeChanged: applySize()

    Component.onCompleted: {
        syncSettings();
        applySize();
    }

    Connections {
        target: root
        function onInstanceDataChanged() {
            root.syncSettings();
        }
        function onPluginServiceChanged() {
            root.syncSettings();
        }
    }

    Connections {
        target: PluginService
        function onPluginDataChanged(pid) {
            if (pid === root.pluginId)
                root.syncSettings();
        }
    }

    FireClockerCore {
        id: core
        defaultTimerMinutes: root.defaultTimerMinutes
        pomodoroWorkMinutes: root.pomodoroWorkMinutes
        pomodoroShortBreakMinutes: root.pomodoroShortBreakMinutes
        pomodoroLongBreakMinutes: root.pomodoroLongBreakMinutes
        pomodoroSessionsBeforeLongBreak: root.pomodoroSessionsBeforeLongBreak
        autoStartBreaks: root.autoStartBreaks
        soundPath: root.soundPath
        useSystemSound: root.useSystemSound
        showNotifications: root.showNotifications
        notifyMissedWhileAway: root.notifyMissedWhileAway
        autoDND: root.autoDND
    }

    // One binding key drives every repaint trigger.
    readonly property string paintKey: [core.progress, core.modeColor, surfaceOpacityPct, arcThicknessPx, scale].join("|")

    // ── Hover handling: expand in place, collapse on leave ───────────────────
    HoverHandler {
        id: hoverHandler
        enabled: root.hoverExpand
        onHoveredChanged: {
            if (hovered) {
                collapseTimer.stop();
                root.expanded = true;
            } else {
                collapseTimer.restart();
            }
        }
    }

    Timer {
        id: collapseTimer
        interval: 260
        repeat: false
        onTriggered: root.expanded = false
    }

    // ── The gauge (arc + controls) ────────────────────────────────────────────
    // The widget window can only grow downward, so when the panel opens "above"
    // the gauge is pinned to the *bottom* of the window: DMS clamps a widget's
    // y to keep it on screen, which turns the extra height into upward growth
    // when the widget sits at/near the bottom edge, leaving the arc where it is.
    readonly property bool panelAbove: panelPosition !== "below"

    Item {
        id: gauge
        x: Math.round((root.widgetWidth - width) / 2)
        y: (root.expanded && root.panelAbove)
            ? Math.max(0, root.widgetHeight - root.baseH * root.scale)
            : 0
        width: root.baseW * root.scale
        height: root.baseH * root.scale

        Canvas {
            id: arc
            anchors.fill: parent

            property string paintKey: root.paintKey
            onPaintKeyChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                const s = root.scale;
                const stroke = Math.max(1.5, root.arcThicknessPx * s);
                const inset = stroke / 2 + 1;
                const cx = width / 2;
                const cy = height - inset;
                const r = Math.max(4, Math.min(cx - inset, cy - inset));

                ctx.lineWidth = stroke;
                ctx.lineCap = "round";

                // Track: the full semicircle, dimmed by the surface opacity setting.
                const track = Theme.surfaceText;
                ctx.strokeStyle = Qt.rgba(track.r, track.g, track.b, root.surfaceAlpha * 0.28);
                ctx.beginPath();
                ctx.arc(cx, cy, r, Math.PI, 2 * Math.PI);
                ctx.stroke();

                // Progress: fills from 12 o'clock outward, symmetrically.
                const p = Math.max(0, Math.min(1, core.progress));
                if (p > 0.002) {
                    const halfAngle = p * Math.PI / 2;
                    const col = core.modeColor;
                    ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, root.surfaceAlpha);
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 1.5 * Math.PI - halfAngle, 1.5 * Math.PI + halfAngle);
                    ctx.stroke();
                }
            }
        }

        // Optional always-visible time, inside the arc above the buttons.
        StyledText {
            id: inlineTime
            visible: root.showTimeAlways
            text: core.formatTimeShort(core.remainingMs)
            color: core.modeColor
            opacity: root.contentAlpha
            font.pixelSize: Math.round(15 * root.scale)
            font.weight: Font.Medium
            isMonospace: true
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(0, parent.height - controls.height - implicitHeight - 8 * root.scale)
        }

        // Controls, sitting on the flat edge.
        Row {
            id: controls
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - height - 5 * root.scale
            spacing: 9 * root.scale

            Item {
                visible: root.showModeIcon
                width: 20 * root.scale
                height: 30 * root.scale

                DankIcon {
                    anchors.centerIn: parent
                    name: core.modeIcons[core.currentMode] || "timer"
                    size: Math.round(17 * root.scale)
                    color: core.modeColor
                    opacity: root.contentAlpha
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: core.cycleMode()
                }
            }

            Rectangle {
                width: 30 * root.scale
                height: width
                radius: width / 2
                color: Qt.rgba(core.modeColor.r, core.modeColor.g, core.modeColor.b, 0.16 * root.contentAlpha)
                border.width: 1
                border.color: Qt.rgba(core.modeColor.r, core.modeColor.g, core.modeColor.b, 0.55 * root.contentAlpha)

                DankIcon {
                    anchors.centerIn: parent
                    name: core.isRunning ? "pause" : "play_arrow"
                    size: Math.round(17 * root.scale)
                    color: core.modeColor
                    opacity: root.contentAlpha
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onClicked: core.startPause()
                }
            }

            Rectangle {
                width: 30 * root.scale
                height: width
                radius: width / 2
                color: Qt.rgba(core.modeColor.r, core.modeColor.g, core.modeColor.b, 0.10 * root.contentAlpha)
                border.width: 1
                border.color: Qt.rgba(core.modeColor.r, core.modeColor.g, core.modeColor.b, 0.38 * root.contentAlpha)

                DankIcon {
                    anchors.centerIn: parent
                    name: "stop"
                    size: Math.round(15 * root.scale)
                    color: core.modeColor
                    opacity: root.contentAlpha
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onClicked: core.resetStop()
                }
            }
        }
    }

    // ── Hover panel ──────────────────────────────────────────────────────────
    Rectangle {
        id: panel
        visible: root.expanded
        x: 0
        y: root.panelAbove ? 0 : Math.round(root.baseH * root.scale)
        width: root.widgetWidth
        height: Math.max(0, Math.round(root.panelH * root.scale))
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        opacity: 0.96
        border.width: 1
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
        clip: true

        Column {
            id: panelColumn
            anchors.fill: parent
            anchors.margins: 6
            spacing: 3

            Row {
                width: parent.width
                height: 20

                Item {
                    width: timeText.implicitWidth
                    height: parent.height

                    StyledText {
                        id: timeText
                        anchors.verticalCenter: parent.verticalCenter
                        text: core.formatTimeShort(core.remainingMs)
                        font.pixelSize: Math.round(17 * Math.min(1.5, root.scale))
                        font.weight: Font.Bold
                        isMonospace: true
                        color: core.modeColor
                    }
                }

                Item {
                    width: phaseText.implicitWidth
                    height: parent.height
                    visible: core.currentMode === "pomodoro"

                    StyledText {
                        id: phaseText
                        anchors.verticalCenter: parent.verticalCenter
                        text: core.pomodoroSession + " \u00b7 " + core.phaseLabel
                        font.pixelSize: Math.max(8, Theme.fontSizeSmall - 4)
                        color: Theme.surfaceVariantText
                    }
                }
            }

            Row {
                width: parent.width
                height: 22
                spacing: 3

                Repeater {
                    model: [
                        { key: "timer", icon: "timer" },
                        { key: "stopwatch", icon: "timer_10" },
                        { key: "pomodoro", icon: "timelapse" }
                    ]

                    delegate: Rectangle {
                        required property var modelData

                        width: (panelColumn.width - 6) / 3
                        height: 22
                        radius: Theme.cornerRadius
                        color: core.currentMode === modelData.key
                            ? Theme.primary : Theme.surfaceContainerHighest

                        DankIcon {
                            anchors.centerIn: parent
                            name: modelData.icon
                            size: Math.round(14 * Math.min(1.5, root.scale))
                            color: core.currentMode === modelData.key ? Theme.onPrimary : Theme.surfaceText
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: core.setMode(modelData.key)
                        }
                    }
                }
            }

            // Timer presets (idle) and the pomodoro skip action share this slot.
            Item {
                width: parent.width
                height: 47

                Flow {
                    width: parent.width
                    spacing: 3
                    visible: core.currentMode === "timer" && core.isIdle

                    Repeater {
                        model: [5, 10, 15, 20, 25, 30]

                        delegate: Rectangle {
                            required property int modelData

                            width: (panelColumn.width - 6) / 3
                            height: 22
                            radius: Theme.cornerRadius
                            color: Theme.primaryContainer

                            StyledText {
                                anchors.centerIn: parent
                                text: modelData + "m"
                                font.pixelSize: Math.max(8, Theme.fontSizeSmall - 4)
                                color: Theme.onPrimaryContainer
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: core.startTimer(modelData)
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 22
                    radius: Theme.cornerRadius
                    color: Theme.tertiaryContainer
                    visible: core.currentMode === "pomodoro" && core.pomodoroPhase !== "work" && !core.isIdle

                    StyledText {
                        anchors.centerIn: parent
                        text: "Skip to next phase"
                        font.pixelSize: Math.max(8, Theme.fontSizeSmall - 3)
                        color: Theme.onTertiaryContainer
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: core.skipPhase()
                    }
                }
            }

            Row {
                width: parent.width
                height: 26
                spacing: 3
                visible: core.currentMode === "timer" && core.isIdle

                DankTextField {
                    id: panelInput
                    width: parent.width - panelSet.width - 3
                    height: 26
                    placeholderText: "Min\u2026"
                    validator: IntValidator { bottom: 1; top: 1440 }
                    onAccepted: panelSet.clicked()
                }

                Rectangle {
                    id: panelSet
                    width: 34
                    height: 26
                    radius: Theme.cornerRadius
                    color: Theme.primary

                    StyledText {
                        anchors.centerIn: parent
                        text: "Set"
                        font.pixelSize: Math.max(8, Theme.fontSizeSmall - 4)
                        color: Theme.onPrimary
                    }

                    function clicked() {
                        const mins = parseInt(panelInput.text);
                        if (!isNaN(mins) && mins > 0) {
                            core.startTimer(mins);
                            panelInput.text = "";
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panelSet.clicked()
                    }
                }
            }
        }
    }
}
