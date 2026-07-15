# PATCH 1: wfRecorderIndicator Freeze Fix

## Bug Report

**When toggling the screen recording ON and then OFF, the entire system freezes — even Ctrl+Alt+F3 TTY switching does not work.**

## Root Cause Analysis

The freeze is caused by a **cascading blocking chain** rooted in `keymaps.lua`, not in the QML widget code itself.

### Issue 1 (CRITICAL): `os.execute` in keymaps.lua blocks Hyprland's main thread

**File**: `keymaps.lua`

```lua
os.execute("pkill -INT wf-recorder")
os.execute("dms ipc call widget toggleQuery wfRecorderIndicator stop")
```

`os.execute` in Lua is synchronous — it calls `fork()` + `exec()` + `waitpid()`. The `waitpid()` blocks the calling thread until the child process exits. In Hyprland, Lua keybind callbacks run on the **main display thread**. When `os.execute` blocks, Hyprland freezes.

**The cascade to full system freeze:**

```
Hyprland main thread
  └─ os.execute("dms ipc call widget ...")   ← BLOCKING waitpid()
       └─ fork() + exec("dms") + waitpid()
            └─ dms CLI sends IPC to DMS daemon via Unix socket
                 └─ DMS processes IPC → calls toggleWithQuery()
                 └─ DMS sends response back
            └─ dms CLI exits
       └─ waitpid() returns, Hyprland continues
```

If the `dms` CLI takes any noticeable time (e.g., >50ms), Hyprland's event loop stalls. If the `dms` CLI **hangs** (socket issue, DMS daemon busy, etc.), Hyprland hangs **indefinitely** in `waitpid()` (D state).

Because Hyprland holds the **DRM master** (the kernel-level GPU/display lock), when it enters D state, the kernel **cannot reassign the DRM master to a different VT**. This is why Ctrl+Alt+F3 doesn't work — the VT switch fails because the current master is stuck.

### Issue 2 (SECONDARY): Process lifecycle race in the original QML code

**File**: `WfRecorderWidget.qml` (ORIGINAL code before patch)
**Location**: `fileSizeTimer.onTriggered`

The original code had an additional race where `fileSizeChecker.running = false` (SIGTERM) raced against `Qt.callLater` restart, but this only compounded the existing `os.execute` blocking issue.

---

### Issue 3 (SECONDARY — FIXED): `Qt.callLater` survives past `toggleWithQuery`

**File**: `WfRecorderWidget.qml`
**Locations**: `fileSizeTimer.onTriggered` + `toggleWithQuery()`

When the user toggles OFF:

1. `fileSizeTimer.onTriggered` fires → queues a `Qt.callLater` callback
2. `toggleWithQuery()` calls `fileSizeTimer.stop()` — but the `Qt.callLater` callback is **already in the event loop queue**
3. The callback executes after `toggleWithQuery` returns → sets `fileSizeChecker.running = true`
4. A `bash -c "stat ..."` process is spawned even though recording has stopped
5. This process runs on a stale/deleted file path, and its `onStreamFinished` sets properties unnecessarily

---

### Issue 4 (SECONDARY — FIXED): 10ms timer (100Hz) starves the event loop

**File**: `WfRecorderWidget.qml`
**Location**: `elapsedTimer` (`interval: 10`)

```qml
Timer {
    id: elapsedTimer
    interval: 10   // 100 ticks/second
    ...
}
```

Each tick:
- Calls `new Date().getTime()` + 4× `Math.floor()` + string concatenation
- Updates `root.elapsedText` → triggers QML property binding re-evaluation
- Both `horizontalBarPill` and `verticalBarPill` re-render on every tick

**Total: 200 layout/paint cycles per second** from this timer alone. This doesn't directly freeze the UI, but it keeps the event loop under constant high pressure, **amplifying the impact** of Process lifecycle races into a full deadlock.

#### Deep Dive: How 100Hz timer pressure turns a race into a deadlock

The Qt/QML event loop is fundamentally single-threaded. Every event — timer ticks, user input, IPC callbacks, property change notifications, repaint requests — runs on the same main/UI thread, processed one at a time from a queue.

**1. It consumes a disproportionate share of the event loop's bandwidth**

At `interval: 10`, the timer fires 100 times per second. Each tick queues a full `onTriggered` execution:

```qml
onTriggered: {
    var elapsedMs = new Date().getTime() - root.startTime;  // syscall
    var totalCs = Math.floor(elapsedMs / 10);
    var minutes  = Math.floor(totalCs / 6000);
    var seconds  = Math.floor((totalCs % 6000) / 100);
    var cs       = totalCs % 100;
    root.elapsedText = String(minutes).padStart(2, '0') + ":" +
        String(seconds).padStart(2, '0') + ":" +
        String(cs).padStart(2, '0');
}
```

