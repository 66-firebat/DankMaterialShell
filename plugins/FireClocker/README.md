# FireClocker

A semicircular timer for **DMS 2.x (dux-shell)**: a transparent desktop widget
with a `∩` gauge, plus an optional bar pill. Timer, stopwatch and pomodoro, with
session state that survives shell restarts.

## Two surfaces, one timer

Both surfaces are hosted by `FireClockerCore.qml`, which keeps all state in
`PluginService.globalVars` — so the desktop card and the bar pill always show the
same countdown. Start on the desktop, pause from the bar: same timer, same
pomodoro cycle, one alarm.

- **Desktop card** (`fireclocker.qml`) — semicircle gauge, no card background.
  Progress fills symmetrically outward from 12 o'clock. Two round buttons (play/
  pause, reset) sit on the flat edge, with an optional mode icon that cycles
  Timer → Stopwatch → Pomodoro. The time is hidden by default and appears on
  hover, together with a control panel (mode tabs, presets, custom minutes, skip)
  that opens **above** the gauge by default (`Panel Position` switches it below).
- **Bar pill** (`FireClockerPill.qml`) — compact pill with a popout for the full
  control set, matching what DmsTimeManager offers.

## Placement, overlay and translucency

The card is a normal DMS desktop widget: add it from **Settings → Desktop
Widgets**, then drag it where you want it (per screen, remembered across
restarts). Two per-instance toggles come from DMS itself:

| Toggle | Effect |
| --- | --- |
| `Show on overlay` | Puts the widget on the layer-shell **overlay** layer, i.e. above all normal windows |
| `Click through` | Clicks pass through the widget to whatever is behind it |

Note the trade-off: `click through` makes the widget non-interactive, so the
buttons and the hover panel stop working. Use it only if you want a purely
decorative readout.

Its window namespace is `dms:desktop-widget:fireclocker`, so a compositor rule
can frost whatever is behind the arc. Hyprland:

```
layerrule = blur, dms:desktop-widget:fireclocker
layerrule = ignorealpha 0.1, dms:desktop-widget:fireclocker
```

Translucency is two independent sliders in the plugin settings:

- **Surface opacity** — the arc (track and progress)
- **Content opacity** — buttons, mode icon and time text

## Settings

**Desktop card:** card scale (drives the real widget size through the desktop
surface's transient resize hook, so drag-resize is disabled), surface/content
opacity, arc thickness, always-show-time, show mode icon, expand-on-hover, panel
position (above/below).

**Bar pill:** show icon, font size, time text vs progress bar.

**Timer / Pomodoro:** default time, work/short/long durations, sessions before a
long break, auto-start next phase.

**Alerts:** alarm sound (system or custom file), desktop notifications, notify if
a countdown expired while DMS was restarting, auto-DND while running.

## Persistence

Session state lives in DMS's Tier 2 plugin state store, next to every other
plugin:

```
~/.local/state/dms/plugins/fireclocker_state.json
```

It is written on transitions only (start, pause, reset, mode switch, phase
change), plus a 30 s backstop while running. Because the timer is modelled on an
absolute `wallBase` timestamp, a countdown keeps draining correctly while the
shell is down, and a countdown that expires in the meantime is reported once as
"finished while DMS was restarting" instead of firing an hours-late alarm.

## Dependencies

- DMS / dux-shell **2.x** (uses the `composite` plugin type with `desktop` and
  `widget` surfaces, `SessionData.setDoNotDisturb`, and `PluginService` plugin
  state)
- `libnotify` (`notify-send`), `paplay` (PipeWire/PulseAudio) or `libcanberra`
  for the alarm

## IPC

IPC is registered by the **bar pill**, on target `fireclocker`. If you use
FireClocker as a desktop widget only and never add the pill to a bar, there is no
IPC target — put the pill in an (optionally hidden/zero-width) bar section, or
control the timer from the desktop card itself.

```bash
dms ipc call fireclocker getStatus
dms ipc call fireclocker toggle
dms ipc call fireclocker pause
dms ipc call fireclocker resume
dms ipc call fireclocker reset
dms ipc call fireclocker mode pomodoro
dms ipc call fireclocker startTimer 15
dms ipc call fireclocker clearState
```

## Install

```bash
dms plugins scan                      # or: Settings → Plugins → Scan for Plugins
```

Then enable **FireClocker**, add the pill to a bar if you want it, and add the
card from Settings → Desktop Widgets.

## Colours

Nothing is hardcoded — every colour is a DMS theme role, so the widget re-colours
itself with your theme (matugen, wallpaper-derived, or the custom
`fireshark.json`) without touching it.

| Element | Source |
| --- | --- |
| Arc progress | `Theme.primary` while running, `Theme.warning` paused/finished, `Theme.surfaceText` idle |
| Arc track | `Theme.surfaceText` at 28 % × surface opacity |
| Buttons | mode colour: fill 16 %/10 %, border 55 %/38 % × content opacity |
| Panel | `Theme.surfaceContainerHigh` @ 96 %, border `Theme.outline` @ 18 % |
| Mode tabs | active `primary`/`onPrimary`, inactive `surfaceContainerHighest`/`surfaceText` |
| Presets | `primaryContainer`/`onPrimaryContainer` |
| Skip phase | `tertiaryContainer`/`onTertiaryContainer` |

Type sizes derive from the theme too: `Theme.fontSizeSmall/Medium` are
`round(fontScale × 12/14)`.

## License

MIT
