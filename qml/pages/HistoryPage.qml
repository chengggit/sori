import QtQuick
import QtQuick.Layouts
import "../Theme.js" as Theme
import "../components"

Item {
    id: root

    signal exploreRequested()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 20

        AppText { text: "History"; font.pixelSize: 26; font.weight: Font.DemiBold }
        AppText {
            text: "Recently watched videos and your playback progress."
            color: Theme.mutedForeground
            font.pixelSize: 13
        }
        EmptyState {
            Layout.fillWidth: true
            Layout.fillHeight: true
            iconName: "history"
            title: "No watch history yet"
            message: "Videos you play in Sori will appear here once playback history is connected."
            actionText: "Explore videos"
            onActionRequested: root.exploreRequested()
        }
    }
}
