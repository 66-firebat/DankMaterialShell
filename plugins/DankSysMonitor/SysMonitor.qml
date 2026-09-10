import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property int updateIntervalMs: pluginData.updateInterval ?? 3000
    property bool showTemp: pluginData.showTemp ?? true

    // EWMA smoothing factor (0..1). Lower = calmer/slower, higher = more responsive.
    readonly property real smoothingAlpha: 0.5

    property real cpuPercent: 0
    property var cpuCores: []
    property int coreCount: 0
    property real memPercent: 0
    property real memUsedGb: 0
    property real memTotalGb: 0
    property real load1: 0
    property string cpuTemp: ""

    // Damped (smoothed) state used for display so readings glide instead of snap.
    property var smoothCores: []
    property real smoothCpu: 0
    property bool _primed: false

    // One usage color ("#rrggbb") per core: linear interpolation between
    // LOW_COLOR (#2b2b2b) and HIGH_COLOR (#ff4400) by the damped usage
    // normalized to the busiest core at this sample (max -> #ff4400, 0 -> #2b2b2b).
    property var coreColors: []

    readonly property string avgCpuText: root.smoothCpu.toFixed(1) + "%"

    // low = #2b2b2b, high = #ff4400
    function usageHex(norm) {
        const t = Math.max(0, Math.min(1, norm))
        function channel(low, high) {
            const v = Math.round(low + (high - low) * t)
            let h = v.toString(16)
            if (h.length < 2)
                h = "0" + h
            return h
        }
        // 0x2b = 43, 0xff = 255, 0x44 = 68, 0x00 = 0
        return "#" + channel(43, 255) + channel(43, 68) + channel(43, 0)
    }

    function damp(prev, target) {
        if (!root._primed || prev === undefined || prev === null)
            return target
        return prev + root.smoothingAlpha * (target - prev)
    }

    function refreshCoreBar() {
        const cores = root.smoothCores || []
        let max = 0
        for (let i = 0; i < cores.length; i++) {
            const v = Number(cores[i]) || 0
            if (v > max)
                max = v
        }
        const colors = []
        for (let i = 0; i < cores.length; i++) {
            const v = Number(cores[i]) || 0
            // normalized to the max core usage right now: busiest core -> 1
            const norm = max > 0 ? Math.min(1, v / max) : 0
            colors.push(root.usageHex(norm))
        }
        root.coreColors = colors
    }

    function poll() {
        Proc.runCommand(
            "dankSysMonitor.poll",
            // sysmon.sh ships without the executable bit on nix-managed (store)
            // installs, and `bash -c <path>` execs the file directly (fails with
            // exit code 126 / "Permission denied"). Invoke bash explicitly so the
            // script is read as an argument and runs regardless of file mode.
            ["bash", "-c", "bash \"$HOME/.config/DankMaterialShell/plugins/DankSysMonitor/sysmon.sh\""],
            (stdout, exitCode) => {
                if (exitCode !== 0 || !stdout || !stdout.trim())
                    return
                try {
                    const data = JSON.parse(stdout.trim())
                    const rawCores = data.cpu_cores || []
                    const rawPct = Number(data.cpu_percent) || 0

                    // Damp per-core usage and the aggregate percentage.
                    const damped = []
                    for (let i = 0; i < rawCores.length; i++) {
                        const t = Number(rawCores[i]) || 0
                        const s = i < root.smoothCores.length ? Number(root.smoothCores[i]) : t
                        damped.push(root.damp(s, t))
                    }
                    root.smoothCores = damped
                    root.smoothCpu = root.damp(root.smoothCpu, rawPct)
                    root._primed = true

                    root.cpuPercent = rawPct
                    root.cpuCores = rawCores
                    root.coreCount = data.core_count || rawCores.length
                    root.memPercent = data.mem_percent
                    root.memUsedGb = data.mem_used_gb
                    root.memTotalGb = data.mem_total_gb
                    root.load1 = data.load1
                    root.cpuTemp = data.cpu_temp
                    root.refreshCoreBar()
                } catch (e) {
                    console.warn("dankSysMonitor: parse failed:", e)
                }
            },
            50,
            5000,
            root
        )
    }

    Timer {
        interval: root.updateIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.poll()
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            StyledText {
                text: root.avgCpuText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            // One █ per core; colors cross-fade between samples for a fluid look.
            Row {
                Repeater {
                    model: root.coreColors.length
                    Text {
                        text: "█"
                        color: root.coreColors[index] ?? "#000000"
                        font.pixelSize: Theme.fontSizeMedium
                        Behavior on color {
                            ColorAnimation {
                                duration: 2000
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }
                }
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            StyledText {
                text: root.avgCpuText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.memPercent.toFixed(1) + "%"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondary
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            headerText: "System Monitor"
            detailsText: "Refreshed every " + (root.updateIntervalMs / 1000) + "s · " + root.coreCount + " cores detected"
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingS

                StyledText {
                    text: "CPU (avg): " + root.smoothCpu.toFixed(1) + "%" +
                          (root.showTemp && root.cpuTemp !== "" ? "  (" + root.cpuTemp + "°C)" : "") +
                          "  load1: " + root.load1.toFixed(2)
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                }

                Repeater {
                    model: root.smoothCores.length
                    Row {
                        spacing: Theme.spacingXS
                        Text {
                            text: "█"
                            color: index < root.coreColors.length ? root.coreColors[index] : "#808080"
                            font.pixelSize: Theme.fontSizeSmall
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: "core " + index + ": " + (Number(root.smoothCores[index]) || 0).toFixed(1) + "%"
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                StyledText {
                    text: "RAM: " + root.memUsedGb.toFixed(2) + " / " + root.memTotalGb.toFixed(2) + " GB (" + root.memPercent.toFixed(1) + "%)"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                }
            }
        }
    }

    popoutWidth: 340
    popoutHeight: 320
}
