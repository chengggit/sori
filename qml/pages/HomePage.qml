import QtQuick
import QtQuick.Layouts
import sori_qt_playback
import "../style"
import "../components"

Item {
    id: root

    signal openLibraryRequested()
    signal openVideoRequested()
    signal resumeVideoRequested(real id)
    signal openYouTubeRequested()
    signal exploreRequested()
    property string error: ""
    readonly property var recentVideo: Library.recentVideos[0] ?? null

    ExplorePage {
        anchors.fill: parent
        discovery: true
        visible: YouTube.configured
    }

    ColumnLayout {
        visible: !YouTube.configured
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
                    text: root.recentVideo ? root.recentVideo.title : "Pick up where you left off"
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.pixelSize: 25
                    font.weight: Font.DemiBold
                }
                AppText {
                    text: root.error || (root.recentVideo ? (root.recentVideo.seconds > 0
                        ? "Resume at " + Player.formatTime(root.recentVideo.seconds) : "Recently watched")
                        : "Open local Korean text or a video to get started.")
                    color: Theme.mutedForeground
                    font.pixelSize: 13
                }
                Item { Layout.fillHeight: true }
                RowLayout {
                    spacing: 8
                    AppButton {
                        visible: !!root.recentVideo
                        text: root.recentVideo?.seconds > 0 ? "Resume video" : "Watch again"
                        iconName: "play"
                        onClicked: root.resumeVideoRequested(root.recentVideo.id)
                    }
                    AppButton { text: "Open Library"; iconName: "library"; onClicked: root.openLibraryRequested() }
                    AppButton { text: "Open a video"; iconName: "play"; variant: "outline"; onClicked: root.openVideoRequested() }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: discovery.implicitHeight + 40
            radius: Theme.radiusLarge
            color: Theme.card
            border.color: Theme.border

            ColumnLayout {
                id: discovery
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 20
                spacing: 10

                AppText { text: "Discover Korean videos"; font.pixelSize: 20; font.weight: Font.DemiBold }

                RowLayout {
                    AppButton { text: "Explore"; iconName: "compass"; onClicked: root.exploreRequested() }
                    AppButton { text: "Paste YouTube link"; variant: "outline"; onClicked: root.openYouTubeRequested() }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
