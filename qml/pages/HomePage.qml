import QtQuick
import QtQuick.Layouts
import "../Theme.js" as Theme
import "../components"

Item {
    id: root

    signal openLibraryRequested()
    signal openVideoRequested()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 24

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 188
            radius: Theme.radiusLarge
            color: Theme.hero
            border.width: 1
            border.color: Theme.chip

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 8

                AppText {
                    text: "CONTINUE LEARNING"
                    color: Theme.accent
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.2
                }
                AppText {
                    text: "Pick up where you left off"
                    font.pixelSize: 25
                    font.weight: Font.DemiBold
                }
                AppText {
                    text: "Your recent reading and watching activity will appear here."
                    color: Theme.mutedForeground
                    font.pixelSize: 13
                }
                Item { Layout.fillHeight: true }
                RowLayout {
                    spacing: 8
                    AppButton { text: "Open Library"; iconName: "library"; onClicked: root.openLibraryRequested() }
                    AppButton { text: "Open a video"; iconName: "play"; variant: "outline"; onClicked: root.openVideoRequested() }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            AppText { text: "Discover"; font.pixelSize: 24; font.weight: Font.DemiBold; Layout.fillWidth: true }
            AppText { text: "Korean media picked for you"; color: Theme.mutedForeground; font.pixelSize: 13 }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: ["All", "Daily life", "Vlogs", "Food", "Travel", "Culture", "Grammar"]
                delegate: Rectangle {
                    required property string modelData
                    width: chipLabel.implicitWidth + 26
                    height: 30
                    radius: 15
                    color: modelData === "All" ? Theme.accent : Theme.card
                    border.width: modelData === "All" ? 0 : 1
                    border.color: Theme.border
                    AppText {
                        id: chipLabel
                        anchors.centerIn: parent
                        text: modelData
                        color: modelData === "All" ? "#ffffff" : Theme.foreground
                        font.pixelSize: 12
                    }
                }
            }
        }

        EmptyState {
            Layout.fillWidth: true
            Layout.fillHeight: true
            iconName: "compass"
            title: "Discover is ready for its data source"
            message: "The Home layout is ported. YouTube discovery and saved progress will be connected in a later frontend step."
            actionText: "Browse Library"
            onActionRequested: root.openLibraryRequested()
        }
    }
}