That single assignment `root.elapsedText = ...` doesn't just set a string — it fires the QML binding engine, which re-evaluates every expression that depends on `elapsedText`. Both `horizontalBarPill` and `verticalBarPill` contain `text: root.elapsedText`, so each tick triggers two full pill re-renders, including layout calculation and painting.

That's **200 re-renders per second** from this timer alone.

**2. It crowds out Process lifecycle events**

Quickshell's `Process` communicates state changes via the same event loop:
- Process started → emits signal
- Data received on stdout → `StdioCollector` signal
- Process finished → `onRunningChanged` → `running` property update

All of these queue on the same single thread. With 100 elapsed timer events per second, Process state transitions that should happen in rapid succession are **stretched across many milliseconds** because dozens of timer ticks are processed in between each stage.

**3. It widens the Qt.callLater race window**

Consider the `fileSizeChecker` restart pattern:

```qml
onTriggered: {
    fileSizeChecker.running = false;   // sends SIGTERM
    Qt.callLater(function() {
        fileSizeChecker.running = true;  // start new process
    });
}
```

Between `running = false` and the `Qt.callLater` callback executing:

- **Without 100Hz timer**: The callback runs next event loop cycle (~1ms later). The old process has been sent SIGTERM but `QProcess` hasn't finished its state transition yet. Still a race, but tight.

- **With 100Hz timer**: Before the `Qt.callLater` callback runs, **dozens of timer ticks** fire. Each one calls `new Date().getTime()`, updates `elapsedText`, and triggers two pill re-renders. Meanwhile, the old process got SIGTERM. If it finishes and `QProcess` emits `onRunningChanged(false)` during this window, that event also queues behind all the timer events. By the time `Qt.callLater` finally runs and sets `running = true`, the internal `QProcess` state may be in the middle of cleanup — or the cleanup event is still queued behind more timer ticks.

This is how the 10ms timer **turns a narrow race condition into a guaranteed collision**.

**4. It prevents the event loop from ever catching up**

Even before a full deadlock, the 100Hz timer keeps the loop so busy that IPC callbacks (`toggleWithQuery`) get delayed, property change events pile up, and the bar UI stops responding to mouse and keyboard. It can *appear* frozen even if the thread hasn't technically deadlocked yet.

**Analogy**: Think of the event loop as a single cashier at a convenience store.
- The **10ms timer** is a customer who walks up to the counter every 0.01 seconds to ask "what time is it?" — and each time, two security guards (the pills) escort them out and redecorate the store.
- The **Process lifecycle** is a customer buying cigarettes — they need to: walk in → pick up pack → walk to counter → pay → walk out.
- The **`Qt.callLater` race** is the cashier trying to serve the next customer while the first customer is still mid-transaction.

Under normal conditions, the cigarette customer is served in one smooth interaction. But with the "what time is it?" customer interrupting 100 times per second, the simple purchase gets stretched into a chaotic sequence of micro-interruptions — and eventually the cashier loses track of whose turn it is and freezes.

**The fix (original plan)**: Changing `interval: 10` to `interval: 100` would reduce interruptions from 100Hz to 10Hz — a 90% reduction.

**The fix (per user requirements)**: Changing `interval: 10` to `interval: 1000` reduces interruptions from 100Hz to **1Hz** — a 99% reduction. Combined with switching to the `onRunningChanged` pattern (which eliminates the `running = false → true` flip-flop entirely), the race condition disappears completely.

Additionally, the display format changes from `MM:SS:CC` (centiseconds, requiring 10ms precision) to `MM:SS` (seconds precision), so a 1-second timer is the natural fit — there is no visual benefit to ticking faster than once per second.

---

### Issue 5 (FIXED): `fileSizeChecker` never explicitly started

**File**: `WfRecorderWidget.qml`
**Locations**: `openWithQuery()` and `startupDetector.onStreamFinished`

```qml
fileSizeChecker.command = ["bash", "-c", "stat -c %s \"" + query + "\" 2>/dev/null || echo N/A"];
// ⚠️ fileSizeChecker.running is NEVER set to true here
elapsedTimer.start();
fileSizeTimer.start();
```

The command is updated but `running` remains `false`. The first file size poll only happens 5 seconds later when `fileSizeTimer` fires. The first 5 seconds of any recording session show "N/A" for file size.

**Note**: Per user requirements, both the elapsed timer and the file size check will be unified on a 1-second interval. This eliminates the separate 5-second `fileSizeTimer` entirely.

---

### Issue 6 (FIXED): No `fileSizeChecker` cleanup on stop

**File**: `WfRecorderWidget.qml`
**Location**: `toggleWithQuery()`

```qml
function toggleWithQuery(query: string): void {
    root.recording = false;
    elapsedTimer.stop();
    fileSizeTimer.stop();
    // ⚠️ fileSizeChecker.running is NOT set to false
}
```

