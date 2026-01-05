import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io

FreezeScreen {
    id: root
    visible: false

    property var hyprlandMonitor: Hyprland.focusedMonitor
    property string tempPath

    // Process to handle the OCR pipeline
    Process {
        id: ocrProcess
        running: false

        // Corrected syntax for the exit handler
        onExited: (exitCode, exitStatus) => {
            Quickshell.execDetached(["rm", tempPath]);
            Qt.quit();
        }
    }

    function runOCR(x, y, width, height) {
        const scale = hyprlandMonitor.scale;
        const scaledX = Math.round((x + root.hyprlandMonitor.x) * scale);
        const scaledY = Math.round((y + root.hyprlandMonitor.y) * scale);
        const scaledWidth = Math.round(width * scale);
        const scaledHeight = Math.round(height * scale);

        // PIPELINE: Crop -> Tesseract -> wl-copy -> Notify
        ocrProcess.command = ["sh", "-c",
        "magick \"" + tempPath + "\" -crop " + scaledWidth + "x" + scaledHeight + "+" + scaledX + "+" + scaledY + " - | " +
        "tesseract - - -l eng | " +
        "wl-copy && notify-send 'OCR Complete' 'Text copied to clipboard'"
        ];

        ocrProcess.running = true;
        root.visible = false;
    }

    // Initial setup to "freeze" the screen
    Component.onCompleted: {
        const timestamp = Date.now();
        tempPath = Quickshell.cachePath("ocr-freeze-" + timestamp + ".png");
        Quickshell.execDetached(["grim", tempPath]);
        showTimer.start();
    }

    Timer {
        id: showTimer
        interval: 50
        running: false
        repeat: false
        onTriggered: root.visible = true
    }

    RegionSelector {
        id: regionSelector
        anchors.fill: parent
        onRegionSelected: (x, y, width, height) => {
            runOCR(x, y, width, height);
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: () => {
            Quickshell.execDetached(["rm", tempPath]);
            Qt.quit();
        }
    }
}
