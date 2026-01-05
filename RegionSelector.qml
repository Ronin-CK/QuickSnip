import QtQuick  
  
Item {  
    id: root  
      
    signal regionSelected(real x, real y, real width, real height)  
      
    // Shader customization properties  
    property real dimOpacity: 0.6  
    property real borderRadius: 10.0  
    property real outlineThickness: 2.0  
    property url fragmentShader: Qt.resolvedUrl("dimming.frag.qsb")  
      
    property point startPos  
    property real selectionX: 0  
    property real selectionY: 0  
    property real selectionWidth: 0  
    property real selectionHeight: 0  
      
    property real targetX: 0  
    property real targetY: 0  
    property real targetWidth: 0  
    property real targetHeight: 0  
      
    Behavior on selectionX { SpringAnimation { spring: 4; damping: 0.4 } }  
    Behavior on selectionY { SpringAnimation { spring: 4; damping: 0.4 } }  
    Behavior on selectionHeight { SpringAnimation { spring: 4; damping: 0.4 } }  
    Behavior on selectionWidth { SpringAnimation { spring: 4; damping: 0.4 } }  
      
    // Shader overlay  
    ShaderEffect {  
        anchors.fill: parent  
        z: 0  
          
        property vector4d selectionRect: Qt.vector4d(  
            root.selectionX,  
            root.selectionY,  
            root.selectionWidth,  
            root.selectionHeight  
        )  
        property real dimOpacity: root.dimOpacity  
        property vector2d screenSize: Qt.vector2d(root.width, root.height)  
        property real borderRadius: root.borderRadius  
        property real outlineThickness: root.outlineThickness  
          
        fragmentShader: root.fragmentShader  
    }  
      
    MouseArea {  
        id: mouseArea  
        anchors.fill: parent  
        z: 3  
          
        Timer {  
            id: updateTimer  
            interval: 16  
            repeat: true  
            running: mouseArea.pressed  
            onTriggered: {  
                root.selectionX = root.targetX  
                root.selectionY = root.targetY  
                root.selectionWidth = root.targetWidth  
                root.selectionHeight = root.targetHeight  
            }  
        }  
          
        onPressed: (mouse) => {  
            root.startPos = Qt.point(mouse.x, mouse.y)  
            root.targetX = mouse.x  
            root.targetY = mouse.y  
            root.targetWidth = 0  
            root.targetHeight = 0  
        }  
          
        onPositionChanged: (mouse) => {  
            if (pressed) {  
                const x = Math.min(root.startPos.x, mouse.x)  
                const y = Math.min(root.startPos.y, mouse.y)  
                const width = Math.abs(mouse.x - root.startPos.x)  
                const height = Math.abs(mouse.y - root.startPos.y)  
                  
                root.targetX = x  
                root.targetY = y  
                root.targetWidth = width  
                root.targetHeight = height  
            }  
        }  
          
        onReleased: {  
            root.regionSelected(  
                Math.round(root.selectionX),  
                Math.round(root.selectionY),  
                Math.round(root.selectionWidth),  
                Math.round(root.selectionHeight)  
            )  
        }  
    }  
}
