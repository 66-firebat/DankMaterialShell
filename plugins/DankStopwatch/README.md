# Dank Stopwatch

Dank Stopwatch is a modern glassmorphic stopwatch pill for DankMaterialShell. It adds a compact DankBar widget with elapsed time and a polished popout for controls, lap tracking, and copying the current time.

## What this solves

Keep timing and lap controls in the desktop bar while you work. This project demonstrates a compact QML interface, timing state, clipboard integration, and theme-aware DankMaterialShell components.

[Developer portfolio](https://nikaj.dev) · [Discuss a custom tool](mailto:contact@nikaj.dev)

## Screenshots

### Ready State

![Dank Stopwatch ready state](./screenshots/stopwatch-ready.png)

### Running With Laps

![Dank Stopwatch running with laps](./screenshots/stopwatch-laps.png)

### Settings

![Dank Stopwatch settings panel](./screenshots/stopwatch-settings.png)

## Features

- Compact horizontal and vertical DankBar pills
- Accurate start, pause, resume, and reset timing
- Latest-first lap list with lap number, lap time, and split delta
- Copy current time via `dms cl copy`
- Minimal settings for centiseconds, compact mode, icon visibility, lap count, and update interval
- Theme-aware QML using DankMaterialShell `Theme`, `DankIcon`, `StyledText`, `DankButton`, `PluginComponent`, and `PluginSettings`

## Install

Install path:

```sh
~/.config/DankMaterialShell/plugins/DankStopwatch
```

Development symlink workflow:

```sh
ln -s "$(pwd)" ~/.config/DankMaterialShell/plugins/DankStopwatch
```

Enable steps:

1. Put this folder in `~/.config/DankMaterialShell/plugins/DankStopwatch`
2. Open DMS Settings -> Plugins
3. Scan for plugins
4. Enable Dank Stopwatch
5. Add it to the DankBar layout
6. Restart or reload DMS if required

Reload during development:

```sh
dms ipc call plugins reload dankStopwatch
```

## Troubleshooting

Validate the manifest:

```sh
jq . plugin.json
```

List detected plugins:

```sh
dms ipc call plugins list
```

Restart DankMaterialShell:

```sh
dms kill && dms run
```

If copy feedback appears but the clipboard does not change, confirm `dms cl copy` works in your shell session.
