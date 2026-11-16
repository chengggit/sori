import QtQuick
import QtQuick.Layouts
import sori_qt_playback
import "../style"
import "../components"

ExplorePage {
    id: home

    signal openLibraryRequested()
    signal openVideoRequested()
    signal resumeVideoRequested(real id)
    property string resumeError: ""
    readonly property var recentVideo: Library.recentVideos[0] ?? null

    discovery: true
    leadingContent: Rectangle {
        implicitHeight: home.recentVideo ? 248 : 150
        radius: Theme.radiusLarge
        color: Theme.dark ? Theme.hero : "#e4ebda"
        border.color: Theme.chip

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 16

            AppText {
                text: "CONTINUE WATCHING"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
            }

            Rectangle {
                visible: !!home.recentVideo
                Layout.fillWidth: true
                Layout.preferredHeight: 126
                radius: 14
                color: Theme.dark ? Theme.card : "#f3f7f1"

                RowLayout {
                    anchors.fill: parent
                    anchors.rightMargin: 20
                    spacing: 20

                    Rectangle {
                        Layout.preferredWidth: Math.min(224, parent.width * 0.28)
                        Layout.fillHeight: true
                        radius: 14
                        color: Theme.accentSoft
                        Icon {
                            anchors.centerIn: parent
                            name: "film"
                            size: 32
                            color: Theme.accent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        AppText {
                            Layout.fillWidth: true
                            text: home.recentVideo?.title ?? ""
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        AppText {
                            Layout.fillWidth: true
                            text: home.resumeError || (home.recentVideo?.seconds > 0
                                ? Player.formatTime(home.recentVideo.seconds) : "Recently watched")
                            color: home.resumeError ? Theme.destructive : Theme.mutedForeground
                            elide: Text.ElideRight
                        }
                    }

                    AppButton {
                        text: home.recentVideo?.seconds > 0 ? "Resume" : "Watch again"
                        iconName: "play"
                        small: true
                        onClicked: home.resumeVideoRequested(home.recentVideo.id)
                    }
                }
            }

            RowLayout {
                visible: !home.recentVideo
                AppButton { text: "Open Library"; iconName: "library"; onClicked: home.openLibraryRequested() }
                AppButton { text: "Open a video"; iconName: "play"; variant: "outline"; onClicked: home.openVideoRequested() }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
