import QtQuick
import QtQuick.Layouts
import "../Theme.js" as Theme
import "../components"

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 20

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                spacing: 4
                Layout.fillWidth: true
                AppText { text: "Vocabulary"; font.pixelSize: 26; font.weight: Font.DemiBold }
                AppText {
                    text: "Words saved while reading and watching."
                    color: Theme.mutedForeground
                    font.pixelSize: 13
                }
            }
            AppText { text: "0 saved"; color: Theme.mutedForeground; font.pixelSize: 12 }
        }

        AppInput {
            Layout.fillWidth: true
            Layout.maximumWidth: 440
            placeholderText: "Search vocabulary"
            iconName: "search"
        }

        EmptyState {
            Layout.fillWidth: true
            Layout.fillHeight: true
            iconName: "bookmark"
            title: "No saved vocabulary yet"
            message: "Words you save from the reader or subtitles will appear here with their meanings, tags, and original context."
        }
    }
}
