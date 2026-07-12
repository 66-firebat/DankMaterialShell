# PLAN: wfRecorderIndicator Refactor

## Architecture

### IPC Mechanism: Quickshell `IpcHandler` (in-memory)

Uses `IpcHandler` from `Quickshell.Io` — the same mechanism hyprsphere uses.
- **No files written to disk** — communicates via Unix domain socket
- The QML widget registers an `IpcHandler` with target `"wfRecorderIndicator"`
- `keymaps.lua` calls `qs ipc call wfRecorderIndicator <method> <args>` to control state
- The widget is purely reactive to IPC calls from keymaps

### Startup Detection

At widget init, run `Process { command: ["bash", "-c", "pgrep -x wf-recorder && ls -lt $HOME/Videos/rec_*.mp4 2>/dev/null | head -1 | awk '{print $NF}'"] }` to detect if wf-recorder survived a shell restart.

If the process is found but the video path can't be determined → show recording state anyway with "N/A" for file size.

---

## Design Decisions (from user answers)

| Question | Decision |
|----------|----------|
| **IPC mechanism** | `IpcHandler` from `Quickshell.Io` — in-memory, no files |
| **Idle colors** | `#444444` foreground, `#2b2b2b` background |
| **Recording colors** | `#ef4444` foreground, `#2b2b2b` background |
| **File size** | Every 5.0s exactly, always MB with 1 decimal |
| **Startup detection** | Yes — `pgrep` + `ls -lt`; fall back to "N/A" for file size |
| **Timer resolution** | 10ms ticks, display format `MM:SS:CC` where CC = centiseconds (00–99) |
| **Click support** | None — display only |
| **Vertical bar** | Icon + stacked label (elapsed time + file size) |
| **Icons** | Idle=`󱫡` (nf-facetime_stop), Recording=`󱫤` (nf-facetime_record), font=`"Symbols Nerd Font"` |
| **keymaps guard** | Remove `_recording` variable — IPC calls are idempotent |

---

## Visual Design

### Non-Recording (Idle) State
```
[ 󱫡 ] 00:00:00 • 0.0 MB
```
- Icon: `󱫡` in `#444444`
- Time + file size in `#444444`
- Background: `#2b2b2b`

### Recording State
```
[ 󱫤 ] MM:SS:CC • XX.X MB
```
- Icon: `󱫤` in `#ef4444`
- Time + file size in `#ef4444`
- Background: `#2b2b2b`

---

## IpcHandler API

### Methods exposed by the widget

| Method | Signature | Called From | Effect |
|--------|-----------|-------------|--------|
| `startRecording(videoPath: string): void` | keymaps.lua (toggle on) | Sets recording=true, starts timer, begins file-size polling |
| `stopRecording(): void` | keymaps.lua (toggle off) | Sets recording=false, stops timer, resets elapsed/size to idle |

### keymaps.lua changes

Replace:
```lua
os.execute("dms ipc call widget hide wfRecorderIndicator")
```
with:
```lua
os.execute("qs ipc call wfRecorderIndicator stopRecording")
```

Replace:
```lua
os.execute("dms ipc call widget reveal wfRecorderIndicator")
```
with:
```lua
os.execute('qs ipc call wfRecorderIndicator startRecording "' .. filename .. '"')
```

Remove `_recording` variable and `_recording = true/false` assignments entirely.

---

## QML Implementation Details

### Properties

```qml
property bool recording: false
property string videoPath: ""
property real startTime: 0
property string elapsedText: "00:00:00"
property string fileSizeText: "0.0 MB"
```

### Timers

1. **elapsedTimer** — fires every 10ms, updates `elapsedText` in `MM:SS:CC` format when `recording == true`
2. **fileSizeTimer** — fires every 5000ms exactly, runs `Process` to check file size of `videoPath` when `recording == true`

### Format Calculation

```
MM:SS:CC where CC = centiseconds (0–99)

elapsedMs = now - startTime
totalCs = Math.floor(elapsedMs / 10)    ← 1 centisecond = 10ms
minutes = Math.floor(totalCs / 6000)    ← 6000 centiseconds per minute
seconds = Math.floor((totalCs % 6000) / 100)
cs = totalCs % 100
```

### Startup Detection

```qml
Process {
    id: startupDetector
    command: ["bash", "-c",
        "pid=$(pgrep -x wf-recorder) && " +
        "[ -n \"$pid\" ] && " +
        "ls -lt $HOME/Videos/rec_*.mp4 2>/dev/null | head -1 | awk '{print $NF}' || true"]
    running: true
    stdout: StdioCollector {
        onStreamFinished: {
            var path = this.text.trim();
            if (path.length > 0) {
                root.videoPath = path;
                root.startTime = new Date().getTime();
                root.recording = true;
            }
        }
    }
}
```

### IPC Handler

```qml
IpcHandler {
    target: "wfRecorderIndicator"
    function startRecording(videoPath: string): void {
        root.videoPath = videoPath;
        root.startTime = new Date().getTime();
        root.recording = true;
    }
    function stopRecording(): void {
        root.recording = false;
        root.elapsedText = "00:00:00";
        root.fileSizeText = "0.0 MB";
    }
}
```

---

## Files to Modify

1. **`WfRecorderWidget.qml`** — Full rewrite with:
   - `IpcHandler` for in-memory IPC
   - Two-state UI (idle + recording)
   - 10ms elapsed timer (`MM:SS:CC` format)
   - 5s file-size polling via `Process` (always MB with 1 decimal)
   - Startup detection via `pgrep` + `ls -lt`
   - No hide/show dependency — always visible

2. **`keymaps.lua`** — Changes:
   - Replace `dms ipc call widget (hide|reveal)` with `qs ipc call wfRecorderIndicator (startRecording|stopRecording)`
   - Remove `_recording` guard variable entirely
