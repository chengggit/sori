import QtQuick
import QtQuick.Layouts
import "../style"

Rectangle {
    id: root

    property string iconName: "folder-open"
    property string title: ""
    property string message: ""
    property string actionText: ""
    property string actionIcon: "plus"
    property string actionVariant: "default"
    signal actionRequested()

    implicitHeight: content.implicitHeight + 64
    color: Theme.card
    radius: Theme.radiusLarge
    border.width: 0

    ColumnLayout {
        id: content
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 420)
        spacing: 10

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            radius: 16
            color: Theme.accentSoft
            Icon {
                anchors.centerIn: parent
                name: root.iconName
                size: 22
                color: Theme.accent
            }
        }
        AppText {
            Layout.alignment: Qt.AlignHCenter
            text: root.title
            font.pixelSize: 18
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
        }
        AppText {
            Layout.fillWidth: true
            text: root.message
            color: Theme.mutedForeground
            font.pixelSize: 13
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }
        AppButton {
            visible: root.actionText !== ""
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            text: root.actionText
            iconName: root.actionIcon
            variant: root.actionVariant
            onClicked: root.actionRequested()
        }
    }
}
