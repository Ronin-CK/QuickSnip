# HyprQuickSnip

HyprQuickSnip is a lightweight, minimal OCR utility for Hyprland, built with Quickshell.

Modern, minimal UI designed to feel native on Hyprland

**Improvements**

– Enhanced the region selector with mouse tracking and guides
<details>
  <summary>▶ 🎥 Demo </summary>
  <br>


https://github.com/user-attachments/assets/aafa197b-111f-4b40-aab4-90a7b66a1ef1


</details>

![License](https://img.shields.io/badge/License-MIT-blue.svg)

## 📦 Requirements
1.  **[Quickshell](https://github.com/outfoxxed/quickshell)**
2.  `grim`
3.  `imagemagick`
4.  `tesseract` (and language data, e.g., `tesseract-data-eng`)
5.  `wl-clipboard`
6.  `libnotify`

## 🚀 Installation
1. **Install Dependencies**
# Install system tools
```bash
sudo pacman -S grim imagemagick tesseract tesseract-data-eng wl-clipboard curl jq libnotify xdg-utils
```

# Install Quickshell (from AUR)
```bash        
yay -S quickshell-git
```

2.  **Clone the repository:** 
   ```bash
mkdir -p ~/.config/quickshell 
   git clone https://github.com/Ronin-CK/HyprQuickSnip.git ~/.config/quickshell/HyprQuickSnip
```




## ⚙️ Configuration (Hyprland)
Add this to `hyprland.conf`:
```ini
bindr = SUPER SHIFT, T, exec, quickshell -p ~/.config/quickshell/HyprQuickSnip/Ocr.qml
