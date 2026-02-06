# QuickSnip

A Wayland utility for OCR and Google Lens search, built using Quickshell. It is compositor-agnostic and works on any **wlroots-based** compositor (Hyprland, Sway, River, Niri, MangoWC, etc.). It's meant to be fast, minimal, and stay out of your way.

## What it does

* **OCR**: Select a region to extract text using Tesseract. It includes a cleanup script to fix the awkward line breaks and spacing that Tesseract usually spits out.
* **Google Lens**: Uploads a cropped JPEG directly to Lens using a form injection hack. This avoids using third-party image hosts and is significantly faster.
* **Selection UI**: Uses fragment shaders for background dimming and spring physics for the selection box. You get precisison crosshairs while hovering and fluid animations while dragging.
* **Low Overhead**: This isn't a daemon. The process only spawns when you trigger the keybind, performs the capture/OCR, and kills itself immediately after.
* **Compositor Support**: Works on any compositor that supports `wlr-layer-shell` and `wlr-screencopy` (standard **wlroots** protocols). This includes Hyprland, Sway, River, Niri, MangoWC, and others.

## Demo

https://github.com/user-attachments/assets/76a272f5-3851-4c0e-a40a-1e46729e7785

## Shortcuts

* `Tab`: Toggle modes (OCR / Lens)
* `t`: Switch to OCR
* `g`: Switch to Lens
* `Escape`: Quit (cleans up temp files)

## Setup

QuickSnip works on any Linux distribution. You just need the following dependencies in your path:

* `quickshell` 
* `grim`
* `imagemagick` 
* `tesseract` + `tesseract-data-eng`
* `wl-clipboard` 
* `curl` 
* `libnotify`

### Installation (Arch)
```bash
sudo pacman -S grim imagemagick tesseract tesseract-data-eng wl-clipboard curl libnotify xdg-utils
# Get quickshell from AUR
yay -S quickshell-git
```

### Other Distros

**Fedora:**
```bash
# Enable COP repository for quickshell
sudo dnf copr enable errornointernet/quickshell
sudo dnf install quickshell grim ImageMagick tesseract tesseract-langpack-eng wl-clipboard curl libnotify xdg-utils
```

For other distros, install the equivalent packages using your package manager (e.g., `apt`, `zypper`). For **quickshell**, follow the [official build instructions](https://github.com/outfoxxed/quickshell#building) if it's not in your repos.

Clone it into your config:
```bash
mkdir -p ~/.config/quickshell 
git clone https://github.com/Ronin-CK/QuickSnip.git ~/.config/quickshell/QuickSnip
```

## Configuration

Add a keybinding to your compositor config to launch the tool.

### Hyprland (`hyprland.conf`)
```ini
bind = $mainMod SHIFT, T, exec, quickshell -c QuickSnip -n
```

### Sway (`config`)
```text
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
