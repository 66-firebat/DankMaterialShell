import QtQuick
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // ── State ────────────────────────────────────────────────────────────────

    property bool recording: false
    property string videoPath: ""
    property real startTime: 0
    property string elapsedText: "00:00"
    property string fileSizeText: "0.0 MB"

    // ── Colors ──────────────────────────────────────────────────────────────

    readonly property color idleFg:  "#ff4400"
    readonly property color recFg:   "#1bfd9c"

    // ── Startup Detection ────────────────────────────────────────────────────
    // Checks if wf-recorder survived a shell restart by looking for the
    // process and its most recent video file.

    Process {
        id: startupDetector
        command: [
            "bash", "-c",
            "pid=$(pgrep -x wf-recorder) && " +
            "[ -n \"$pid\" ] && " +
            "ls -lt \"$HOME/Videos/rec_*.mp4\" 2>/dev/null | head -1 | awk '{print $NF}' || true"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var path = this.text.trim();
                if (path.length > 0) {
                    root.videoPath = path;
                    root.startTime = new Date().getTime();
                    root.recording = true;
                    root.fileSizeText = "N/A";

                    // Prime the file-size checker command
                    fileSizeChecker.command = ["bash", "-c",
                        "stat -c %s \"" + path + "\" 2>/dev/null || echo N/A"];

                    fileSizeChecker.running = true;
                    elapsedTimer.start();
                }
            }
        }
    }

    // ── IPC Handlers ─────────────────────────────────────────────────────────
    // Called from keymaps.lua via:
    //   dms ipc call widget openQuery wfRecorderIndicator "<video-path>"
    //   dms ipc call widget toggleQuery wfRecorderIndicator "stop"

    function openWithQuery(query: string): void {
        // Start recording — query is the video file path
        if (!query || query.length === 0) return;

        root.videoPath = query;
        root.startTime = new Date().getTime();
        root.recording = true;

        // Prime the file-size checker command
        fileSizeChecker.command = ["bash", "-c",
            "stat -c %s \"" + query + "\" 2>/dev/null || echo N/A"];

        fileSizeChecker.running = true;
        elapsedTimer.start();
    }

    function toggleWithQuery(query: string): void {
        // Stop recording — keep elapsed time and file size frozen at last values,
        // only change icon and color back to idle state
        root.recording = false;

        fileSizeChecker.running = false;
        elapsedTimer.stop();
    }

    // ── Elapsed Timer (1-second resolution / MM:SS display) ─────────────────
    // Also triggers a file size check on each tick for once-per-second polling.

    Timer {
        id: elapsedTimer
        interval: 1000
        running: false
        repeat: true
        onTriggered: {
            var elapsedSec = Math.floor((new Date().getTime() - root.startTime) / 1000);
            var minutes = Math.floor(elapsedSec / 60);
            var seconds = elapsedSec % 60;

            root.elapsedText =
                String(minutes).padStart(2, '0') + ":" +
                String(seconds).padStart(2, '0');

            // Trigger a file size check once per second
            if (root.recording && !fileSizeChecker.running) {
                fileSizeChecker.running = true;
            }
        }
    }

    // ── File Size Polling (timer-driven, once per second) ───────────────────
    // Started by openWithQuery / startupDetector for the initial check,
    // then re-triggered by elapsedTimer.onTriggered every 1 second.

    Process {
        id: fileSizeChecker
        command: ["bash", "-c", "echo 0"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim();
                if (text.length > 0 && text !== "N/A" && text !== "0") {
                    var bytes = parseFloat(text);
                    if (!isNaN(bytes) && bytes > 0) {
                        root.fileSizeText = (bytes / 1048576).toFixed(1) + " MB";
                    }
                } else if (text === "N/A") {
                    root.fileSizeText = "N/A";
                }
            }
        }
    }

    // ── Pills ───────────────────────────────────────────────────────────────

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            Text {
                text: root.recording ? "󰙧" : "󰣿"
                font.family: "FreeSans"
                font.pixelSize: Theme.iconSize
                font.weight: Font.Normal
                color: root.recording ? root.recFg : root.idleFg
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.elapsedText + " • " + root.fileSizeText
                font.family: "FreeSans"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Normal
                color: root.recording ? root.recFg : root.idleFg
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            Text {
                text: root.recording ? "󰙧" : "󰣿"
                font.family: "FreeSans"
                font.pixelSize: Theme.iconSize
                font.weight: Font.Normal
                color: root.recording ? root.recFg : root.idleFg
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.elapsedText
                font.family: "FreeSans"
                font.pixelSize: Theme.fontSizeTiny
                font.weight: Font.Normal
                color: root.recording ? root.recFg : root.idleFg
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.fileSizeText
                font.family: "FreeSans"
                font.pixelSize: Theme.fontSizeTiny
                font.weight: Font.Normal
                color: root.recording ? root.recFg : root.idleFg
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
