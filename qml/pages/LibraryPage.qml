import QtQuick
import QtQuick.Layouts
import "../Theme.js" as Theme
import "../components"

Item {
    id: root

    signal openReaderRequested(int documentId)
    signal openWatchRequested(int videoId)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 20

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                spacing: 4
                Layout.fillWidth: true
                AppText { text: "My Library"; font.pixelSize: 26; font.weight: Font.DemiBold }
                AppText {
                    text: "Your Korean reading and watching materials."
                    color: Theme.mutedForeground
                    font.pixelSize: 13
                }
            }
            AppButton { text: "Import"; iconName: "plus" }
        }

        RowLayout {
            Layout.fillWidth: true
            AppInput {
                Layout.fillWidth: true
                Layout.maximumWidth: 440
                placeholderText: "Search your library"
                iconName: "search"
            }
            Item { Layout.fillWidth: true }
            AppText { text: "0 items"; color: Theme.mutedForeground; font.pixelSize: 12 }
        }

        EmptyState {
            Layout.fillWidth: true
            Layout.fillHeight: true
            iconName: "library"
            title: "Your library is empty"
            message: "Import a Korean text file or a local video with subtitles. Library storage is not connected yet."
            actionText: "Import content"
        }
    }
}
