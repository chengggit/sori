import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import sori_qt_playback
import "../style"
import "../components"

ExplorePage {
    id: home

    signal openLibraryRequested()
    signal openVideoRequested()
    signal resumeVideoRequested(var entry)
    property string resumeError: ""
    readonly property var recentVideo: {
        const local = Library.recentVideos[0] ?? null
        const youtube = Library.youtubeHistory.find(entry => entry.seconds > 0)
        return youtube && (!local || youtube.watchedAt > (local.watchedAt ?? 0)) ? youtube : local
    }
    readonly property real resumeSeconds: recentVideo?.seconds ?? 0
    readonly property real resumeDuration: recentVideo?.duration ?? 0
    readonly property real resumeProgress: resumeDuration > 0
        ? Math.min(1, Math.max(0, resumeSeconds / resumeDuration)) : 0

    function requestThumbnail() {
        if (recentVideo?.id)
            Library.ensureVideoThumbnail(recentVideo.id)
    }

    Component.onCompleted: requestThumbnail()
    onRecentVideoChanged: requestThumbnail()

    discovery: true
    leadingContent: Rectangle {
        implicitHeight: home.recentVideo ? 248 : 150
        radius: Theme.radiusLarge
        color: Theme.hero
        border.color: Theme.chip

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.dashboardPadding
            spacing: Theme.iconSize

            AppText {
                text: "CONTINUE WATCHING"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
            }

            Rectangle {
                visible: !!home.recentVideo
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.resumeThumbnailWidth * 9 / 16
                radius: Theme.radius
                color: Theme.resumeCard

                RowLayout {
                    anchors.fill: parent
                    anchors.rightMargin: Theme.dashboardColumnGap
                    spacing: Theme.dashboardColumnGap

                    Item {
                        Layout.preferredWidth: Math.min(Theme.resumeThumbnailWidth, parent.width * 0.28)
                        Layout.fillHeight: true

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radius
                            color: Theme.chip
                        }

                        Image {
                            id: thumbnail
                            anchors.fill: parent
                            asynchronous: true
                            cache: false
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                            source: home.recentVideo?.thumbnailUrl ?? ""
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: thumbnail.status !== Image.Ready
                            name: "film"
                            size: 32
                            color: Theme.dashboardAccent
                        }

                        Repeater {
                            model: 4
                            delegate: Shape {
                                id: corner
                                required property int index
                                width: Theme.radius
                                height: width
                                x: index === 1 || index === 2 ? parent.width - width : 0
                                y: index >= 2 ? parent.height - height : 0
                                rotation: index * 90
                                preferredRendererType: Shape.CurveRenderer
                                ShapePath {
                                    strokeWidth: 0
                                    fillColor: corner.index === 0 || corner.index === 3
                                        ? Theme.hero : Theme.resumeCard
                                    PathSvg { path: "M 0 0 H %1 A %1 %1 0 0 0 0 %1 Z".arg(corner.width) }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 6

                        AppText {
                            Layout.fillWidth: true
                            text: home.recentVideo?.displayTitle || home.recentVideo?.title || ""
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        AppText {
                            Layout.fillWidth: true
                            text: home.recentVideo?.youtubeId ? (home.recentVideo.channel || "YouTube") : "Local video"
                            font.pixelSize: 13
                            color: Theme.mutedForeground
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Rectangle {
                            visible: home.resumeDuration > 0
                            Layout.fillWidth: true
                            Layout.topMargin: Theme.controlGap
                            Layout.maximumWidth: Theme.resumeProgressWidth
                            Layout.preferredHeight: Theme.progressHeight
                            radius: height / 2
                            color: Theme.chip

                            Rectangle {
                                width: parent.width * home.resumeProgress
                                height: parent.height
                                radius: parent.radius
                                color: Theme.dashboardProgress
                            }
                        }

                        AppText {
                            Layout.fillWidth: true
                            text: home.resumeError || (home.resumeDuration > 0
                                ? Player.formatTime(home.resumeSeconds) + " / " + Player.formatTime(home.resumeDuration)
                                : home.resumeSeconds > 0
                                    ? Player.formatTime(home.resumeSeconds) + " watched"
                                    : "Recently watched")
                            color: home.resumeError ? Theme.destructive : Theme.mutedForeground
                            elide: Text.ElideRight
                        }
                    }

                    AppButton {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 116
                        compact: true
                        text: home.recentVideo?.seconds > 0 ? "Resume" : "Watch again"
                        iconName: "play"
                        variant: "primary"
                        onClicked: home.resumeVideoRequested(home.recentVideo)
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
