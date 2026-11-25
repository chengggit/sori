import QtQuick
import "../style/Reply.js" as Reply
import QtQuick.Shapes
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import sori_core
import "../components"
import "../style"

Item {
    id: root
    clip: true
    required property var video
    required property bool embeddingAvailable
    required property var renderHost
    property string saveError: ""
    readonly property string youtubeId: video?.youtubeId ?? ""
    property var savedTranscript: ({})
    property bool showText: false
    property int fetchRequest: 0
    property string transcriptVideoId: ""
    property string transcriptError: ""
    readonly property real viewingWidth: width - analysis.width * analysis.revealProgress
    readonly property real playerHeight: Math.max(0, Math.min(root.Window.window.height * 0.42,
        root.height - 218, Math.min(root.viewingWidth - 48, Theme.watchWidth) * 9 / 16))
    signal backRequested()
    signal checkpoint(var entry, real seconds, real duration)

    function fetchKoreanTranscript() {
        if (!youtubeId || fetchRequest) return
        transcriptError = ""
        fetchRequest = YouTube.fetchTranscript(youtubeId, "ko")
    }
    function loadTranscript() {
        if (youtubeId === transcriptVideoId) return
        transcriptVideoId = youtubeId
        fetchRequest = 0
        analysis.close()
        savedTranscript = youtubeId ? Reply.valueOrError(Library.readYoutubeTranscript(youtubeId)) : ({})
        transcriptError = savedTranscript.error || ""
        showText = !!savedTranscript.content
        playback.position = video?.seconds ?? 0
        youtubeSubtitles.refresh()
        if (youtubeId && (savedTranscript.language !== "ko" || !savedTranscript.cues?.length)) {
            savedTranscript = Object.assign({}, savedTranscript, {cues: []})
            fetchKoreanTranscript()
        }
    }
    onYoutubeIdChanged: Qt.callLater(loadTranscript)
    Component.onCompleted: Qt.callLater(loadTranscript)

    QtObject {
        id: playback
        property real position: 0
        function formatTime(seconds) { return Player.formatTime(seconds) }
        function seek(seconds) {
            if (embed.item) {
                embed.item.seek(seconds)
                position = seconds
                youtubeSubtitles.refresh()
            }
        }
    }
    QtObject {
        id: youtubeSubtitles
        property var transcript: root.savedTranscript.cues ?? []
        property int activeRow: -1
        property bool loading: root.fetchRequest !== 0
        function refresh() {
            let left = 0, right = transcript.length
            while (left < right) {
                const middle = Math.floor((left + right) / 2)
                if (transcript[middle].start <= playback.position) left = middle + 1
                else right = middle
            }
            activeRow = left - 1
        }
        onTranscriptChanged: Qt.callLater(refresh)
    }
    Connections {
        target: YouTube
        function onTranscriptFinished(request, result) {
            result = Reply.valueOrError(result)
            if (request !== root.fetchRequest) return
            root.fetchRequest = 0
            root.transcriptError = result.error || ""
            if (!result.error) {
                root.transcriptError = Library.cacheYoutubeTranscript(root.youtubeId, result).error
                root.savedTranscript = Object.assign({}, root.savedTranscript, result)
                youtubeSubtitles.refresh()
            }
        }
    }
    FileDialog {
        id: textPicker
        title: "Add text transcript"
        nameFilters: ["Text files (*.txt)"]
        onAccepted: {
            textReader.flush()
            const result = Reply.valueOrError(Library.attachYoutubeTranscript(root.youtubeId, root.renderHost.localPath(selectedFile)))
            root.transcriptError = result.error || ""
            if (!result.error) {
                root.savedTranscript = result
                root.showText = true
                textReader.restoring = true
                Qt.callLater(textReader.restore)
            }
        }
    }

    function removeTextTranscript() {
        textReader.flush()
        transcriptError = Library.removeYoutubeTextTranscript(youtubeId).error
        if (!transcriptError) {
            savedTranscript = Object.assign({}, savedTranscript, {content: null, title: null, position: 0})
            showText = false
        }
    }
    Component {
        id: transcriptHeader
        TranscriptHeader {
            hasText: !!root.savedTranscript.content
            showingText: root.showText
            filename: root.savedTranscript.title ?? ""
            canRetry: root.transcriptError !== "" && !root.fetchRequest
            onAddRequested: textPicker.open()
            onRemoveRequested: root.removeTextTranscript()
            onToggleRequested: root.showText = !root.showText
            onRetryRequested: root.fetchKoreanTranscript()
        }
    }

    ColumnLayout {
        id: content
        x: (root.viewingWidth - width) / 2
        y: 24
        width: root.playerHeight * 16 / 9
        height: Math.max(0, root.height - y - 16)
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            AppButton { text: "Back"; iconName: "arrow-left"; variant: "ghost"; onClicked: root.backRequested() }
            Item { Layout.fillWidth: true }
            AppButton { text: "Open in browser"; variant: "outline"; onClicked: Qt.openUrlExternally(root.video.youtubeUrl) }
        }
        Rectangle {
            id: playerFrame
            Layout.fillWidth: true
            Layout.preferredHeight: root.playerHeight
            Layout.minimumHeight: Layout.preferredHeight
            Layout.maximumHeight: Layout.preferredHeight
            radius: Theme.radius
            color: "black"
            clip: true
            Loader {
                id: embed
                objectName: "youtubePlayerLoader"
                anchors.fill: parent
                active: root.embeddingAvailable && width >= 200
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
            Connections {
                target: embed.item
                function onCheckpoint(entry, seconds, duration) {
                    playback.position = seconds
                    youtubeSubtitles.refresh()
                    root.checkpoint(entry, seconds, duration)
                }
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
                : embed.item?.playbackError ?? ""
            text: root.transcriptError || playerError || root.saveError
            visible: text !== ""
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Theme.mutedForeground
        }
        UntimedTranscript {
            id: textReader
            headerComponent: transcriptHeader
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.showText
            videoId: 0
            youtubeId: root.youtubeId
            renderHost: root.renderHost
            text: root.savedTranscript.content ?? ""
            savedPosition: root.savedTranscript.position ?? 0
            onLookupRequested: (text, start, end) => analysis.lookup(text, start, end)
            onSaveFailed: error => root.transcriptError = error
        }
        SubtitleTranscript {
            showEmptyAction: false
            headerComponent: transcriptHeader
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.showText
            emptyAction: "Add text transcript (TXT)"
            emptyHint: "Korean subtitles will load automatically when available. You can also attach a TXT transcript."
            subtitles: youtubeSubtitles
            player: playback
            onLookupRequested: (text, start, end) => analysis.lookup(text, start, end)
            onAddRequested: textPicker.open()
        }
    }
    ReaderAnalysis {
        id: analysis
        objectName: "youtubeWordAnalysis"
        documentId: 0
        youtubeId: root.youtubeId
        sourceTitle: root.video?.title ?? "YouTube video"
        animateEntrance: true
        anchors.right: parent.right
        anchors.rightMargin: -(1 - revealProgress) * width
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        visible: opened || revealProgress > 0
        onDismissRequested: close()
    }
    Shortcut {
        sequence: "Escape"
        enabled: analysis.opened
        onActivated: {
            if (analysis.editing) analysis.closeSaveEditor()
            else analysis.close()
        }
    }
}
