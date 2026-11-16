import QtQuick
import QtQuick.Controls
import "../style"

TextField {
    id: control

    property string iconName: ""

    implicitHeight: Theme.inputHeight
    leftPadding: iconName === "" ? 12 : 36
    rightPadding: 12
    color: Theme.foreground
    placeholderTextColor: Theme.mutedForeground
    selectionColor: Theme.accent
    selectedTextColor: Theme.onAccent
    font.family: "Inter"
    font.pixelSize: 13

    background: Rectangle {
        radius: Theme.radius
        color: Theme.card
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Theme.accent : Theme.border

        Icon {
            visible: control.iconName !== ""
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            name: control.iconName
            size: 16
            color: Theme.mutedForeground
        }
    }
}
