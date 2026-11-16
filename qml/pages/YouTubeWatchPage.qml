import QtQuick
import QtQuick.Layouts
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
        width: Math.min(parent.width - 2 * anchors.margins, 920)
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

        Loader {
            id: embed
            objectName: "youtubePlayerLoader"
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(200, content.width * 9 / 16)
            active: root.embeddingAvailable && content.width >= 200
            visible: active && status !== Loader.Error
            source: "YouTubeEmbed.qml"

            onLoaded: item.video = Qt.binding(() => root.video)
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
