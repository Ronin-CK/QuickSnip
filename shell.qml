import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root
    Component.onCompleted: {
        console.log("HyprQuickSnip loaded")
    }

    UniversalSnip {
        id: snip
    }
}

