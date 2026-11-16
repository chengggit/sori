import QtQuick
import QtQuick.Layouts
import "../style"

Rectangle {
    id: root

    required property string currentPage
    required property bool expanded
    property int vocabularyCount: 0
    signal pageRequested(string page)
    signal settingsRequested()
    signal toggleRequested()

    implicitWidth: expanded ? 208 : 56
    color: Theme.sidebar
    clip: true
    Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    readonly property var links: [
        { page: "home", label: "Home", icon: "house" },
        { page: "explore", label: "Explore", icon: "compass" },
        { page: "library", label: "My Library", icon: "library" },
        { page: "vocabulary", label: "Vocabulary", icon: "bookmark" },
        { page: "history", label: "History", icon: "history" }
    ]

    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: Theme.border
    }

    Item {
        id: brandRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 14
        anchors.leftMargin: expanded ? 20 : 12
        anchors.rightMargin: 10
        height: 38

        AppText {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: root.expanded
            text: "sori"
            font.pixelSize: 20
            font.weight: Font.Bold
            color: Theme.accent
        }

        Item {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: brandToggle.containsMouse ? Theme.accentSoft : "transparent"
            }
            Icon {
                anchors.centerIn: parent
                name: "panel-left"
                size: 18
                color: Theme.foreground
            }
            MouseArea {
                id: brandToggle
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleRequested()
            }
        }
    }

    ColumnLayout {
        id: navigation
        anchors.top: brandRow.bottom
        anchors.topMargin: 20
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 3

        Repeater {
            model: root.links

            delegate: Item {
                id: linkItem
                required property var modelData
                readonly property bool active: root.currentPage === modelData.page

                Layout.fillWidth: true
                Layout.preferredHeight: 38

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: linkItem.active ? Theme.accentSoft
                        : linkMouse.containsMouse ? Theme.hero : "transparent"
                }

                Icon {
                    x: root.expanded ? 13 : Math.round((parent.width - width) / 2)
                    anchors.verticalCenter: parent.verticalCenter
                    name: linkItem.modelData.icon
                    size: 18
                    color: linkItem.active ? Theme.accent : Theme.mutedForeground
                }

                AppText {
                    visible: root.expanded
                    x: 41
                    anchors.verticalCenter: parent.verticalCenter
                    text: linkItem.modelData.label
                    color: linkItem.active ? Theme.accent : Theme.foreground
                    font.pixelSize: 13
                    font.weight: linkItem.active ? Font.DemiBold : Font.Normal
                }

                AppText {
                    visible: root.expanded && linkItem.modelData.page === "vocabulary"
                        && root.vocabularyCount > 0
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.vocabularyCount > 99 ? "99+" : String(root.vocabularyCount)
                    color: Theme.mutedForeground
                    font.pixelSize: 11
                }

                MouseArea {
                    id: linkMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pageRequested(linkItem.modelData.page)
                }
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: settingsRow.top
        anchors.bottomMargin: 12
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        height: 1
        color: Theme.border
    }

    Item {
        id: settingsRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        height: 38

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: settingsMouse.containsMouse ? Theme.accentSoft : "transparent"
            border.width: root.expanded ? 1 : 0
            border.color: Theme.border
        }
        Icon {
            x: root.expanded ? 13 : Math.round((parent.width - width) / 2)
            anchors.verticalCenter: parent.verticalCenter
            name: "settings"
            size: 18
            color: Theme.mutedForeground
        }
        AppText {
            visible: root.expanded
            x: 41
            anchors.verticalCenter: parent.verticalCenter
            text: "Settings"
            color: Theme.foreground
            font.pixelSize: 13
        }
        MouseArea {
            id: settingsMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.settingsRequested()
        }
    }
}
