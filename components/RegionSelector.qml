import QtQuick

Item {
    id: root

    property real mouseX: 0
    property real mouseY: 0
    readonly property bool pressed: mouseArea.pressed
    property real selectionX: 0
    property real selectionY: 0
    property real selectionWidth: 0
    property real selectionHeight: 0
    property point startPos
    property var path: []
    property point lastPathPoint: Qt.point(-1, -1)
    property bool ctsEnabled: false
    property real targetX: 0
    property real targetY: 0
    property real targetWidth: 0
    property real targetHeight: 0
    property bool animate: true

    signal regionSelected()
    signal fullScreenRequested()
    signal rightClicked()

    property real lastClickTime: 0

    anchors.fill: parent
    onSelectionXChanged: guides.requestPaint()
    onSelectionYChanged: guides.requestPaint()
    onSelectionWidthChanged: guides.requestPaint()
    onSelectionHeightChanged: guides.requestPaint()
    onMouseXChanged: guides.requestPaint()
    onMouseYChanged: guides.requestPaint()
    onPressedChanged: guides.requestPaint()

    Canvas {
        id: guides

        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.setLineDash([]);
            if (mouseArea.pressed && root.selectionWidth > 5 && root.selectionHeight > 5) {
                if (!(root.ctsEnabled && root.path.length > 0)) {
                    ctx.fillStyle = Qt.rgba(0.15, 0.15, 0.18, 0.3);
                    ctx.fillRect(root.selectionX, root.selectionY, root.selectionWidth, root.selectionHeight);
                }
            }
            ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.4);
            ctx.lineWidth = 2;
            ctx.beginPath();
            if (!mouseArea.pressed) {
                ctx.moveTo(root.mouseX, 0);
                ctx.lineTo(root.mouseX, height);
                ctx.moveTo(0, root.mouseY);
                ctx.lineTo(width, root.mouseY);
            } else if (!(root.ctsEnabled && root.path.length > 0)) {
                ctx.rect(root.selectionX, root.selectionY, root.selectionWidth, root.selectionHeight);
            }
            ctx.stroke();
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.8);
            ctx.lineWidth = 1;
            ctx.setLineDash([4, 4]);
            ctx.beginPath();
            if (!mouseArea.pressed) {
                ctx.moveTo(root.mouseX, 0);
                ctx.lineTo(root.mouseX, height);
                ctx.moveTo(0, root.mouseY);
                ctx.lineTo(width, root.mouseY);
            } else if (root.ctsEnabled && root.path.length > 0) {
                ctx.setLineDash([]);
                ctx.lineJoin = "round";
                ctx.lineCap = "round";
                ctx.strokeStyle = "rgba(203, 166, 247, 0.4)";
                ctx.lineWidth = 14;
                ctx.beginPath();
                ctx.moveTo(root.path[0].x, root.path[0].y);
                for (var i = 1; i < root.path.length; i++) ctx.lineTo(root.path[i].x, root.path[i].y)
                ctx.stroke();
                ctx.strokeStyle = "#cba6f7";
                ctx.lineWidth = 5;
                ctx.beginPath();
                ctx.moveTo(root.path[0].x, root.path[0].y);
                for (var j = 1; j < root.path.length; j++) ctx.lineTo(root.path[j].x, root.path[j].y)
                ctx.stroke();
                return ;
            } else {
                ctx.rect(root.selectionX, root.selectionY, root.selectionWidth, root.selectionHeight);
            }
            ctx.stroke();
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.CrossCursor
        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.rightClicked();
                return ;
            }
            root.animate = false; // Disable animations initially for the first point
            root.startPos = Qt.point(mouse.x, mouse.y);
            root.path = [Qt.point(mouse.x, mouse.y)];
            root.lastPathPoint = Qt.point(mouse.x, mouse.y);
            root.targetX = mouse.x;
            root.targetY = mouse.y;
            root.targetWidth = 0;
            root.targetHeight = 0;
            root.selectionX = mouse.x;
            root.selectionY = mouse.y;
            root.selectionWidth = 0;
            root.selectionHeight = 0;
            root.animate = true;
            guides.requestPaint();
        }
        onPositionChanged: (mouse) => {
            root.mouseX = Math.max(0, Math.min(root.width, mouse.x));
            root.mouseY = Math.max(0, Math.min(root.height, mouse.y));
            if (pressed && mouse.buttons & Qt.LeftButton) {
                const boundedX = root.mouseX;
                const boundedY = root.mouseY;
                if (root.ctsEnabled) {
                    const dx = boundedX - root.lastPathPoint.x;
                    const dy = boundedY - root.lastPathPoint.y;
                    if (dx * dx + dy * dy > 100) {
                        root.path.push(Qt.point(boundedX, boundedY));
                        root.lastPathPoint = Qt.point(boundedX, boundedY);
                        // For CTS, we update the selection bounds immediately but precisely
                        const minX = Math.min(root.selectionX, boundedX);
                        const minY = Math.min(root.selectionY, boundedY);
                        const maxX = Math.max(root.selectionX + root.selectionWidth, boundedX);
                        const maxY = Math.max(root.selectionY + root.selectionHeight, boundedY);
                        root.targetX = minX;
                        root.targetY = minY;
                        root.targetWidth = maxX - minX;
                        root.targetHeight = maxY - minY;
                        guides.requestPaint();
                    }
                } else {
                    root.targetX = Math.min(root.startPos.x, boundedX);
                    root.targetY = Math.min(root.startPos.y, boundedY);
                    root.targetWidth = Math.abs(boundedX - root.startPos.x);
                    root.targetHeight = Math.abs(boundedY - root.startPos.y);
                }
            }
        }
        onReleased: (mouse) => {
            if (mouse.button === Qt.RightButton)
                return ;

            // Snap the animated properties to their final target values immediately
            root.animate = false;
            root.selectionX = root.targetX;
            root.selectionY = root.targetY;
            root.selectionWidth = root.targetWidth;
            root.selectionHeight = root.targetHeight;
            guides.requestPaint();

            // Ignore tiny accidental clicks, require a meaningful drag
            if (root.selectionWidth > 10 && root.selectionHeight > 10) {
                root.regionSelected();
            } else {
                const now = Date.now();
                if (now - root.lastClickTime < 350) {
                    root.fullScreenRequested();
                    root.lastClickTime = 0;
                } else {
                    root.lastClickTime = now;
                }
            }
        }

        // Sync animated properties
        Timer {
            interval: 16
            repeat: true
            running: mouseArea.pressed
            onTriggered: {
                root.selectionX = root.targetX;
                root.selectionY = root.targetY;
                root.selectionWidth = root.targetWidth;
                root.selectionHeight = root.targetHeight;
            }
        }

    }

    Rectangle {
        id: sizeLabel

        visible: mouseArea.pressed && root.selectionWidth > 20
        x: root.selectionX + root.selectionWidth / 2 - width / 2
        y: root.selectionY - 35
        width: sizeLabelText.implicitWidth + 16
        height: sizeLabelText.implicitHeight + 8
        radius: 6
        color: Qt.rgba(0.12, 0.12, 0.14, 0.9)
        z: 100
        opacity: 0
        onVisibleChanged: {
            if (visible)
                opacity = 1;

        }
        Component.onCompleted: {
            if (mouseArea.pressed && root.selectionWidth > 20)
                opacity = 1;

        }

        Text {
            id: sizeLabelText

            anchors.centerIn: parent
            text: `${Math.round(root.selectionWidth)} × ${Math.round(root.selectionHeight)}`
            color: Qt.rgba(0.9, 0.9, 0.9, 1)
            font.pixelSize: 12
            font.family: "monospace"
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 100
            }

        }

        Behavior on x {
            NumberAnimation {
                duration: 50
            }

        }

        Behavior on y {
            NumberAnimation {
                duration: 50
            }

        }

    }

    Behavior on selectionX {
        enabled: root.animate

        SpringAnimation {
            spring: 4
            damping: 0.4
        }

    }

    Behavior on selectionY {
        enabled: root.animate

        SpringAnimation {
            spring: 4
            damping: 0.4
        }

    }

    Behavior on selectionWidth {
        enabled: root.animate

        SpringAnimation {
            spring: 4
            damping: 0.4
        }

    }

    Behavior on selectionHeight {
        enabled: root.animate

        SpringAnimation {
            spring: 4
            damping: 0.4
        }

    }

}
