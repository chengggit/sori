pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.VectorImage
import QtQuick.Window
import "../style"

Item {
    id: root

    property string name: ""
    property color color: Theme.foreground
    property real size: 18

    // Colorization has to go through a texture. Render it at twice the on-screen
    // size (and never below 32px) so small icons keep clean, antialiased strokes
    // instead of turning into blurry blobs when zoomed out.
    readonly property real rasterSize: Math.max(size * Theme.pageScale * 2, 32)
        * (Screen.devicePixelRatio || 1)

    implicitWidth: size
    implicitHeight: size

    VectorImage {
        anchors.fill: parent
        source: root.name === "" ? "" : "qrc:/qml/icons/" + root.name + ".svg"
        fillMode: VectorImage.PreserveAspectFit
        preferredRendererType: VectorImage.CurveRenderer
        visible: root.name !== ""
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(Math.ceil(root.rasterSize), Math.ceil(root.rasterSize))
        layer.effect: MultiEffect {
            colorization: 1
            colorizationColor: root.color
        }
    }
}
