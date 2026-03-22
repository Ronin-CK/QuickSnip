import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "components"
import "modes"

ShellRoot {
    id: shellRoot

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: root

            required property ShellScreen modelData
            property var targetScreen: modelData
            property string fullScreenshot: ""
            property string cropJpg: ""
            property string lensHtml: ""
            property string ocrPhase: ""
            property bool ocrDirect: false
            property bool ocrSingleLine: false
            property bool ocrRaw: false
            property bool grimReady: false
            property bool cleanupHandled: false
            property real detectedMonitorScale: 1.0
            property var pendingOcrRect: null

            readonly property bool ctsEnabled: settings.selectionStyle === "circle"
            readonly property real monitorScale: detectedMonitorScale
            readonly property string activeOcrMode: ocrDirect ? "direct" : ocrSingleLine ? "single" : ocrRaw ? "raw" : ""



            function escapeShell(text) {
                if (typeof text !== 'string') return '';
                return text.replace(/'/g, "'\\''");
            }

            function cleanup() {
                if (cleanupHandled) return;
                cleanupHandled = true;
                if (fullScreenshot)
                    Quickshell.execDetached(["rm", "-f", fullScreenshot, cropJpg, lensHtml]);
            }

            function copyAndQuit(text, wordCount) {
                cleanupHandled = true;
                const sanitized = selectMode.sanitizeText(text);
                const escaped = escapeShell(sanitized);
                ocrCopyProc.command = ["sh", "-c",
                    `printf '%s' '${escaped}' | wl-copy && ` +
                    `notify-send 'Text Copied' '${wordCount} words copied to clipboard' ; ` +
                    `rm -f "${fullScreenshot}" "${cropJpg}"`
                ];
                ocrCopyProc.running = true;
            }

            function setOcrMode(mode) {
                console.log("[QuickSnip] OCR Mode set to: " + mode);
                ocrDirect = mode === "direct" && !ocrDirect;
                ocrSingleLine = mode === "single" && !ocrSingleLine;
                ocrRaw = mode === "raw" && !ocrRaw;
                if (ocrDirect) { ocrSingleLine = false; ocrRaw = false; }
                if (ocrSingleLine) { ocrDirect = false; ocrRaw = false; }
                if (ocrRaw) { ocrDirect = false; ocrSingleLine = false; }
            }

            function buildSearchUrl(text, engine) {
                const query = encodeURIComponent(text);
                const engines = {
                    "google": "https://www.google.com/search?q=%s&cs=1",
                    "duckduckgo": "https://duckduckgo.com/?q=%s",
                    "ddg": "https://duckduckgo.com/?q=%s",
                    "bing": "https://www.bing.com/search?q=%s",
                    "brave": "https://search.brave.com/search?q=%s"
                };
                const lower = engine.trim().toLowerCase();
                let format = engines[lower] || engine.trim();
                if (!format.includes("%s"))
                    format = engines["google"];
                return format.replace("%s", query);
            }

            function buildAiUrl(text, provider) {
                const query = encodeURIComponent(text);
                const providers = {
                    "chatgpt": "https://chatgpt.com/?q=%s",
                    "claude": "https://claude.ai/new?q=%s",
                    "grok": "https://grok.com/?q=%s"
                };
                const lower = provider.trim().toLowerCase();
                let format = providers[lower] || provider.trim();
                if (!format.includes("%s"))
                    format = providers["chatgpt"];
                return format.replace("%s", query);
            }

            function executeSmartAction(text) {
                if (!text || text.length === 0) return;
                const sanitized = selectMode.sanitizeText(text);
                const action = selectMode.analyzeText(sanitized, settings.smartAiThreshold);
                if (action === "url")
                    openInBrowser(selectMode.cleanUrl(sanitized), settings.smartOpenIn);
                else if (action === "code")
                    openInBrowser(buildAiUrl("Explain this code and show errors if any:\n\n" + sanitized, settings.aiProvider), settings.aiOpenIn);
                else if (action === "dictionary")
                    openInBrowser(buildSearchUrl("define " + sanitized, settings.searchEngine), settings.searchOpenIn);
                else if (action === "ai")
                    openInBrowser(buildAiUrl(sanitized, settings.aiProvider), settings.aiOpenIn);
                else
                    openInBrowser(buildSearchUrl(sanitized, settings.searchEngine), settings.searchOpenIn);
            }

            function openInBrowser(url, openMethod) {
                const sanitizedUrl = selectMode.sanitizeText(url);
                if (openMethod === "sidebar") {
                    const bc = settings.browserClass || "zen";
                    const escaped = escapeShell(sanitizedUrl);
                    const openCmd = `OLD_CLIP=$(wl-paste --no-newline --type text/plain 2>/dev/null || true); ` +
                                    `printf '%s' '${escaped}' | wl-copy && ` +
                                    `sleep 0.1 && wlrctl window focus ${bc} && ` +
                                    `sleep 0.2 && wtype -M alt -k s -m alt && ` +
                                    `sleep 0.3 && if [ "$(wl-paste)" = "OPEN_SIDEBAR_PLEASE" ]; then ` +
                                    `wtype -M alt -k g -m alt && ` +
                                    `sleep 0.1 && printf '%s' '${escaped}' | wl-copy ; fi; ` +
                                    `sleep 1; printf '%s' "$OLD_CLIP" | wl-copy`;
                    Quickshell.execDetached(["sh", "-c", openCmd]);
                } else {
                    Quickshell.execDetached(["xdg-open", sanitizedUrl]);
                }
                cleanup();
                Qt.quit();
            }



            function executeAction() {
                console.log("[QuickSnip] executeAction - screen:", !!targetScreen,
                           "grimReady:", grimReady, "scale:", monitorScale);
                if (!targetScreen || !grimReady) return;

                const x = Math.round(selector.selectionX * monitorScale);
                const y = Math.round(selector.selectionY * monitorScale);
                const w = Math.round(selector.selectionWidth * monitorScale);
                const h = Math.round(selector.selectionHeight * monitorScale);
                console.log("[QuickSnip] Region physical:", x, y, w, h,
                           "logical:", selector.selectionX, selector.selectionY,
                           selector.selectionWidth, selector.selectionHeight);

                if (w < 10 || h < 10) {
                    startOcr();
                    return;
                }

                if (ocrDirect || ocrSingleLine || ocrRaw) {
                    visible = false;
                    proc.command = ["sh", "-c", ocrMode.getCommand(x, y, w, h, ocrSingleLine, ocrRaw)];
                    proc.running = true;
                } else {
                    startOcr(x, y, w, h);
                }
            }

            function startOcr(x, y, w, h) {
                if (!targetScreen || ocrPhase !== "") {
                    return;
                }
                
                if (!grimReady) {
                    if (x !== undefined) pendingOcrRect = { x: x, y: y, w: w, h: h };
                    else pendingOcrRect = {};
                    return;
                }

                const hasRegion = x !== undefined;
                
                selectMode.regionX = hasRegion ? x / monitorScale : 0;
                selectMode.regionY = hasRegion ? y / monitorScale : 0;
                selectMode.regionW = hasRegion ? w / monitorScale : width;
                selectMode.regionH = hasRegion ? h / monitorScale : height;
                selectMode.loading = true;

                ocrPhase = "loading";

                const physW = hasRegion ? w : width * monitorScale;
                const physH = hasRegion ? h : height * monitorScale;
                const area = physW * physH;
                const isSmall = area < 40000;
                const isTiny = physH < 30;

                let upscale = "";
                let scaleFactor = 1.0;
                if (isTiny) {
                    upscale = "-resize 400%";
                    scaleFactor = 4.0;
                } else if (isSmall) {
                    upscale = "-resize 200%";
                    scaleFactor = 2.0;
                }

                // Global conversion factor: physical scale × upscale factor
                selectMode.monitorScale = monitorScale * scaleFactor;

                console.log("[QuickSnip] OCR overlay scale:", selectMode.monitorScale,
                           "(monitor:", monitorScale, "× upscale:", scaleFactor, ")",
                           "region logical:", selectMode.regionX, selectMode.regionY,
                           selectMode.regionW, selectMode.regionH);

                let psm = "3";
                if (isTiny || physH < 50 || physW / physH > 10) psm = "7";
                else if (isSmall) psm = "6";

                const cropParams = hasRegion ? `-crop ${w}x${h}+${x}+${y} +repage` : "";
                
                function getPath(filename) {
                    return Quickshell.cachePath(filename).toString().replace(/^file:\/\//, "");
                }
                const tmpA = getPath("snip-ocr-a.png");
                const tmpB = getPath("snip-ocr-b.png");
                const outA = getPath("snip-tsv-a");
                const outB = getPath("snip-tsv-b");

                ocrTsvProc.command = ["sh", "-c", `
                    SCORE_AWK='
                        NR > 1 && $1 == "5" && $12 != "" {
                            conf = $11 + 0; w = $9 + 0; h = $10 + 0; y = $8 + 0; x = $7 + 0; word = $12; len = length(word)
                            if (h < 6 || w < 2 || conf < 15) next
                            word_score = len * conf
                            ratio = w / h
                            if (ratio > 0.2 && ratio < 15) word_score *= 1.2
                            tmp = word; gsub(/[a-zA-Z0-9]/, "", tmp); noise_chars = length(tmp)
                            if (len > 1 && noise_chars / len > 0.7) word_score *= 0.3
                            total += word_score; count++
                            bucket = int(y / (h > 0 ? h : 10)); lines[bucket]++
                        }
                        END {
                            line_bonus = 0
                            for (b in lines) {
                                if (lines[b] >= 2) line_bonus += lines[b] * 100
                                if (lines[b] >= 5) line_bonus += lines[b] * 200
                            }
                            printf "%d", total + line_bonus
                        }
                    '

                    tmpA="/dev/shm/qs-a-$(date +%s%N).pnm"
                    tmpB="/dev/shm/qs-b-$(date +%s%N).pnm"
                    
                    magick "${fullScreenshot}" ${cropParams} -colorspace Gray ${upscale} -depth 8 \
                        \\( +clone -negate -write "$tmpB" \\) "$tmpA" &&

                    tesseract "$tmpA" "${outA}" -l eng --psm ${psm} --oem 1 -c preserve_interword_spaces=1 tsv 2>/dev/null &
                    PID1=$!
                    tesseract "$tmpB" "${outB}" -l eng --psm ${psm} --oem 1 -c preserve_interword_spaces=1 tsv 2>/dev/null &
                    PID2=$!
                    wait $PID1 $PID2

                    SCORE_A=$(awk -F'\\t' "$SCORE_AWK" "${outA}.tsv")
                    SCORE_B=$(awk -F'\\t' "$SCORE_AWK" "${outB}.tsv")

                    if [ "\${SCORE_A:-0}" -ge "\${SCORE_B:-0}" ]; then
                        cat "${outA}.tsv"
                    else
                        cat "${outB}.tsv"
                    fi

                    rm -f "$tmpA" "$tmpB" "${outA}.tsv" "${outB}.tsv"
                `];
                ocrTsvProc.running = true;
            }

            function cancelOcr() {
                ocrPhase = "";
                selectMode.reset();
                if (ocrTsvProc.running) ocrTsvProc.running = false;
            }

            function initPaths() {
                cleanupHandled = false;
                const ts = Date.now();
                const sid = root.targetScreen.name.replace(/[^a-zA-Z0-9]/g, "_");
                function getPath(filename) {
                    return Quickshell.cachePath(filename).toString().replace(/^file:\/\//, "");
                }
                fullScreenshot = getPath(`snip-full-${sid}-${ts}.png`);
                cropJpg = getPath(`snip-crop-${sid}-${ts}.jpg`);
                lensHtml = getPath(`snip-lens-${sid}-${ts}.html`);
                visible = true;
                grimProc.running = true;
            }

            screen: targetScreen
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"
            visible: false

            anchors {
                left: true; right: true; top: true; bottom: true
            }

            Component.onCompleted: {
                console.log("[QuickSnip] Screen:", targetScreen?.name,
                           "Window:", width, "×", height);
                initPaths();
            }



            Settings { id: settings }

            FileView {
                id: settingsFile
                property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
                path: configHome + "/quickshell/QuickSnip/settings.json"
                onTextChanged: {
                    try {
                        const raw = (typeof text === 'function') ? text() : text;
                        if (raw?.trim().length > 0)
                            settings.source = JSON.parse(raw);
                    } catch (e) {
                        console.warn("Failed to parse settings.json:", e);
                    }
                }
            }



            LensMode {
                id: lensMode
                fullScreenshot: root.fullScreenshot
                cropJpg: root.cropJpg
                lensHtml: root.lensHtml
                browserClass: settings.browserClass
            }

            OcrMode {
                id: ocrMode
                fullScreenshot: root.fullScreenshot
            }

            SelectMode {
                id: selectMode
                stripNewlines: root.ocrSingleLine
                rawMode: root.ocrRaw
            }



            Process {
                id: grimProc
                command: targetScreen ? ["grim", "-o", targetScreen.name, fullScreenshot] : ["true"]
                onExited: (code) => {
                    if (code === 0) {
                        console.log("[QuickSnip] Screenshot captured, detecting scale...");
                        scaleDetectProc.running = true;
                    } else if (!grimReady) {
                        console.warn("[QuickSnip] grim failed (code:", code, "), retrying...");
                        retryTimer.start();
                    }
                }
            }

            Process {
                id: scaleDetectProc
                property string _output: ""
                command: ["magick", "identify", "-format", "%w", fullScreenshot]
                running: false

                stdout: StdioCollector {
                    onStreamFinished: {
                        scaleDetectProc._output = text || "";
                    }
                }

                onExited: (code) => {
                    if (code === 0 && _output.trim().length > 0) {
                        const imgWidth = parseInt(_output.trim());
                        if (imgWidth > 0 && root.width > 0) {
                            detectedMonitorScale = Math.round((imgWidth / root.width) * 100) / 100;
                        }
                        console.log("[QuickSnip] Scale:", detectedMonitorScale,
                                   "(image:", imgWidth, "px, window:", root.width, "px)");
                    } else {
                        console.warn("[QuickSnip] Scale detection failed (code:", code, "), using 1.0");
                    }
                    _output = "";
                    grimReady = true;
                    
                    if (pendingOcrRect) {
                        if (pendingOcrRect.w !== undefined)
                            startOcr(pendingOcrRect.x, pendingOcrRect.y, pendingOcrRect.w, pendingOcrRect.h);
                        else
                            startOcr();
                        pendingOcrRect = null;
                    }
                }
            }

            Process {
                id: ocrTsvProc
                property string _collected: ""
                running: false

                stdout: StdioCollector {
                    onStreamFinished: {
                        console.log("[QuickSnip] OCR stream finished, length:", text ? text.length : 0);
                        ocrTsvProc._collected = text || "";
                    }
                }
                stderr: StdioCollector {
                    onStreamFinished: console.log("[QuickSnip] OCR stderr:", text);
                }

                onExited: (code) => {
                    console.log("[QuickSnip] OCR exited:", code, "collected:", _collected.length);
                    if (code === 0 && _collected.length > 0) {
                        selectMode.words = selectMode.parseTSV(_collected);
                        selectMode.loading = false;
                        ocrPhase = "words";
                    } else {
                        console.error("[QuickSnip] OCR failed:", code);
                        cancelOcr();
                    }
                    _collected = "";
                }
            }

            Process {
                id: ocrCopyProc
                running: false
                onExited: { cleanup(); Qt.quit(); }
            }

            Process {
                id: proc
                onExited: (code) => {
                    if (code !== 0) console.error("[QuickSnip] Action failed:", code);
                    Qt.quit();
                }
            }



            Timer {
                id: retryTimer
                interval: 200
                onTriggered: { if (targetScreen) grimProc.running = true; }
            }



            Image {
                id: bgImage
                anchors.fill: parent
                z: -1
                source: grimReady ? "file://" + fullScreenshot : ""
                fillMode: Image.Stretch
                cache: false
            }

            ShaderEffect {
                anchors.fill: parent
                z: 0

                property vector4d selectionRect: {
                    if (ctsEnabled && selector.path.length > 0)
                        return Qt.vector4d(0, 0, 0, 0);
                    return Qt.vector4d(selector.selectionX, selector.selectionY,
                                      selector.selectionWidth, selector.selectionHeight);
                }
                property real dimOpacity: 0.5
                property vector2d screenSize: Qt.vector2d(root.width, root.height)
                property real borderRadius: 4
                property real outlineThickness: 1

                fragmentShader: Qt.resolvedUrl("shaders/dimming.frag.qsb")
            }

            RegionSelector {
                id: selector
                visible: ocrPhase !== "words" && ocrPhase !== "loading"
                ctsEnabled: root.ctsEnabled
                onRegionSelected: executeAction()
                onFullScreenRequested: startOcr()
                onRightClicked: {
                    path = [];
                    selectionX = selectionY = selectionWidth = selectionHeight = 0;
                }
            }

            WordOverlay {
                id: wordOverlay
                visible: ocrPhase === "loading" || ocrPhase === "words"
                words: selectMode.words
                selectedIndices: selectMode.selectedIndices
                startIndex: selectMode.startIndex
                endIndex: selectMode.endIndex
                isMultiSelect: selectMode.isMultiSelect
                regionX: selectMode.regionX
                regionY: selectMode.regionY
                regionW: selectMode.regionW
                regionH: selectMode.regionH
                monitorScale: selectMode.monitorScale
                loading: selectMode.loading

                onWordTapped: (index) => selectMode.selectWord(index)
                onWordToggled: (index) => selectMode.toggleWord(index)
                onWordRangeExtended: (index) => selectMode.extendToWord(index)
                onCtrlReleased: selectMode.convertToRange()
                onHandleStartDragged: (index) => selectMode.setStartIndex(index)
                onHandleEndDragged: (index) => selectMode.setEndIndex(index)
                onSelectAllRequested: selectMode.selectAll()

                onWordDoubleTapped: (index) => {
                    if (selectMode.selectedIndices.indexOf(index) === -1) {
                        selectMode.selectWord(index);
                    }
                    executeSmartAction(selectMode.getSelectedText());
                }

                onCopyRequested: {
                    const text = selectMode.getSelectedText();
                    if (text.length > 0)
                        copyAndQuit(text, selectMode.selectedIndices.length);
                }

                onSmartRequested: {
                    executeSmartAction(selectMode.getSelectedText());
                }

                onTranslateRequested: {
                    const text = selectMode.getSelectedText();
                    if (text.length === 0) return;
                    const query = encodeURIComponent(text);
                    openInBrowser(
                        `https://translate.google.com/?sl=auto&tl=${settings.targetLang}&text=${query}&op=translate`,
                        settings.translationOpenIn
                    );
                }

                onLensRequested: {
                    const x = selectMode.regionX * monitorScale;
                    const y = selectMode.regionY * monitorScale;
                    const w = selectMode.regionW * monitorScale;
                    const h = selectMode.regionH * monitorScale;
                    Quickshell.execDetached(["sh", "-c", lensMode.getCommand(x, y, w, h, settings.lensOpenIn)]);
                    Qt.quit();
                }
            }



            Item {
                anchors.fill: parent
                z: 999
                visible: ocrPhase !== "words"

                HoverHandler {
                    target: null
                    onPointChanged: {
                        if (!selector.pressed) {
                            selector.mouseX = point.position.x;
                            selector.mouseY = point.position.y;
                        }
                    }
                }

                Column {
                    visible: activeOcrMode !== "" && ocrPhase === ""
                    x: selector.mouseX + 15
                    y: selector.mouseY + 15
                    spacing: 4

                    Repeater {
                        model: [
                            { show: ocrDirect,     label: "Direct Copy" },
                            { show: ocrSingleLine, label: "Single Line" },
                            { show: ocrRaw,        label: "Raw Copy"    }
                        ]

                        Rectangle {
                            visible: modelData.show
                            width: modeLabel.width + 16
                            height: 24
                            radius: 12
                            color: "#cba6f7"

                            Text {
                                id: modeLabel
                                anchors.centerIn: parent
                                text: modelData.label
                                color: "#11111b"
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }
                }
            }



            Shortcut {
                sequence: "Escape"
                onActivated: { cleanup(); Qt.quit(); }
            }

            Shortcut {
                sequence: "Return"
                onActivated: {
                    if (ocrPhase === "words" && selectMode.selectedIndices.length > 0)
                        copyAndQuit(selectMode.getSelectedText(), selectMode.selectedIndices.length);
                }
            }

            Shortcut {
                sequence: "Ctrl+A"
                onActivated: { if (ocrPhase === "words") selectMode.selectAll(); }
            }

            Shortcut {
                sequence: "Ctrl+C"
                onActivated: {
                    if (ocrPhase === "words" && selectMode.selectedIndices.length > 0)
                        copyAndQuit(selectMode.getSelectedText(), selectMode.selectedIndices.length);
                }
            }

            Shortcut { sequence: "r"; onActivated: setOcrMode("raw") }
            Shortcut { sequence: "d"; onActivated: setOcrMode("direct") }
            Shortcut { sequence: "s"; onActivated: setOcrMode("single") }
        }
    }
}