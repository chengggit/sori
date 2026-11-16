import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sori_qt_playback
import "../style"
import "../components"

Item {
    id: root

    property string error: ""
    signal openLibraryRequested()
    signal openWatchRequested(var entry)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 16

        AppText {
            visible: text !== ""
            text: root.error
            color: Theme.destructive
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }

        ListView {
            id: history
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: count > 0
            clip: true
            spacing: 8
            model: Library.recentVideos.concat(Library.youtubeHistory)
                .sort((a, b) => (b.watchedAt ?? 0) - (a.watchedAt ?? 0))
            ScrollBar.vertical: ScrollBar {}

            delegate: Rectangle {
                id: row
                required property var modelData
                width: ListView.view.width
                height: 70
                color: Theme.card
                border.color: Theme.border
                radius: Theme.radiusSmall

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Icon { name: "film"; color: Theme.accent }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        AppText {
                            Layout.fillWidth: true
                            text: row.modelData.title
                            elide: Text.ElideRight
                        }
                        AppText {
                            text: row.modelData.seconds > 0
                                ? "Resume at " + Player.formatTime(row.modelData.seconds) : "Recently watched"
                            color: Theme.mutedForeground
                            font.pixelSize: 12
                        }
                    }
                    AppButton {
                        text: row.modelData.seconds > 0 ? "Resume" : "Watch again"
                        variant: "outline"
                        small: true
                        onClicked: root.openWatchRequested(row.modelData)
                    }
                }
            }
        }

        EmptyState {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: history.count === 0
            iconName: "history"
            title: "No watch history yet"
            message: "Local and YouTube videos you watch in Sori will appear here."
            actionText: "Open Library"
            onActionRequested: root.openLibraryRequested()
        }
    }
}
