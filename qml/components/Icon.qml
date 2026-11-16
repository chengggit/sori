pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.VectorImage
import "../Theme.js" as Theme

Item {
    id: root

    property string name: ""
    property color color: Theme.foreground
    property real size: 18

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
        layer.effect: MultiEffect {
            colorization: 1
            colorizationColor: root.color
        }
    }
}
