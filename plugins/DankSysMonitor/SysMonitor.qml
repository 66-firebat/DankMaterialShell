import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property int updateIntervalMs: pluginData.updateInterval ?? 2000
    property int numCoresToShow: pluginData.numCores ?? 4
    property string iconFontFamily: pluginData.iconFontFamily ?? ""   // "" = inherit theme font
    property bool showTemp: pluginData.showTemp ?? true

    property real cpuPercent: 0
    property var cpuCores: []
    property int coreCount: 0
    property real memPercent: 0
    property real memUsedGb: 0
    property real memTotalGb: 0
    property real load1: 0
    property string cpuTemp: ""

    function cpuBandIcon(pct) {
        if (pct >= 1.0) return "󰪥"
        var band = Math.floor(pct / 0.125)
        if (band < 0) band = 0
        if (band > 7) band = 7
        const icons = ["󰄰", "󰪞", "󰪟", "󰪠", "󰪡", "󰪢", "󰪣", "󰪤"]
        return icons[band]
    }

    function coreIconRow() {
        const n = Math.min(root.numCoresToShow, root.cpuCores.length)
        let s = ""
        for (let i = 0; i < n; i++)
            s += root.cpuBandIcon(root.cpuCores[i] / 100)
        return s
    }

    function poll() {
        Proc.runCommand(
            "dankSysMonitor.poll",
            ["bash", "-c", "$HOME/.config/DankMaterialShell/plugins/DankSysMonitor/sysmon.sh"],
            (stdout, exitCode) => {
                if (exitCode !== 0 || !stdout || !stdout.trim())
                    return
                try {
                    const data = JSON.parse(stdout.trim())
                    root.cpuPercent = data.cpu_percent
                    root.cpuCores = data.cpu_cores
                    root.coreCount = data.core_count
                    root.memPercent = data.mem_percent
                    root.memUsedGb = data.mem_used_gb
                    root.memTotalGb = data.mem_total_gb
                    root.load1 = data.load1
                    root.cpuTemp = data.cpu_temp
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
            DankIcon {
                name: "memory"
                size: root.iconSize
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: root.coreIconRow()
                font.family: root.iconFontFamily
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: root.memBandIconText()
                font.family: root.iconFontFamily
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.secondary
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    function memBandIconText() {
        return root.cpuBandIcon(root.memPercent / 100)
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS
            StyledText {
                text: root.cpuBandIcon(root.cpuPercent / 100)
                font.family: root.iconFontFamily
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                text: root.memBandIconText()
                font.family: root.iconFontFamily
                font.pixelSize: Theme.fontSizeMedium
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
                    text: "CPU (avg): " + root.cpuPercent.toFixed(1) + "%" +
                          (root.showTemp && root.cpuTemp !== "" ? "  (" + root.cpuTemp + "°C)" : "") +
                          "  load1: " + root.load1.toFixed(2)
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                }

                Repeater {
                    model: root.cpuCores
                    StyledText {
                        text: "core " + index + ": " + root.cpuBandIcon(modelData / 100) + " " + modelData.toFixed(1) + "%"
                        font.family: root.iconFontFamily
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeSmall
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