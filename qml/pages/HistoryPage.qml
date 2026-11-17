import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import sori_qt_playback
import "../style"
import "../components"

Item {
    id: root

    property string error: ""
    readonly property var entries: {
        const all = Library.recentVideos.concat(Library.youtubeHistory)
        return all.sort((a, b) => (b.watchedAt ?? 0) - (a.watchedAt ?? 0))
    }

    signal openExploreRequested()
    signal openWatchRequested(var entry)

    function requestDetails() {
        for (const entry of entries) {
            if (entry.youtubeId) {
                Library.ensureYoutubeMetadata(entry.youtubeId)
                Library.ensureYoutubeDuration(entry.youtubeId)
            } else if (entry.id) {
                Library.ensureVideoThumbnail(entry.id)
            }
        }
    }

    Component.onCompleted: requestDetails()
    onEntriesChanged: requestDetails()

    Item {
        id: content
        width: Math.min(Theme.historyWidth, root.width - 2 * Theme.pageInset)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 24
            anchors.bottomMargin: 24
            spacing: 12

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
                spacing: 16
                model: root.entries
                ScrollBar.vertical: AppScrollBar {
                    parent: root
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                }

                delegate: ItemDelegate {
                    id: row
                    required property var modelData
                    readonly property string title: modelData.displayTitle || modelData.title || "Untitled"
                    readonly property string channel: modelData.channel ?? ""
                    readonly property real duration: modelData.duration ?? 0
                    readonly property real seconds: modelData.seconds ?? 0
                    readonly property real progress: duration > 0 && seconds > 0
                        ? Math.min(1, seconds / duration) : 0
                    readonly property real thumbnailWidth: Math.min(268, width * 0.4)
                    readonly property real thumbnailHeight: Math.round(thumbnailWidth * 9 / 16)

                    width: ListView.view.width
                    height: thumbnailHeight
                    padding: 0
                    hoverEnabled: true
                    Accessible.name: channel === "" ? title : title + ", " + channel

                    onClicked: root.openWatchRequested(modelData)

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }

                    background: Rectangle {
                        color: "transparent"
                        radius: Theme.radiusSmall
                        border.width: row.visualFocus ? 2 : 0
                        border.color: Theme.accent
                    }

                    contentItem: RowLayout {
                        spacing: 16

                        Item {
                            id: thumbnail
                            Layout.preferredWidth: row.thumbnailWidth
                            Layout.preferredHeight: row.thumbnailHeight
                            Layout.alignment: Qt.AlignTop
                            clip: true

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.chip
                            }

                            Image {
                                id: artwork
                                anchors.fill: parent
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                                visible: status === Image.Ready
                                source: row.modelData.thumbnailUrl ?? ""
                            }

                            Icon {
                                anchors.centerIn: parent
                                visible: !artwork.visible
                                name: "film"
                                size: 28
                                color: Theme.mutedForeground
                            }

                            Rectangle {
                                visible: row.duration > 0
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 8
                                width: durationLabel.implicitWidth + 8
                                height: 18
                                radius: 4
                                color: Qt.alpha("#000000", 0.8)

                                AppText {
                                    id: durationLabel
                                    anchors.centerIn: parent
                                    text: Player.formatTime(row.duration)
                                    color: "#ffffff"
                                    font.pixelSize: 12
                                }
                            }

                            Rectangle {
                                visible: row.duration > 0
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 4
                                color: Qt.alpha("#000000", 0.4)

                                Rectangle {
                                    visible: row.progress > 0
                                    width: parent.width * row.progress
                                    height: parent.height
                                    color: Theme.dashboardProgress
                                }
                            }

                            Repeater {
                                model: 4
                                delegate: Shape {
                                    id: corner
                                    required property int index
                                    width: Theme.radiusSmall
                                    height: width
                                    x: index === 1 || index === 2 ? parent.width - width : 0
                                    y: index >= 2 ? parent.height - height : 0
                                    rotation: index * 90
                                    preferredRendererType: Shape.CurveRenderer
                                    ShapePath {
                                        strokeWidth: 0
                                        fillColor: Theme.background
                                        PathSvg { path: "M 0 0 H %1 A %1 %1 0 0 0 0 %1 Z".arg(corner.width) }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 2
                            spacing: 0

                            AppText {
                                id: titleText
                                Layout.fillWidth: true
                                text: row.title
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                font.underline: row.hovered || row.visualFocus
                                lineHeightMode: Text.FixedHeight
                                lineHeight: 22
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight

                                ToolTip {
                                    delay: 1500
                                    visible: (row.hovered || row.visualFocus) && titleText.truncated
                                    x: titleText.mapToItem(parent, 0, 0).x
                                    y: -implicitHeight - 4
                                    padding: 10
                                    width: Math.min(row.width - row.thumbnailWidth - 16,
                                        titleTip.implicitWidth + leftPadding + rightPadding)

                                    background: Rectangle {
                                        color: Qt.alpha(Theme.card, 0.75)
                                        radius: Theme.radiusSmall
                                        border.width: 1
                                        border.color: Theme.border
                                    }

                                    contentItem: AppText {
                                        id: titleTip
                                        text: titleText.text
                                        font.pixelSize: 13
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }

                            AppText {
                                visible: text !== ""
                                Layout.fillWidth: true
                                Layout.topMargin: 6
                                text: row.channel
                                color: Theme.mutedForeground
                                font.pixelSize: 14
                                elide: Text.ElideRight
                            }

                            AppText {
                                visible: row.duration <= 0
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                text: row.seconds > 0
                                    ? Player.formatTime(row.seconds) + " watched" : "Watched"
                                color: Theme.mutedForeground
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                visible: history.count === 0 && root.error === ""
                implicitHeight: emptyHistory.implicitHeight + 48
                radius: Theme.radius
                color: Theme.card
                border.color: Theme.border

                ColumnLayout {
                    id: emptyHistory
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 24
                    spacing: 4

                    AppText {
                        text: "No watch history yet"
                        font.weight: Font.DemiBold
                    }
                    AppText {
                        Layout.fillWidth: true
                        text: "Videos you play in Sori will appear here."
                        color: Theme.mutedForeground
                        wrapMode: Text.Wrap
                    }
                    AppButton {
                        text: "Explore videos"
                        variant: "outline"
                        Layout.topMargin: 12
                        onClicked: root.openExploreRequested()
                    }
                }
            }
        }
    }
}
