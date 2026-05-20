# QuickSnip

A fast, native screen snipping, OCR, and routing tool built for Quickshell.

## ⚡ Features

* **Instant OCR:** Fast text extraction via Tesseract.
* **Smart Actions:** Auto-routes URLs/code/text. **Double-click** words to trigger.
* **Granular Selection:** Drag regions, `Ctrl+click` to multi-select, `Shift+click` to extend.
* **Integrations:** Native send-to Google Lens & Translate.
* **Format Toggles:** `d` (Direct mode), `r` (Raw OCR layout), `s` (Single-line).

## Installation

### Arch Linux

**AUR (maintained by [@knownasnaffy](https://github.com/knownasnaffy)):**
```bash
yay -S quicksnip-git
```

**Manual Installation:**
```bash
sudo pacman -S grim imagemagick tesseract tesseract-data-eng wl-clipboard curl libnotify xdg-utils wlrctl wtype
# Get quickshell from AUR
yay -S quickshell
```

### Fedora Linux

```bash
# Enable COPR repository for quickshell
sudo dnf copr enable errornointernet/quickshell
# Install dependencies
sudo dnf install quickshell grim ImageMagick tesseract tesseract-langpack-eng wl-clipboard curl wtype wlrctl libnotify xdg-utils
```

### Other Distros
For other distros, install the equivalent packages using your package manager (e.g., `apt`, `zypper`). For **quickshell**, follow the [official build instructions](https://github.com/outfoxxed/quickshell) if it's not in your repos.

### Clone it into your config:
```bash
mkdir -p ~/.config/quickshell
git clone https://github.com/Ronin-CK/QuickSnip.git ~/.config/quickshell/QuickSnip
```

## Configuration

Add a keybinding to your compositor config to launch the tool.

### Hyprland (`hyprland.conf`)
```bash
bind = $mainMod SHIFT, T, exec, quickshell -c QuickSnip -n
```

### Sway (`config`)
```bash
bindsym $mod+Shift+t exec quickshell -c QuickSnip -n
```

### Niri (`config.kdl`)
```kdl
binds {
    Mod+Shift+T { spawn "quickshell" "-c" "QuickSnip" "-n"; }
}
```

**Note on Scaling**: If the selection area looks shifted or wrong, it's probably Qt scaling fighting with the compositor. You can force it to 1 like this:

```bash
# Hyprland example
bind = $mainMod SHIFT, T, exec, env QT_SCALE_FACTOR=1 QT_AUTO_SCREEN_SCALE_FACTOR=0 quickshell -c QuickSnip -n
```

### Settings File (`settings.json`)
### Settings (`settings.json`)

Customize QuickSnip via `~/.config/quickshell/QuickSnip/settings.json`. Example:

```json
{ "OCR": { "language": "eng+hin" } } // Requires tesseract-data-hin
```

## QuickSnip Sidebar Extension

QuickSnip includes a companion browser extension to handle instant routing into your browser's sidebar.

**Install the extension:**
* **Firefox / Zen Browser**: [QuickSnip Sidebar](https://addons.mozilla.org/en-US/firefox/addon/quicksnip-sidebar/) 

**How to use:**
1. In `settings.json`, ensure `"Browser": { "class": "zen" }` is set.
2. Set `"open_in": "sidebar"` for your desired actions.
3. Results will now seamlessly dispatch into your dedicated browser sidebar.
