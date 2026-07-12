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
    property string elapsedText: "00:00:00"
    property string fileSizeText: "0.0 MB"

    // ── Colors ──────────────────────────────────────────────────────────────

    readonly property color idleFg:  "#444444"
    readonly property color recFg:   "#ef4444"
    readonly property color bgColor: "#2b2b2b"

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

                    elapsedTimer.start();
                    fileSizeTimer.start();
                }
            }
        }
    }

    // ── IPC Handler (called from keymaps.lua via `qs ipc call ...`) ──────────

    IpcHandler {
        target: "wfRecorderIndicator"

        function startRecording(videoPath: string): void {
            root.videoPath = videoPath;
            root.startTime = new Date().getTime();
            root.recording = true;

            // Prime the file-size checker command
            fileSizeChecker.command = ["bash", "-c",
                "stat -c %s \"" + videoPath + "\" 2>/dev/null || echo N/A"];

            elapsedTimer.start();
            fileSizeTimer.start();
        }

        function stopRecording(): void {
            root.recording = false;
            root.elapsedText = "00:00:00";
            root.fileSizeText = "0.0 MB";

            elapsedTimer.stop();
            fileSizeTimer.stop();
        }
    }

    // ── Elapsed Timer (10ms / centisecond resolution) ───────────────────────

    Timer {
        id: elapsedTimer
        interval: 10
        running: false
        repeat: true
        onTriggered: {
            var elapsedMs = new Date().getTime() - root.startTime;
            var totalCs = Math.floor(elapsedMs / 10);       // 1 centisecond = 10ms
            var minutes  = Math.floor(totalCs / 6000);       // 6000 cs per minute
            var seconds  = Math.floor((totalCs % 6000) / 100);
            var cs       = totalCs % 100;

            root.elapsedText =
                String(minutes).padStart(2, '0') + ":" +
                String(seconds).padStart(2, '0') + ":" +
                String(cs).padStart(2, '0');
        }
    }

    // ── File Size Polling (every 5 seconds) ─────────────────────────────────

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
                } // else: keep existing value (e.g. initial "0.0 MB" or last known)
            }
        }
    }

    Timer {
        id: fileSizeTimer
        interval: 5000
        running: false
        repeat: true
        onTriggered: {
            // Restart the process to re-check file size
            fileSizeChecker.running = false;
            Qt.callLater(function() {
                fileSizeChecker.running = true;
            });
        }
    }

    // ── Pills ───────────────────────────────────────────────────────────────

    horizontalBarPill: Component {
        Rectangle {
            color: root.bgColor
            radius: 6
            height: 24
            implicitWidth: row.implicitWidth + 12

            Row {
                id: row
                spacing: 6
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 6

                Text {
                    text: root.recording ? "󱫤" : "󱫡"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: Theme.iconSize
                    color: root.recording ? root.recFg : root.idleFg
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: root.elapsedText + " • " + root.fileSizeText
                    font.pixelSize: Theme.fontSizeSmall
                    color: root.recording ? root.recFg : root.idleFg
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    verticalBarPill: Component {
        Rectangle {
            color: root.bgColor
            radius: 6
            width: 48
            height: col.implicitHeight + 10

            Column {
                id: col
                spacing: 2
                anchors.centerIn: parent

                Text {
                    text: root.recording ? "󱫤" : "󱫡"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: Theme.iconSize
                    color: root.recording ? root.recFg : root.idleFg
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: root.elapsedText
                    font.pixelSize: Theme.fontSizeTiny
                    color: root.recording ? root.recFg : root.idleFg
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: root.fileSizeText
                    font.pixelSize: Theme.fontSizeTiny
                    color: root.recording ? root.recFg : root.idleFg
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
