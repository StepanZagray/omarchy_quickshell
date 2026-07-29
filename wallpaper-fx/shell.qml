import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Experiment: sample the current omarchy wallpaper and run a filter
// shader over it. Not a procedural background — the photo is the input.
//
// Launch:
//   qs -n -d -c wallpaper-fx
//
// IPC:
//   qs -c wallpaper-fx ipc call fx pick 0   # passthrough (image only)
//   qs -c wallpaper-fx ipc call fx pick 1   # ripple
//   qs -c wallpaper-fx ipc call fx next
//   qs -c wallpaper-fx ipc call fx reload   # re-read wallpaper symlink
//
// Stop + restore omarchy wallpaper:
//   pkill -f 'qs -n -d -c wallpaper-fx'
//   omarchy theme bg set ~/.config/omarchy/current/background
ShellRoot {
    id: root

    property int fxIndex: 1

    readonly property var fxList: [
        "shaders/passthrough.frag.qsb",
        "shaders/ripple.frag.qsb"
    ]
    readonly property int fxCount: fxList.length

    // Symlink omarchy keeps current; bumping wallpaperToken forces Image reload.
    property int wallpaperToken: 0
    readonly property string wallpaperPath: Quickshell.env("HOME")
        + "/.config/omarchy/current/background"

    IpcHandler {
        target: "fx"
        function next(): void {
            root.fxIndex = (root.fxIndex + 1) % root.fxCount;
        }
        function prev(): void {
            root.fxIndex = (root.fxIndex - 1 + root.fxCount) % root.fxCount;
        }
        function pick(i: int): void {
            root.fxIndex = ((i % root.fxCount) + root.fxCount) % root.fxCount;
        }
        function reload(): void {
            root.wallpaperToken += 1;
        }
    }

    // One background surface per monitor (otherwise only the "primary"
    // screen gets a layer — typically HDMI, not the laptop panel).
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: wp
            required property var modelData
            screen: modelData

            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "wallpaper-fx"
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}

            property real elapsed: 0

            Timer {
                interval: 16
                repeat: true
                running: true
                onTriggered: wp.elapsed += 0.016
            }

            // Wallpaper texture source — hidden; ShaderEffect samples it.
            Image {
                id: wall
                anchors.fill: parent
                // Token in query string busts Qt's image cache after `fx reload`
                // or `omarchy theme bg next` + reload.
                source: "file://" + root.wallpaperPath + "?t=" + root.wallpaperToken
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
                layer.enabled: true
            }

            // Fallback while the image is loading / missing.
            Rectangle {
                anchors.fill: parent
                color: "#181616"
                visible: wall.status !== Image.Ready
            }

            ShaderEffect {
                anchors.fill: parent
                visible: wall.status === Image.Ready
                // Name must match sampler2D in the .frag
                property variant src: wall
                property real iTime: wp.elapsed
                property size iResolution: Qt.size(width, height)
                fragmentShader: root.fxList[root.fxIndex]
            }
        }
    }
}
