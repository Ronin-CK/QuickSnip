import QtQuick

QtObject {
    id: root

    property var source: ({
    })
    readonly property string searchEngine: _get("Search", "engine", "brave")
    readonly property string searchOpenIn: _get("Search", "open_in", "sidebar")
    readonly property string selectionStyle: _get("Selection", "style", "rectangle")
    readonly property string targetLang: _get("Translation", "target_lang", "en")
    readonly property string translationOpenIn: _get("Translation", "open_in", "sidebar")
    readonly property string aiProvider: _get("AI", "provider", "gemini")
    readonly property string aiOpenIn: _get("AI", "open_in", "sidebar")
    readonly property string lensOpenIn: _get("Lens", "open_in", "newtab")
    readonly property int smartAiThreshold: _get("Smart", "ai_threshold", 15)
    readonly property string smartOpenIn: _get("Smart", "open_in", "sidebar")
    readonly property string browserClass: _get("Browser", "class", "zen")

    function _get(section, key, fallback) {
        if (!source || !source[section]) return fallback;
        let val = source[section][key];
        return (val !== undefined && val !== null) ? val : fallback;
    }

}
