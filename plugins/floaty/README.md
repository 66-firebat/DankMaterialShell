# Floaty

Pin reference images, screenshots, and PDFs on top of your workspace.

<img src="screenshot.png" width="400" alt="Screenshot">

## Install

Use the DMS CLI:
```bash
dms plugins install floaty
```

Or manually:
```bash
git clone https://github.com/hthienloc/dms-floaty ~/.config/DankMaterialShell/plugins/floaty
```

## Features

- **Float from anywhere** - Clipboard, file picker, drag & drop, or URL
- **Multi-format support** - PNG, JPG, WebP, BMP, SVG, PDF (page selection)
- **Smart layout** - Auto-tiling prevents overlapping
- **Always on top** - Windows stay visible while you work
- **IPC ready** - Script-friendly commands for automation

## Usage

### Bar Icon

| Action | Result |
|--------|--------|
| Left click | Open popout menu |
| Middle click | Open file browser to select file |
| Right click | Paste and float from clipboard |
| Drag & drop | Quick float dropped image, file or text |

### Floating Windows

| Action | Result |
|--------|--------|
| Left click + Drag | Move window |
| Middle click | Close window |
| Right click | Toggle minimize / expand |
| Scroll | Resize window |

## IPC Commands

Use `dms ipc call floaty <command>` to control Floaty from scripts or keybindings.

| Command | Description |
|---------|-------------|
| `floatFromClipboard` | Float image/URL from clipboard |
| `selectFileAndFloat` | Open file picker and float selection |
| `floatFromUrl "url"` | Float from a URL or file path |
| `toggleMinimizeAll` | Toggle minimize/expand all windows |
| `minimizeAll` | Minimize all floating windows |
| `expandAll` | Expand all floating windows |
| `closeAllWindows` | Close all floating windows |

### Keybinding examples

**Niri:**
```kdl
bindings {
    Print { spawn "sh" "-c" "dms screenshot region --no-file --no-notify && dms ipc call floaty floatFromClipboard"; }
    Mod+V { spawn "dms" "ipc" "call" "floaty" "floatFromClipboard"; }
}
```

**Hyprland:**
```ini
bind = , Print, exec, dms screenshot region --no-file --no-notify && dms ipc call floaty floatFromClipboard
bind = SUPER, V, exec, dms ipc call floaty floatFromClipboard
```

## Requirements

- `poppler-utils` - PDF conversion (`pdftocairo`, `pdfinfo`)

## License

GPL-3.0

## Roadmap / TODO
- [ ] **Session Restoration:** Automatically reload floating images and their positions after a restart or crash.
- [ ] **Live Annotations:** Integrated pen and highlighter tools to mark up reference images without external editors.
- [ ] **Per-Window Opacity:** Individual transparency sliders for each window to prevent obscuring critical background details.
- [ ] **Quick OCR:** One-click text extraction from floating images directly into the clipboard.
- [ ] **Built-in Cropping:** Ability to trim or focus on specific parts of a floated image within the UI.
