import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // ── Configuration (plugin settings) ──────────────────────────────────────
    property int updateIntervalMs: pluginData.updateInterval ?? 1000
    property int readoutIntervalMs: Math.max(5000, pluginData.readoutInterval ?? 5000)
    property int animationDuration: pluginData.animationDuration ?? 800
    property string animationEasing: pluginData.animationEasing ?? "OutQuad"
    property int fontSize: pluginData.fontSize ?? Math.max(8, Math.round(Theme.fontSizeMedium) - 2)
    property int barFontSize: pluginData.barFontSize ?? Math.round(Theme.fontSizeMedium)

    // ── Rolling window: 16 cells × 30 s = 480 s (8 min) ──────────────────────
    readonly property int bucketMs: 30000
    readonly property int bucketCount: 16
    readonly property int completedKeep: bucketCount - 1

    // ── Cell height levels: lower blocks grow upward ─────────────────────────
    readonly property var boxGlyphs: ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

    // Every cell gets the same width (measured from a full block) so the
    // widget's total width stays constant while the window fills up.
    TextMetrics {
        id: blockMetrics
        text: "█"
        font.family: "FreeMono" // Free monospace family (there is no "FreeSans Mono")
        font.pixelSize: root.barFontSize
    }
    readonly property real cellWidth: Math.ceil(blockMetrics.advanceWidth)

    readonly property int filledCells: root.powerBuckets.length + (root.bucketSampleCount > 0 ? 1 : 0)

    // ── Live values ───────────────────────────────────────────────────────────
    property real latestPower: 0
    property real latestTemp: 0

    // ── Current 30 s bucket accumulator ──────────────────────────────────────
    property real bucketPowerSum: 0
    property real bucketTempSum: 0
    property int bucketSampleCount: 0
    property double bucketStart: 0

    // ── Completed buckets (oldest → newest) ──────────────────────────────────
    property var powerBuckets: []
    property var tempBuckets: []

    readonly property real currentAvgPower: root.bucketSampleCount > 0 ? root.bucketPowerSum / root.bucketSampleCount : 0
    readonly property real currentAvgTemp: root.bucketSampleCount > 0 ? root.bucketTempSum / root.bucketSampleCount : 0

    // Watts/temp text refreshes on its own (slower) cadence so it does not
    // flicker every sample; the bar cells still update live.
    property real shownPower: 0
    property real shownTemp: 0

    // Display window: last 15 completed buckets + the live bucket, left-padded
    // so the newest cell always sits at the right edge.
    readonly property var powerWindow: root.buildWindow(root.powerBuckets, root.currentAvgPower)
    readonly property var tempWindow: root.buildWindow(root.tempBuckets, root.currentAvgTemp)
    readonly property real windowMaxPower: root.maxOf(root.powerWindow)
    readonly property real windowMaxTemp: root.maxOf(root.tempWindow)

    // Nerd Font separator: U+F44D. FreeSans has no glyph for it, so it renders
    // in a Nerd font; watts/temp digits stay FreeSans.
    readonly property string arrowIcon: "\uF44D"

    readonly property int animationEasingValue: root.easingValue()

    // ── Helpers ───────────────────────────────────────────────────────────────
    function buildWindow(completed, current) {
        const vals = completed.slice(Math.max(0, completed.length - root.completedKeep))
        vals.push(current)
        const out = []
        for (let i = vals.length; i < root.bucketCount; i++)
            out.push(null)
        return out.concat(vals)
    }

    function maxOf(vals) {
        let m = -Infinity
        for (let i = 0; i < vals.length; i++) {
            const v = vals[i]
            if (v !== null && v !== undefined && v > m)
                m = v
        }
        return m === -Infinity ? 0 : m
    }

    // Height: normalized to the max power in the current 480 s window.
    function glyphFor(power, maxPower) {
        if (power === null || power === undefined || power <= 0 || maxPower <= 0)
            return " "
        const norm = Math.min(1, power / maxPower)
        const level = Math.max(1, Math.ceil(norm * root.boxGlyphs.length))
        return root.boxGlyphs[level - 1]
    }

    // Color: normalized to the max temp in the current 480 s window.
    function colorFor(temp, maxTemp) {
        if (temp === null || temp === undefined || maxTemp <= 0)
            return "#2b2b2b"
        const t = Math.max(0, Math.min(1, temp / maxTemp))
        return root.lerpHex("#2b2b2b", "#ff4400", t)
    }

    function lerpHex(a, b, t) {
        const ca = root.hexRgb(a)
        const cb = root.hexRgb(b)
        let out = "#"
        for (let i = 0; i < 3; i++) {
            let v = Math.round(ca[i] + (cb[i] - ca[i]) * t)
            let h = v.toString(16)
            if (h.length < 2)
                h = "0" + h
            out += h
        }
        return out
    }

    function hexRgb(hex) {
        const s = hex.charAt(0) === "#" ? hex.substring(1) : hex
        return [parseInt(s.substring(0, 2), 16), parseInt(s.substring(2, 4), 16), parseInt(s.substring(4, 6), 16)]
    }

    function easingValue() {
        switch (root.animationEasing) {
        case "Linear": return Easing.Linear
        case "InQuad": return Easing.InQuad
        case "OutQuad": return Easing.OutQuad
        case "InOutQuad": return Easing.InOutQuad
        case "OutCubic": return Easing.OutCubic
        case "InOutCubic": return Easing.InOutCubic
        default: return Easing.OutQuad
        }
    }

    function accumulate(power, temp) {
        const now = Date.now()
        if (root.bucketStart === 0)
            root.bucketStart = now
        if (now - root.bucketStart >= root.bucketMs) {
            root.finalizeBucket()
            root.bucketStart = now
        }
        root.bucketPowerSum += power
        root.bucketTempSum += temp
        root.bucketSampleCount += 1
    }

    function finalizeBucket() {
        if (root.bucketSampleCount === 0)
            return
        let pb = root.powerBuckets.slice()
        let tb = root.tempBuckets.slice()
        pb.push(root.bucketPowerSum / root.bucketSampleCount)
        tb.push(root.bucketTempSum / root.bucketSampleCount)
        if (pb.length > root.completedKeep)
            pb = pb.slice(pb.length - root.completedKeep)
        if (tb.length > root.completedKeep)
            tb = tb.slice(tb.length - root.completedKeep)
        root.powerBuckets = pb
        root.tempBuckets = tb
        root.bucketPowerSum = 0
        root.bucketTempSum = 0
        root.bucketSampleCount = 0
    }

    function poll() {
        Proc.runCommand(
            "dankPowerMonitor.poll",
            // Explicit `bash <script>` so it runs even if the nix-managed store
            // copy lacks the executable bit (same lesson as DankSysMonitor).
            ["bash", "-c", "bash \"$HOME/.config/DankMaterialShell/plugins/DankPowerMonitor/powermon.sh\""],
            (stdout, exitCode) => {
                if (exitCode !== 0 || !stdout || !stdout.trim())
                    return
                try {
                    const data = JSON.parse(stdout.trim())
                    const p = (data.power_w === null || data.power_w === undefined) ? NaN : Number(data.power_w)
                    const t = (data.temp_c === null || data.temp_c === undefined) ? NaN : Number(data.temp_c)
                    if (isNaN(p))
                        return
                    root.latestPower = p
                    if (!isNaN(t))
                        root.latestTemp = t
                    root.accumulate(p, root.latestTemp)
                } catch (e) {
                    console.warn("dankPowerMonitor: parse failed:", e)
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

    Timer {
        interval: root.readoutIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.shownPower = root.currentAvgPower
            root.shownTemp = root.currentAvgTemp
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            // One vertical block per 30 s bucket: height = average power
            // (scaled to the window peak), color = average temp (scaled to the
            // window peak temp).
            Row {
                Repeater {
                    model: root.bucketCount
                    Text {
                        width: root.cellWidth
                        horizontalAlignment: Text.AlignHCenter
                        text: root.glyphFor(root.powerWindow[index], root.windowMaxPower)
                        color: root.colorFor(root.tempWindow[index], root.windowMaxTemp)
                        font.family: "FreeMono" // blocks only; readout stays FreeSans
                        font.pixelSize: root.barFontSize
                        Behavior on color {
                            ColorAnimation {
                                duration: root.animationDuration
                                easing.type: root.animationEasingValue
                            }
                        }
                    }
                }
            }

            Row {
                spacing: Theme.spacingXS

                StyledText {
                    text: root.shownPower.toFixed(1) + "W"
                    font.pixelSize: root.fontSize
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: root.arrowIcon
                    font.family: "JetBrainsMono Nerd Font" // FreeSans has no glyph for this
                    font.pixelSize: root.fontSize
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: root.shownTemp.toFixed(1) + "°C"
                    font.pixelSize: root.fontSize
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            headerText: "Power Monitor"
            detailsText: root.bucketCount + " × " + (root.bucketMs / 1000) + "s rolling window (" + (root.bucketCount * root.bucketMs / 1000) + "s)"
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingS

                StyledText {
                    text: "Power now: " + root.currentAvgPower.toFixed(1) + " W    peak: " + root.windowMaxPower.toFixed(1) + " W"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                }

                StyledText {
                    text: "Temp now: " + root.currentAvgTemp.toFixed(1) + " °C    peak: " + root.windowMaxTemp.toFixed(1) + " °C"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                }

                StyledText {
                    text: "Window filled: " + root.filledCells + "/" + root.bucketCount + " buckets"
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }

    popoutWidth: 360
    popoutHeight: 200
}
