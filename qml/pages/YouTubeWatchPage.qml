import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../components"
import "../style"

Item {
    id: root

    required property var video
    required property bool embeddingAvailable
    property string saveError: ""

    signal backRequested()
    signal checkpoint(var entry, real seconds, real duration)

    ColumnLayout {
        id: content
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.margins: 24
        width: Math.min(parent.width - 2 * anchors.margins, Theme.watchWidth)
        spacing: 16

        RowLayout {
            Layout.fillWidth: true

            AppButton {
                text: "Back"
                iconName: "arrow-left"
                variant: "ghost"
                onClicked: root.backRequested()
            }

            Item { Layout.fillWidth: true }

            AppButton {
                text: "Open in browser"
                variant: "outline"
                onClicked: Qt.openUrlExternally(root.video.youtubeUrl)
            }
        }

        Rectangle {
            id: playerFrame
            readonly property real playerWidth: content.width

            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(200, playerWidth * 9 / 16)
            visible: embed.active && embed.status !== Loader.Error
            radius: Theme.radius
            color: "black"

            Loader {
                id: embed
                objectName: "youtubePlayerLoader"
                anchors.fill: parent
                active: root.embeddingAvailable && playerFrame.playerWidth >= 200
                source: "YouTubeEmbed.qml"

                onLoaded: item.video = Qt.binding(() => root.video)
            }

            Repeater {
                model: 4
                delegate: Shape {
                    id: corner
                    required property int index
                    width: playerFrame.radius
                    height: width
                    x: index === 1 || index === 2 ? playerFrame.width - width : 0
                    y: index >= 2 ? playerFrame.height - height : 0
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

        Connections {
            target: embed.item
            function onCheckpoint(entry, seconds, duration) {
                root.checkpoint(entry, seconds, duration)
            }
        }

        AppText {
            text: root.video.title
            font.pixelSize: 20
            font.weight: Font.DemiBold
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        AppText {
            readonly property string playerError: !root.embeddingAvailable || embed.status === Loader.Error
                ? "This build does not include Qt WebEngine. Open the video in your browser."
                : !embed.active ? "Enlarge the window to watch here." : (embed.item?.playbackError ?? "")
            text: playerError || root.saveError
            visible: !!text
            Layout.fillWidth: true
            color: Theme.mutedForeground
            wrapMode: Text.Wrap
        }
    }
}
