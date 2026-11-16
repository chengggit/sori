import QtQuick
import QtQuick.Layouts
import "../Theme.js" as Theme

Rectangle {
    id: root

    property string title: ""
    property string backLabel: ""
    property string placeholder: ""
    property bool searchVisible: false
    property string searchText: ""
    property string searchIcon: "search"
    signal backRequested()
    signal searchAccepted(string text)

    implicitHeight: 64
    color: Theme.sidebar

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.border
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        spacing: 12

        Item {
            visible: root.backLabel !== ""
            Layout.preferredWidth: backContent.implicitWidth
            Layout.fillHeight: true

            RowLayout {
                id: backContent
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Icon { name: "arrow-left"; size: 16; color: Theme.mutedForeground }
                AppText { text: root.backLabel; color: Theme.mutedForeground; font.pixelSize: 13 }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.backRequested()
            }
        }

        AppInput {
            visible: root.searchVisible
            Layout.fillWidth: true
            Layout.maximumWidth: 504
            Layout.preferredHeight: 38
            placeholderText: root.placeholder
            text: root.searchText
            iconName: root.searchIcon
            onAccepted: root.searchAccepted(text)
        }

        AppText {
            visible: !root.searchVisible
            text: root.title
            font.pixelSize: 17
            font.weight: Font.DemiBold
            Layout.fillWidth: true
        }

        Item { Layout.fillWidth: root.searchVisible }
    }
}
