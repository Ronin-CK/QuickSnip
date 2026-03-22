import QtQuick

QtObject {
    // Trust the upstream TSV parsing and do not filter out small alphanumeric
    // characters or punctuation (I, |, ., ,, -, etc).

    id: root

    // Cached regex patterns for performance
    // [OPTIMIZATION] Consolidated regex patterns for better performance
    readonly property var strictUrlRegex: /^(https?:\/\/.*|www\..*|([a-zA-Z0-9-]+\.)+(com|org|net|io|co|us|uk|dev|app|me|info|edu|gov|tv|ai|gg|to|ru|de|cn|jp|br|eu|in)(\/.*)?|(\d{1,3}\.){3}\d{1,3}(:\d+)?(\/.*)?)$/i
    readonly property var codeRegex: /\{|\}|;|function|const|var|let|if|while|import|return/g
    readonly property var urlRegex5: /[^\s]*(https?:\/\/|www\.)[^\s]*/i
    property var words: []
    property int startIndex: -1
    property int endIndex: -1
    property var selectedIndices: []
    property bool loading: false
    property real regionX: 0
    property real regionY: 0
    property real regionW: 0
    property real regionH: 0
    property real monitorScale: 1
    property bool stripNewlines: false
    property bool rawMode: false
    property bool isMultiSelect: false

    function parseTSV(text) {
        var lines = text.trim().split("\n");
        var result = [];
        for (var i = 1; i < lines.length; i++) {
            var cols = lines[i].split("\t");
            if (cols.length >= 12 && cols[0].trim() === "5" && cols[11].trim().length > 0) {
                var word = cols[11].trim();
                var conf = parseFloat(cols[10]);
                var w = parseInt(cols[8]);
                var h = parseInt(cols[9]);
                // Relaxed filtering: Since the bash script's `score_tsv` function already
                // heavily penalizes noise passes, we can trust the winning TSV much more.
                // We only drop obvious artifacts (tiny specks).
                if (w < 2 || h < 2)
                    continue;

                result.push({
                    "text": word,
                    "x": parseInt(cols[6]),
                    "y": parseInt(cols[7]),
                    "width": w,
                    "height": h,
                    "conf": conf,
                    "lineNum": parseInt(cols[4]),
                    "parNum": parseInt(cols[3]),
                    "blockNum": parseInt(cols[2]),
                    "index": result.length
                });
            }
        }
        return result;
    }

    function selectWord(index) {
        isMultiSelect = false;
        startIndex = index;
        endIndex = index;
        updateSelection();
    }

    function toggleWord(index) {
        if (index < 0 || index >= words.length)
            return ;

        var arr;
        if (!isMultiSelect) {
            // Convert current range to array, then toggle
            arr = selectedIndices.slice();
            isMultiSelect = true;
        } else {
            arr = selectedIndices.slice();
        }
        var pos = arr.indexOf(index);
        if (pos >= 0)
            arr.splice(pos, 1);
        else
            arr.push(index);
        arr.sort(function(a, b) {
            return a - b;
        });
        selectedIndices = arr;
        if (arr.length > 0) {
            startIndex = arr[0];
            endIndex = arr[arr.length - 1];
        } else {
            startIndex = -1;
            endIndex = -1;
            isMultiSelect = false;
        }
    }

    function extendToWord(index) {
        if (index < 0 || index >= words.length)
            return ;

        if (startIndex < 0) {
            selectWord(index);
            return ;
        }
        isMultiSelect = false;
        endIndex = index;
        updateSelection();
    }

    function setStartIndex(index) {
        isMultiSelect = false;
        startIndex = index;
        updateSelection();
    }

    function setEndIndex(index) {
        isMultiSelect = false;
        endIndex = index;
        updateSelection();
    }

    function selectAll() {
        if (words.length === 0)
            return ;

        isMultiSelect = false;
        startIndex = 0;
        endIndex = words.length - 1;
        updateSelection();
    }

    function convertToRange() {
        isMultiSelect = false;
    }

    function updateSelection() {
        if (startIndex < 0 || endIndex < 0) {
            selectedIndices = [];
            return ;
        }
        var minI = Math.min(startIndex, endIndex);
        var maxI = Math.max(startIndex, endIndex);
        var arr = [];
        for (var i = minI; i <= maxI; i++) arr.push(i)
        selectedIndices = arr;
    }

    function getSelectedText(forcedIndex = -1) {
        if (forcedIndex >= 0) {
            var indices = [forcedIndex];
        } else {
            if (selectedIndices.length === 0)
                return "";

            var indices = selectedIndices.slice().sort(function(a, b) {
                return a - b;
            });
        }
        var result = "";
        var lastLine = -1;
        var lastPar = -1;
        var lastBlock = -1;
        var pendingHyphen = false;
        var prevIdx = -1;
        for (var ii = 0; ii < indices.length; ii++) {
            var i = indices[ii];
            var word = words[i].text;
            if (lastLine >= 0) {
                if (root.rawMode) {
                    if (words[i].lineNum !== lastLine)
                        result += "\n";
                    else
                        result += " ";
                } else {
                    if (words[i].blockNum !== lastBlock || words[i].parNum !== lastPar) {
                        result += "\n\n";
                        pendingHyphen = false;
                    } else if (words[i].lineNum !== lastLine) {
                        if (pendingHyphen)
                            pendingHyphen = false;
                        else
                            result += " ";
                    } else {
                        if (prevIdx >= 0) {
                            var prevWord = words[prevIdx];
                            var currentWord = words[i];
                            var gap = currentWord.x - (prevWord.x + prevWord.width);
                            var isUrl = root.urlRegex5.test(result);
                            var threshold = isUrl ? 10 : 6;
                            if (gap > threshold)
                                result += " ";

                        } else {
                            result += " ";
                        }
                    }
                }
            }
            var nextInSelection = ii + 1 < indices.length ? indices[ii + 1] : -1;
            if (!root.rawMode && nextInSelection >= 0 && words[nextInSelection].lineNum !== words[i].lineNum && word.endsWith("-") && word.length > 2) {
                result += word.substring(0, word.length - 1);
                pendingHyphen = true;
            } else {
                result += word;
                pendingHyphen = false;
            }
            lastLine = words[i].lineNum;
            lastPar = words[i].parNum;
            lastBlock = words[i].blockNum;
            prevIdx = i;
        }
        var cleaned = result.replace(/ +/g, " ").trim();
        if (root.stripNewlines)
            cleaned = cleaned.replace(/\n+/g, " ");

        return cleaned;
    }

    function cleanUrl(text) {
        var url = text.trim().replace(/\s+/g, '');
        url = url.replace(/[|]/g, 'l');
        url = url.replace(/[{}\[\]<>]/g, '');
        url = url.replace(/,,/g, ',');
        url = url.replace(/\.\./g, '.');
        if (!url.match(/^https?:\/\//i)) {
            if (url.startsWith("www."))
                url = "https://" + url;
            else if (url.match(/^[a-zA-Z0-9-]+\.[a-zA-Z]{2,}/))
                url = "https://" + url;
        }
        return url;
    }

    function analyzeText(text, aiThreshold) {
        if (!text)
            return "search";

        const trimmed = text.trim();
        const noSpaces = trimmed.replace(/\s+/g, '');
        if (strictUrlRegex.test(noSpaces))
            return "url";

        const codeMatches = trimmed.match(codeRegex);
        if (codeMatches && codeMatches.length > 3)
            return "code";

        const words = trimmed.split(/\s+/).filter((w) => {
            return w.length > 0;
        });
        if (words.length <= 2) {
            // Check if it looks like a file path or complex query
            if (/[.\/\\?&=]/.test(trimmed))
                return "search";

            return "dictionary";
        }
        if (words.length >= (aiThreshold || 15))
            return "ai";

        return "search";
    }

    function sanitizeText(text) {
        if (!text)
            return "";

        // [SECURITY] Strip control characters and non-printable sequences
        return text.replace(/[\x00-\x1F\x7F-\x9F]/g, "");
    }

    function reset() {
        words = [];
        selectedIndices = [];
        startIndex = -1;
        endIndex = -1;
        loading = false;
        isMultiSelect = false;
    }

}
