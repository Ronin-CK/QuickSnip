# QuickSnip

A highly optimized screen snipping, OCR, and routing tool built for Quickshell. Designed for speed, flexibility, and minimal friction.

## Key Features

* **Instant OCR**: Fast text extraction using Tesseract.
* **Smart Actions**: Automatically detects URLs, code blocks, or standard text and routes them to your browser, search engine, or AI sidebar.
* **Advanced Selection**: 
  * Granular word highlighting and drag-to-select regions.
  * `Ctrl + Click` to select multiple, non-contiguous words.
  * `Shift + Click` to extend a selection range.
* **Google Lens**: Built-in support for grabbing a region and sending it to Google Lens.
* **Quick Translation**: Instantly translate text snippets using Google Translate.
* **Copy Modes**: Switch between standard, raw, and single-line formatting on the fly based on your paste destination.
  * Press `d` to toggle **Direct Copy** (skips word selection and copies entire region).
  * Press `r` to toggle **Raw Copy** (preserves exact OCR formatting).
  * Press `s` to toggle **Single Line** (strips newlines).


<video src="https://github.com/user-attachments/assets/ef7d56ee-acce-4e03-ac94-194914290589" controls="controls" style="max-width: 100%;">
  Your browser does not support the video tag.
</video>
  

## Installation (Arch)

### AUR (maintained by @knownasnaffy):
```bash
yay -S quicksnip-git
```

### Manual Installation
```bash
sudo pacman -S grim imagemagick tesseract tesseract-data-eng wl-clipboard curl libnotify xdg-utils wlrctl wtype
# Get quickshell from AUR
yay -S quickshell
```

## Other Distros

### Fedora:
```bash
# Enable COPR repository for quickshell
sudo dnf copr enable errornointernet/quickshell
sudo dnf install quickshell grim ImageMagick tesseract tesseract-langpack-eng wl-clipboard curl
```

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
### Labwc/LabFyre (`rc.xml`)
```xml
<keyboard>
 <keybind key="W-S-t">
  <action name="Execute">
   <command>quickshell -c QuickSnip -n</command>
  </action>
 </keybind>
</keyboard>
```

**Note on Scaling**: If the selection area looks shifted or wrong, it's probably Qt scaling fighting with the compositor. You can force it to 1 like this:

```bash
# Hyprland example
bind = $mainMod SHIFT, T, exec, env QT_SCALE_FACTOR=1 QT_AUTO_SCREEN_SCALE_FACTOR=0 quickshell -c QuickSnip -n
```

## QuickSnip Sidebar Extension  ![Mozilla Add-on Users](https://img.shields.io/amo/users/quicksnip-sidebar?style=flat-square&color=orange)

QuickSnip includes a companion browser extension to handle instant routing into your browser's sidebar.

**Install the extension:**
* **Firefox / Zen Browser**: [QuickSnip Sidebar](https://addons.mozilla.org/en-US/firefox/addon/quicksnip-sidebar/) 
* **Manual**: Load the `extension/` directory as an unpacked extension in your browser.

**How to use:**
1. In `settings.json`, ensure `"Browser": { "class": "zen" }` is set.
2. Set `"open_in": "sidebar"` for your desired actions.
3. Results will now seamlessly dispatch into your dedicated browser sidebar.
