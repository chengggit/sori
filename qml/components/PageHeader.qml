import QtQuick
import QtQuick.Layouts
import "../style"

Rectangle {
    id: root

    property string title: ""
    property string backLabel: ""
    property string placeholder: ""
    property bool searchVisible: false
    property string searchText: ""
    property string searchIcon: "search"
    property bool searchEnabled: true
    property int maximumContentWidth: 0
    signal backRequested()
    signal searchAccepted(string text)

    implicitHeight: 56
    color: root.searchVisible ? Theme.background : Theme.sidebar

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.border
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.maximumContentWidth > 0 ? Math.max(32, (root.width - root.maximumContentWidth) / 2) : 32
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
            id: headerSearch
            visible: root.searchVisible
            enabled: root.searchEnabled
            Layout.fillWidth: true
            Layout.maximumWidth: 460
            Layout.preferredHeight: 38
            placeholderText: root.placeholder
            text: root.searchText
            iconName: ""
            onAccepted: root.searchAccepted(text)
        }

        AppButton {
            visible: root.searchVisible
            enabled: root.searchEnabled
            iconName: root.searchIcon
            variant: "outline"
            Accessible.name: "Search"
            Layout.preferredWidth: 36
            onClicked: root.searchAccepted(headerSearch.text)
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