If a stale `Qt.callLater` starts `fileSizeChecker` after the timer is stopped, the process keeps running silently in the background with no mechanism to stop it.

---

## Proposed Fixes

### Fix 0: Background the `dms ipc call` commands in keymaps.lua

**File**: `keymaps.lua`

Add `&` to all `dms ipc call` and `pkill` commands so they run in the background. The shell returns immediately, `os.execute` returns immediately, and Hyprland never blocks:

```lua
-- Before (blocks Hyprland):
os.execute("pkill -INT wf-recorder")
os.execute("dms ipc call widget toggleQuery wfRecorderIndicator stop")

-- After (fire-and-forget):
os.execute("pkill -INT wf-recorder &")
os.execute("dms ipc call widget toggleQuery wfRecorderIndicator stop &")
```

This breaks the cascading freeze chain by making every external call non-blocking.

### Fix 1: Trigger file size check from the 1-second elapsed timer (Option B)

Instead of an `onRunningChanged` auto-loop (which would poll as fast as `stat` can run — ~100-200Hz), the file size check is driven by the 1-second elapsed timer. Each tick updates both the display AND triggers one file size check if one isn't already in flight:

```qml
Timer {
    id: elapsedTimer
    interval: 1000          // fires once per second
    onTriggered: {
        // Update elapsed time display
        var elapsedSec = Math.floor((...));
        root.elapsedText = ...;

        // Trigger one file size check per second
        if (root.recording && !fileSizeChecker.running) {
            fileSizeChecker.running = true;
        }
    }
}
```

This eliminates:
- The `running = false` SIGTERM race entirely (no more `onRunningChanged` auto-loop)
- The `Qt.callLater` pattern that survives past timer stop
- The need for a separate `fileSizeTimer`
- Unnecessary polling — exactly one `stat` per second, no more

### Fix 2: Change elapsed timer to 1-second interval with MM:SS display

```qml
// Properties
property string elapsedText: "00:00"   // was "00:00:00"

// Timer
Timer {
    id: elapsedTimer
    interval: 1000          // was 10 — now fires once per second
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
```

The timer now owns both the display update and the file size polling trigger. The `!fileSizeChecker.running` guard prevents stacking checks if `stat` takes longer than 1 second.

### Fix 3: Explicitly start and stop the fileSizeChecker process

In `openWithQuery()`:
```qml
fileSizeChecker.command = ["bash", "-c", "stat -c %s \"" + query + "\" 2>/dev/null || echo N/A"];
root.recording = true;
fileSizeChecker.running = true;   // ← initial check (subsequent checks via timer)
elapsedTimer.start();
```

In `toggleWithQuery()`:
```qml
root.recording = false;            // ← prevents timer from starting new checks
fileSizeChecker.running = false;   // ← stops any in-flight check
elapsedTimer.stop();               // ← stops the timer (no more ticks)
```

### Fix 4: Eliminate the `fileSizeTimer` entirely

The separate 5-second `fileSizeTimer` is removed. The file size check is now owned by `elapsedTimer`, which fires once per second — exactly the cadence the user requested.

### Fix 5: Remove `onRunningChanged` from `fileSizeChecker`

The `fileSizeChecker` Process is simplified back to a plain process with no auto-loop. It runs once when `running = true` is set, then sits idle until the next timer tick sets `running = true` again.

### Fix 6: Update idle display text

```
Idle:  "00:00 • 0.0 MB"    (was "00:00:00 • 0.0 MB")
```

---

## Files to Modify

| File | Changes |
|------|---------|
| `keymaps.lua` | Add `&` to all `os.execute` calls (`pkill`, `dms ipc call widget openQuery`, `dms ipc call widget toggleQuery`) to prevent Hyprland main thread blocking |
| `WfRecorderWidget.qml` | Remove `fileSizeTimer`, simplify `fileSizeChecker` (remove `onRunningChanged` loop), add file size trigger inside `elapsedTimer.onTriggered`, change `elapsedTimer.interval` from 10ms to 1000ms, change display format from `MM:SS:CC` to `MM:SS`, update default `elapsedText` from `"00:00:00"` to `"00:00"`, add explicit `running = true/false` in `openWithQuery`/`toggleWithQuery` |

---

## Verification Steps

1. Load the widget and verify idle state shows icon + `00:00 • 0.0 MB`
2. Start recording (CTRL+Print) → verify elapsed timer ticks up once per second (MM:SS), file size updates each second
3. Stop recording (CTRL+Print) → verify widget freezes elapsed time and file size at last values
4. Repeat toggles 10+ times rapidly — verify no freeze
5. Kill Quickshell, restart, verify `startupDetector` correctly detects an active recording if `wf-recorder` survived the restart
