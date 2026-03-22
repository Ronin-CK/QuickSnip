import Qt5Compat.GraphicalEffects
import QtQuick

FocusScope {
    id: root

    property var words: []

    property var selectedIndices: []
    property int startIndex: -1
    property int endIndex: -1

    property real regionX: 0
    property real regionY: 0
    property real regionW: 0
    property real regionH: 0
    property real monitorScale: 1
    property bool loading: false
    property bool isMultiSelect: false

    readonly property bool hasSelection: selectedIndices.length > 0
    readonly property int firstIdx: hasSelection ? Math.min(startIndex, endIndex) : -1
    readonly property int lastIdx: hasSelection ? Math.max(startIndex, endIndex) : -1
    readonly property color accentColor: "#cba6f7"
    readonly property real minTouchSize: 28

    property bool ctrlHeld: false

    readonly property var selectionSet: {
        let s = ({});
        for (let i = 0; i < selectedIndices.length; i++)
            s[selectedIndices[i]] = true;
        return s;
    }

    signal wordTapped(int index)
    signal wordDoubleTapped(int index)
    signal wordToggled(int index)
    signal wordRangeExtended(int index)
    signal handleStartDragged(int index)
    signal handleEndDragged(int index)
    signal copyRequested()
    signal translateRequested()
    signal smartRequested()
    signal selectAllRequested()
    signal lensRequested()
    signal ctrlReleased()

    anchors.fill: parent
    z: 50
    focus: visible

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Control) ctrlHeld = true;
    }
    Keys.onReleased: (event) => {
        if (event.key === Qt.Key_Control) {
            ctrlHeld = false;
            ctrlReleased();
        }
    }

    onVisibleChanged: {
        if (visible) forceActiveFocus();
    }



    // Find the nearest word to (px, py)
    function findNearestWord(px, py, maxDist) {
        let minDist = Infinity;
        let nearest = -1;
        const thresholdSq = maxDist !== undefined ? maxDist * maxDist : Infinity;

        for (let i = 0, len = words.length; i < len; i++) {
            const w = words[i];
            const wx = regionX + (w.x / monitorScale);
            const wy = regionY + (w.y / monitorScale);
            const ww = w.width / monitorScale;
            const wh = w.height / monitorScale;

            // Short-circuit: check if point is inside the word box first (zero distance)
            if (px >= wx && px <= wx + ww && py >= wy && py <= wy + wh) return i;

            // Otherwise calc distance to nearest edge
            const dx = Math.max(0, wx - px, px - (wx + ww));
            const dy = Math.max(0, wy - py, py - (wy + wh));
            const distSq = dx * dx + dy * dy;

            if (distSq < minDist && distSq <= thresholdSq) {
                minDist = distSq;
                nearest = i;
            }
        }
        return nearest;
    }

    function handleWordClick(index, mouse) {
        if (mouse.modifiers & Qt.ControlModifier)
            wordToggled(index);
        else if (mouse.modifiers & Qt.ShiftModifier)
            wordRangeExtended(index);
        else {
            if (root.selectedIndices.indexOf(index) !== -1) {
                return;
            }
            wordTapped(index);
        }
    }

    function handleWordDoubleClick(index) {
        wordDoubleTapped(index);
    }

    function wX(i) { return i >= 0 && i < words.length ? regionX + words[i].x / monitorScale : 0 }
    function wY(i) { return i >= 0 && i < words.length ? regionY + words[i].y / monitorScale : 0 }
    function wW(i) { return i >= 0 && i < words.length ? words[i].width / monitorScale : 0 }
    function wH(i) { return i >= 0 && i < words.length ? words[i].height / monitorScale : 0 }



    MouseArea {
        anchors.fill: parent
        z: 0
        onClicked: (mouse) => {
            const idx = root.findNearestWord(mouse.x, mouse.y, 60);
            if (idx >= 0) root.handleWordClick(idx, mouse);
        }
        onDoubleClicked: (mouse) => {
            const idx = root.findNearestWord(mouse.x, mouse.y, 60);
            if (idx >= 0) root.handleWordDoubleClick(idx);
        }
    }



    Repeater {
        model: root.words

        Rectangle {
            id: wordRect
            required property var modelData
            required property int index

            readonly property bool isSelected: root.selectionSet[index] === true
            readonly property real rawW: (modelData.width / root.monitorScale) + 6
            readonly property real rawH: (modelData.height / root.monitorScale) + 6
            readonly property real displayW: Math.max(rawW, root.minTouchSize)
            readonly property real displayH: Math.max(rawH, root.minTouchSize)

            x: root.regionX + (modelData.x / root.monitorScale) - 3 - (displayW - rawW) / 2
            y: root.regionY + (modelData.y / root.monitorScale) - 3 - (displayH - rawH) / 2
            width: displayW
            height: displayH
            color: "transparent"
            radius: 4
            z: 1

            Rectangle {
                anchors.centerIn: parent
                width: wordRect.rawW
                height: wordRect.rawH
                radius: 4
                color: {
                    if (wordRect.isSelected)
                        return Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.4);
                    if (wordMouse.containsMouse)
                        return Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.2);

                    return Qt.rgba(0.5, 0.5, 0.5, 0.35);
                }

                Behavior on color { ColorAnimation { duration: 100 } }
            }

            MouseArea {
                id: wordMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => root.handleWordClick(wordRect.index, mouse)
                onDoubleClicked: (mouse) => root.handleWordDoubleClick(wordRect.index)
            }
        }
    }



    component SelectionHandle: Item {
        property bool isEnd: false
        signal dragged(int index)

        visible: root.hasSelection && !root.isMultiSelect
        width: 24; height: 30; z: 200

        x: isEnd
            ? root.wX(root.lastIdx) + root.wW(root.lastIdx) - width / 2
            : root.wX(root.firstIdx) - width / 2
        y: isEnd
            ? root.wY(root.lastIdx) + root.wH(root.lastIdx)
            : root.wY(root.firstIdx) + root.wH(root.firstIdx)

        Rectangle {
            width: 2.5; height: 14; radius: 1
            color: root.accentColor
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
        }

        Rectangle {
            width: 14; height: 14; radius: 7
            color: root.accentColor
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom

            Rectangle {
                width: 4; height: 4; radius: 2
                color: "white"
                anchors.centerIn: parent
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -2
            cursorShape: Qt.SizeAllCursor
            preventStealing: true
            onPositionChanged: (mouse) => {
                if (pressed) {
                    const gp = mapToItem(root, mouse.x, mouse.y);
                    const idx = root.findNearestWord(gp.x, gp.y);
                    if (idx >= 0) parent.dragged(idx);
                }
            }
        }
    }

    SelectionHandle {
        isEnd: false
        onDragged: (index) => root.handleStartDragged(index)
    }

    SelectionHandle {
        isEnd: true
        onDragged: (index) => root.handleEndDragged(index)
    }



    component ToolbarButton: Rectangle {
        id: btn
        property string icon: ""
        property string label: ""
        property color iconColor: Qt.rgba(0.75, 0.75, 0.75, 0.95)
        property string shortcutHint: ""
        signal clicked()

        width: btnRow.width + 20; height: 30; radius: 15
        color: btnMouse.pressed
            ? Qt.rgba(1, 1, 1, 0.2)
            : btnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
        anchors.verticalCenter: parent.verticalCenter

        Behavior on color { ColorAnimation { duration: 80 } }

        scale: btnMouse.pressed ? 0.94 : btnMouse.containsMouse ? 1.05 : 1.0
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        Row {
            id: btnRow
            anchors.centerIn: parent
            spacing: 7

            Text {
                text: btn.icon; color: btn.iconColor
                font.pixelSize: 20; font.family: "Symbols Nerd Font"
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: btn.label; color: Qt.rgba(1, 1, 1, 0.9)
                opacity: btnMouse.containsMouse ? 1.0 : 0.8
                font.pixelSize: 15
                font.weight: 50
                font.letterSpacing: 0
                anchors.verticalCenter: parent.verticalCenter
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }
        }

        Rectangle {
            visible: btnMouse.containsMouse && btn.shortcutHint !== ""
            y: -height - 10
            anchors.horizontalCenter: parent.horizontalCenter
            width: hintText.contentWidth + 18
            height: 24; radius: 8
            color: Qt.rgba(0.06, 0.06, 0.08, 0.94)
            border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1

            opacity: btnMouse.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 100 } }

            Text {
                id: hintText
                anchors.centerIn: parent
                text: btn.shortcutHint
                color: Qt.rgba(1, 1, 1, 0.6)
                font.pixelSize: 12; font.weight: 50
            }
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    component ToolbarSeparator: Rectangle {
        width: 1; height: 16
        color: Qt.rgba(1, 1, 1, 0.1)
        anchors.verticalCenter: parent.verticalCenter
    }



    Rectangle {
        id: actionToolbar
        visible: root.hasSelection
        z: 300
        width: toolbarRow.width + 24; height: 38; radius: 19
        color: Qt.rgba(0.1, 0.1, 0.12, 0.95)
        border.color: Qt.rgba(1, 1, 1, 0.2); border.width: 1

        x: {
            if (!root.hasSelection) return 0;
            const sx = root.wX(root.firstIdx);
            const ex = root.wX(root.lastIdx) + root.wW(root.lastIdx);
            const center = (sx + ex) / 2;
            return Math.max(12, Math.min(center - width / 2, root.width - width - 12));
        }

        y: {
            if (!root.hasSelection) return 0;
            const above = root.wY(root.firstIdx) - height - 16;
            if (above > 12) return above;
            return root.wY(root.lastIdx) + root.wH(root.lastIdx) + 40;
        }


        Row {
            id: toolbarRow
            anchors.centerIn: parent
            spacing: 4

            ToolbarButton { icon: "󰍉"; label: "Search"; shortcutHint: "Double-click"; onClicked: root.smartRequested() }
            ToolbarSeparator {}
            ToolbarButton { icon: "󰆏"; label: "Copy"; shortcutHint: "Ctrl+C"; onClicked: root.copyRequested() }
            ToolbarSeparator {}
            ToolbarButton { icon: "󰊿"; label: "Translate"; onClicked: root.translateRequested() }
            ToolbarSeparator {}
            ToolbarButton { icon: "󰒆"; label: "All"; shortcutHint: "Ctrl+A"; iconColor: Qt.rgba(1, 1, 1, 0.5); onClicked: root.selectAllRequested() }
        }
    }



    component StatusPill: Rectangle {
        property alias text: pillText.text
        property bool showSpinner: false

        x: root.regionX + (root.regionW / 2) - (width / 2)
        y: root.regionY + (root.regionH / 2) - (height / 2)
        width: pillRow.width + 32; height: 40; radius: 20
        color: "transparent"
        border.color: Qt.rgba(0.7, 0.63, 0.55, 0.15); border.width: 1
        z: 100

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(0.1, 0.1, 0.12, 0.9)
        }

        FastBlur {
            source: parent.children[1]
            radius: 15
            anchors.fill: parent.children[1]
        }

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 10

            Rectangle {
                visible: showSpinner
                width: 14; height: 14; radius: 7
                color: "transparent"
                border.color: Qt.rgba(0.75, 0.75, 0.75, 0.7); border.width: 2
                anchors.verticalCenter: parent.verticalCenter

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 600 }
                    NumberAnimation { to: 1; duration: 600 }
                }
            }

            Text {
                id: pillText
                color: showSpinner ? Qt.rgba(0.8, 0.8, 0.8, 1) : Qt.rgba(0.7, 0.7, 0.7, 0.9)
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    StatusPill {
        visible: root.loading
        text: "Extracting text…"
        showSpinner: true
    }

    StatusPill {
        visible: !root.loading && root.words.length === 0
        text: "No text found"
    }



    Item {
        id: selectionArea
        x: root.regionX; y: root.regionY
        width: root.regionW; height: root.regionH
    }

    Rectangle {
        id: lensButton
        visible: true
        anchors.right: selectionArea.right
        anchors.bottom: selectionArea.bottom
        anchors.margins: 8
        width: 44; height: 44; radius: 22
        color: Qt.rgba(0.12, 0.12, 0.14, 0.9)
        border.color: Qt.rgba(1, 1, 1, 0.2); border.width: 1
        z: 100
        
        scale: lensMouse.pressed ? 0.94 : lensMouse.containsMouse ? 1.05 : 1.0
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        Image {
            id: lensIcon
            anchors.centerIn: parent
            source: Qt.resolvedUrl("../assets/lens-white.svg")
            width: 22; height: 22
            sourceSize: Qt.size(22, 22)
            opacity: lensMouse.containsMouse ? 1.0 : 0.85
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }

        MouseArea {
            id: lensMouse
            anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.lensRequested()

            Rectangle {
                visible: parent.containsMouse
                y: -height - 8
                anchors.horizontalCenter: parent.horizontalCenter
                width: tooltipText.contentWidth + 16
                height: 28; radius: 6
                color: Qt.rgba(0, 0, 0, 0.9)

                Text {
                    id: tooltipText
                    anchors.centerIn: parent
                    text: "Search Image (Lens)"
                    color: "white"; font.pixelSize: 12
                }
            }
        }
    }
}