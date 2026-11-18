import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services

// FireClocker shared core.
//
// Hosted by both surfaces (bar pill and desktop card). All mutable state lives
// in PluginService.globalVars, so every surface sees the same timer and there is
// exactly one source of truth. `g` is a single reactive read of the plugin's
// var bag: PluginService.setGlobalVar() replaces the map object, which
// invalidates this binding and therefore every property derived from it.
//
// State API note: this intentionally uses the PluginService *singleton* for
// persistence, not the instance-scoped stub a desktop widget receives (that stub
// only exposes load/savePluginData). Both surfaces must share one state file.
Item {
    id: core

    readonly property string pluginId: "fireclocker"
    readonly property string stateKey: "session"

    // ── Settings, injected by the hosting surface ────────────────────────────
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

    // ── Shared state ─────────────────────────────────────────────────────────
    readonly property var g: PluginService.globalVars[pluginId] || ({})

    readonly property string currentMode: g.mode || "timer"
    readonly property bool isRunning: g.isRunning === true
    readonly property real totalMs: g.totalMs || 0
    readonly property real remainingMs: g.remainingMs || 0
    readonly property real wallBase: g.wallBase || 0
    readonly property real wallAccum: g.wallAccum || 0
    readonly property string pomodoroPhase: g.pomodoroPhase || "work"
    readonly property int pomodoroSession: g.pomodoroSession || 1
    readonly property real runId: g.runId || 0
    readonly property bool finishedWhileAway: g.finishedWhileAway === true

    readonly property bool isIdle: totalMs <= 0
    readonly property bool isFinished: !isRunning && totalMs > 0 && remainingMs <= 0
    readonly property bool isPaused: !isRunning && totalMs > 0 && remainingMs > 0

    // 0 → 1, elapsed fraction for countdowns, fill fraction for the stopwatch.
    readonly property real progress: {
        if (isIdle || totalMs <= 0)
            return 0;
        if (currentMode === "stopwatch")
            return Math.min(1, remainingMs / totalMs);
        return Math.max(0, Math.min(1, 1 - remainingMs / totalMs));
    }

    readonly property color modeColor: {
        if (isRunning)
            return Theme.primary;
        if (isPaused || isFinished)
            return Theme.warning;
        return Theme.surfaceText;
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

    readonly property string phaseLabel: pomodoroPhase === "work" ? "Focus" :
                                         pomodoroPhase === "shortBreak" ? "Short Break" : "Long Break"

    // ── Formatting ───────────────────────────────────────────────────────────
    function formatTime(ms) {
        const total = Math.floor(Math.max(0, ms) / 1000);
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = total % 60;
        return ("0" + h).slice(-2) + ":" + ("0" + m).slice(-2) + ":" + ("0" + s).slice(-2);
    }

    function formatTimeShort(ms) {
        const total = Math.floor(Math.max(0, ms) / 1000);
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = total % 60;
        if (h > 0)
            return h + ":" + ("0" + m).slice(-2) + ":" + ("0" + s).slice(-2);
        return m + ":" + ("0" + s).slice(-2);
    }

    // ── State primitives ─────────────────────────────────────────────────────
    function setVar(name, value) {
        if (!PluginService || !PluginService.setGlobalVar)
            return;
        PluginService.setGlobalVar(pluginId, name, value);
    }

    // Absolute wall-clock model: elapsed = wallAccum + (now - wallBase).
    // Because wallBase is an epoch timestamp, elapsed time keeps accruing while
    // the shell is not running — that is what makes restart recovery exact.
    function syncRemainingFromWall() {
        if (!isRunning || wallBase <= 0)
            return;

        const elapsed = wallAccum + Math.max(0, Date.now() - wallBase);

        if (currentMode === "stopwatch") {
            const value = Math.min(totalMs, elapsed);
            if (Math.abs(value - remainingMs) >= 200)
                setVar("remainingMs", value);
            if (value >= totalMs)
                setVar("isRunning", false);
            return;
        }

        const left = Math.max(0, totalMs - elapsed);
        if (left <= 0) {
            setVar("remainingMs", 0);
            setVar("isRunning", false);
            handleTimeout();
        } else if (Math.abs(left - remainingMs) >= 200) {
            setVar("remainingMs", left);
        }
    }

    // ── Actions ──────────────────────────────────────────────────────────────
    function cycleMode() {
        const modes = ["timer", "stopwatch", "pomodoro"];
        const next = modes[(modes.indexOf(currentMode) + 1) % modes.length];
        setMode(next);
    }

    function setMode(mode) {
        resetStop();
        setVar("mode", mode);
    }

    function startTimer(minutes) {
        const mins = Math.max(1, Math.round(Number(minutes) || 0));
        const ms = mins * 60 * 1000;
        setVar("finishedWhileAway", false);
        setVar("firedRunId", 0);
        setVar("runId", Date.now());
        setVar("totalMs", ms);
        setVar("wallAccum", 0);
        setVar("wallBase", Date.now());
        setVar("remainingMs", ms);
        setVar("isRunning", true);
    }

    function startPause() {
        if (currentMode === "stopwatch") {
            if (isIdle || isFinished) {
                setVar("finishedWhileAway", false);
                setVar("firedRunId", 0);
                setVar("runId", Date.now());
                setVar("totalMs", 86400000);
                setVar("wallAccum", 0);
                setVar("wallBase", Date.now());
                setVar("remainingMs", 0);
                setVar("isRunning", true);
                return;
            }
            if (isRunning) {
                setVar("wallAccum", wallAccum + (Date.now() - wallBase));
                setVar("wallBase", 0);
                setVar("isRunning", false);
                syncRemainingFromWall();
            } else {
                setVar("wallBase", Date.now());
                setVar("isRunning", true);
            }
            return;
        }

        if (isIdle) {
            const minutes = currentMode === "timer" ? defaultTimerMinutes :
                (pomodoroPhase === "work" ? pomodoroWorkMinutes :
                    (pomodoroPhase === "shortBreak" ? pomodoroShortBreakMinutes : pomodoroLongBreakMinutes));
            startTimer(minutes);
            return;
        }

        if (isFinished) {
            resetStop();
            return;
        }

        if (isRunning) {
            setVar("wallAccum", wallAccum + (Date.now() - wallBase));
            setVar("wallBase", 0);
            setVar("isRunning", false);
            syncRemainingFromWall();
        } else {
            setVar("wallBase", Date.now());
            setVar("isRunning", true);
        }
    }

    function resetStop() {
        setVar("finishedWhileAway", false);
        setVar("isRunning", false);
        setVar("remainingMs", 0);
        setVar("totalMs", 0);
        setVar("wallBase", 0);
        setVar("wallAccum", 0);
        setVar("runId", 0);
        setVar("firedRunId", 0);
    }

    function adjustTime(deltaSeconds) {
        if (currentMode !== "timer" || isRunning)
            return;
        const next = Math.max(0, Math.min(remainingMs + deltaSeconds * 1000, 86400000));
        setVar("remainingMs", next);
        setVar("totalMs", next);
        setVar("finishedWhileAway", false);
    }

    function advancePomodoroPhase() {
        if (pomodoroPhase === "work") {
            const nextSession = pomodoroSession + 1;
            const longBreak = nextSession % Math.max(1, pomodoroSessionsBeforeLongBreak) === 0;
            setVar("pomodoroSession", nextSession);
            setVar("pomodoroPhase", longBreak ? "longBreak" : "shortBreak");
            if (autoStartBreaks)
                startTimer(longBreak ? pomodoroLongBreakMinutes : pomodoroShortBreakMinutes);
        } else {
            setVar("pomodoroPhase", "work");
            if (autoStartBreaks)
                startTimer(pomodoroWorkMinutes);
        }
    }

    function skipPhase() {
        if (currentMode === "pomodoro" && pomodoroPhase !== "work")
            advancePomodoroPhase();
    }

    // ── Alerts ───────────────────────────────────────────────────────────────
    function playAlarm() {
        if (!useSystemSound)
            return;
        if (soundPath !== "")
            Proc.runCommand("fc-alarm", ["paplay", soundPath], null, 0);
        else
            Proc.runCommand("fc-alarm", ["canberra-gtk-play", "-i", "message", "-d", "FireClocker"], null, 0);
    }

    readonly property string finishedMessage: currentMode === "timer" ? "Timer finished!" :
        currentMode === "pomodoro" ? (pomodoroPhase === "work" ? "Focus session complete!" : "Break over!") :
        "Stopwatch finished"

    function notify(message, urgent) {
        if (!showNotifications)
            return;
        const args = ["notify-send", "-i", "appointment-soon", "-a", "FireClocker"];
        if (urgent)
            args.push("-u", "critical");
        args.push("FireClocker", message);
        Proc.runCommand("fc-notify", args, null, 0);
    }

    // Only one surface may act on a finished run. Every surface runs its own
    // 200 ms ticker, so without this claim the alarm, notification and pomodoro
    // advance would fire once per visible surface.
    function handleTimeout() {
        if (runId !== 0 && g.firedRunId === runId)
            return;
        setVar("firedRunId", runId === 0 ? -1 : runId);

        playAlarm();
        notify(finishedMessage, true);

        if (currentMode === "pomodoro")
            advancePomodoroPhase();
    }

    // A countdown that ran out while the shell was not running: stay silent, the
    // alarm would be hours late, but tell the user and move the cycle on.
    function handleMissedTimeout() {
        if (showNotifications && notifyMissedWhileAway)
            notify(currentMode === "pomodoro"
                ? (pomodoroPhase === "work" ? "Focus session ended while DMS was restarting"
                                            : "Break ended while DMS was restarting")
                : "Timer finished while DMS was restarting", false);

        if (currentMode === "pomodoro") {
            if (pomodoroPhase === "work") {
                const nextSession = pomodoroSession + 1;
                setVar("pomodoroSession", nextSession);
                setVar("pomodoroPhase", nextSession % Math.max(1, pomodoroSessionsBeforeLongBreak) === 0 ? "longBreak" : "shortBreak");
            } else {
                setVar("pomodoroPhase", "work");
            }
        }
    }

    function setDND(enabled) {
        if (typeof SessionData === "undefined")
            return;
        if (typeof SessionData.setDoNotDisturb === "function")
            SessionData.setDoNotDisturb(enabled);
    }

    onIsRunningChanged: {
        if (autoDND)
            setDND(isRunning);
    }

    // ── Persistence (Tier 2) ─────────────────────────────────────────────────
    property bool _restoring: false

    function snapshot() {
        return {
            "version": 1,
            "mode": currentMode,
            "isRunning": isRunning,
            "remainingMs": remainingMs,
            "totalMs": totalMs,
            "pomodoroPhase": pomodoroPhase,
            "pomodoroSession": pomodoroSession,
            "wallBase": wallBase,
            "wallAccum": wallAccum,
            "runId": runId,
            "finishedWhileAway": finishedWhileAway,
            "savedAt": Date.now()
        };
    }

    function persistState() {
        if (_restoring || !PluginService || !PluginService.savePluginState)
            return;
        PluginService.savePluginState(pluginId, stateKey, snapshot());
    }

    function loadState() {
        if (!PluginService || !PluginService.loadPluginState)
            return null;
        try {
            return PluginService.loadPluginState(pluginId, stateKey, null);
        } catch (e) {
            return null;
        }
    }

    function restoreState() {
        // One restore per shell across all surfaces.
        if (g.sessionRestored === true)
            return;

        _restoring = true;
        setVar("sessionRestored", true);

        const st = loadState();
        const modes = ["timer", "stopwatch", "pomodoro"];
        const mode = (st && modes.indexOf(st.mode) >= 0) ? st.mode : "timer";

        const totalMsSaved = (st && st.totalMs) || 0;
        const wasRunning = !!(st && st.isRunning);
        const wallBaseSaved = (st && st.wallBase) || 0;
        const wallAccumSaved = (st && st.wallAccum) || 0;
        const remainingSaved = (st && st.remainingMs) || 0;

        setVar("mode", mode);
        setVar("pomodoroPhase", (st && st.pomodoroPhase) || "work");
        setVar("pomodoroSession", (st && st.pomodoroSession) || 1);
        setVar("totalMs", totalMsSaved);
        setVar("runId", (st && st.runId) || 0);
        setVar("finishedWhileAway", !!(st && st.finishedWhileAway));

        if (totalMsSaved <= 0) {
            setVar("wallBase", 0);
            setVar("wallAccum", 0);
            setVar("isRunning", false);
            setVar("remainingMs", 0);
            _restoring = false;
            return;
        }

        if (wasRunning && wallBaseSaved > 0) {
            const elapsed = wallAccumSaved + Math.max(0, Date.now() - wallBaseSaved);

            if (mode === "stopwatch") {
                const value = Math.min(totalMsSaved, elapsed);
                setVar("wallAccum", elapsed);
                setVar("wallBase", value >= totalMsSaved ? 0 : wallBaseSaved);
                setVar("remainingMs", value);
                setVar("isRunning", value < totalMsSaved);
            } else {
                const left = Math.max(0, totalMsSaved - elapsed);
                if (left > 0) {
                    setVar("wallAccum", wallAccumSaved);
                    setVar("wallBase", wallBaseSaved);
                    setVar("remainingMs", left);
                    setVar("isRunning", true);
                } else {
                    setVar("wallBase", 0);
                    setVar("wallAccum", elapsed);
                    setVar("isRunning", false);
                    setVar("remainingMs", 0);
                    setVar("finishedWhileAway", true);
                    handleMissedTimeout();
                }
            }
        } else {
            setVar("wallAccum", wallAccumSaved);
            setVar("wallBase", 0);
            setVar("isRunning", false);
            setVar("remainingMs", remainingSaved);
        }

        _restoring = false;

        if (finishedWhileAway)
            persistState();
    }

    function clearState() {
        if (PluginService && PluginService.clearPluginState)
            PluginService.clearPluginState(pluginId);
        resetStop();
        setVar("mode", "timer");
        setVar("pomodoroPhase", "work");
        setVar("pomodoroSession", 1);
    }

    // Persist on semantic transitions, never on tick. `remainingMs` only matters
    // when stopped (while running it is derived from wallBase/wallAccum).
    Connections {
        target: PluginService
        function onGlobalVarChanged(pid, name) {
            if (pid !== core.pluginId)
                return;
            if (name === "remainingMs") {
                if (!core.isRunning)
                    core.persistState();
                return;
            }
            core.persistState();
        }
    }

    // Bounds what a hard crash can lose; transitions are already covered above.
    Timer {
        interval: 30000
        repeat: true
        running: core.isRunning && !core._restoring
        onTriggered: core.persistState()
    }

    Timer {
        id: ticker
        interval: 200
        repeat: true
        running: core.isRunning
        onTriggered: core.syncRemainingFromWall()
    }

    Component.onCompleted: restoreState()
    Component.onDestruction: persistState()
}
