import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sori_qt_playback
import "../style"
import "../components"

Item {
    id: root

    property int request: 0
    property var videos: []
    property string currentQuery: ""
    property string nextPage: ""
    property string error: ""
    property bool loadingMore: false
    property string linkError: ""

    readonly property var topics: [
        { label: "History", query: "한국 역사 다큐 한국어 자막" },
        { label: "Science & nature", query: "과학 자연 다큐 한국어 자막" },
        { label: "Food & cooking", query: "한국 전통 음식 요리 한국어 자막" },
        { label: "Comedy", query: "한국 코미디 스케치 한국어 자막" },
        { label: "Interviews", query: "한국 직업 인터뷰 한국어 자막" },
        { label: "Arts & crafts", query: "한국 공예 작업실 한국어 자막" },
        { label: "Music", query: "한국 음악 공연 인터뷰 한국어 자막" },
        { label: "Daily life", query: "한국 시골 일상 브이로그 한국어 자막" }
    ]

    function showLinkForm() {
        linkError = ""
        pasteDialog.open()
        videoLink.forceActiveFocus()
    }

    function openLink(raw) {
        const url = YouTube.resolveLink(raw)
        if (!url)
            return "Enter a YouTube video link."
        return Qt.openUrlExternally(url) ? "" : "Could not open your browser."
    }

    function browse(query, pageToken) {
        const term = query.trim()
        if (!term || !YouTube.configured || (request && term === currentQuery))
            return
        error = ""
        currentQuery = term
        loadingMore = !!pageToken
        if (!loadingMore) {
            search.text = term
            videos = []
            nextPage = ""
        }
        request = YouTube.search(term, pageToken || "")
    }

    Connections {
        target: YouTube

        function onSearchFinished(request, result) {
            if (request !== root.request)
                return
            root.request = 0
            root.error = result.error ?? ""
            if (!root.error) {
                const loaded = new Set(root.videos.map(video => video.id))
                root.videos = root.videos.concat(result.videos.filter(video => !loaded.has(video.id)))
                root.nextPage = result.nextPage
            }
        }
    }

    Dialog {
        id: pasteDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(490, parent.width - 48)
        modal: true
        title: "Open a YouTube video"

        function submit() {
            root.linkError = root.openLink(videoLink.text)
            if (!root.linkError) {
                videoLink.clear()
                close()
            }
        }

        contentItem: ColumnLayout {
            spacing: 12

            AppInput {
                id: videoLink
                Layout.fillWidth: true
                placeholderText: "Paste a YouTube link"
                Accessible.name: "YouTube address"
                onAccepted: pasteDialog.submit()
            }

            AppText {
                text: root.linkError
                visible: text !== ""
                color: Theme.destructive
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                AppButton { text: "Cancel"; variant: "ghost"; onClicked: pasteDialog.close() }
                AppButton { text: "Open in browser"; enabled: !!videoLink.text.trim(); onClicked: pasteDialog.submit() }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 14

        RowLayout {
            Layout.fillWidth: true

            AppInput {
                id: search
                enabled: YouTube.configured
                Layout.fillWidth: true
                Layout.maximumWidth: 520
                placeholderText: "Search YouTube for Korean videos"
                iconName: "search"
                onAccepted: root.browse(text)
            }

            AppButton {
                text: "Search"
                enabled: YouTube.configured && !!search.text.trim() && !root.request
                onClicked: root.browse(search.text)
            }

            Item { Layout.fillWidth: true }
            AppButton { text: "Paste video link"; iconName: "play"; variant: "outline"; onClicked: root.showLinkForm() }
        }

        Flow {
            visible: YouTube.configured
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: root.topics

                delegate: AppButton {
                    required property var modelData
                    text: modelData.label
                    variant: root.currentQuery === modelData.query ? "secondary" : "outline"
                    small: true
                    onClicked: root.browse(modelData.query)
                }
            }
        }

        AppText {
            visible: text !== ""
            text: root.error || (!YouTube.configured
                ? "Set SORI_YOUTUBE_API_KEY to enable search. You can open a video link without a key."
                : root.request && !root.loadingMore ? "Searching YouTube…"
                : root.currentQuery && !root.videos.length ? "No videos found." : "")
            Layout.fillWidth: true
            color: root.error ? Theme.destructive : Theme.mutedForeground
            wrapMode: Text.Wrap
        }

        GridView {
            id: results
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.videos
            cellWidth: width / Math.max(1, Math.floor(width / 234))
            cellHeight: (cellWidth - 12) * 9 / 16 + 78
            ScrollBar.vertical: ScrollBar {}

            delegate: ItemDelegate {
                id: tile
                required property var modelData
                width: results.cellWidth - 12
                height: results.cellHeight - 12
                padding: 6
                Accessible.name: modelData.title + ", open in browser"

                background: Rectangle {
                    color: tile.hovered || tile.activeFocus ? Theme.hero : Theme.card
                    border.color: Theme.border
                    radius: Theme.radiusSmall
                }

                contentItem: ColumnLayout {
                    spacing: 6

                    Image {
                        Layout.fillWidth: true
                        Layout.preferredHeight: width * 9 / 16
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        source: "https://i.ytimg.com/vi/" + tile.modelData.id + "/mqdefault.jpg"
                    }

                    AppText {
                        Layout.fillWidth: true
                        text: tile.modelData.title
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    AppText {
                        Layout.fillWidth: true
                        text: tile.modelData.channel
                        color: Theme.mutedForeground
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                onClicked: root.error = root.openLink("https://www.youtube.com/watch?v=" + modelData.id)
            }
        }

        AppButton {
            Layout.alignment: Qt.AlignHCenter
            visible: !!root.nextPage
            text: root.request ? "Loading…" : "Load more"
            variant: "outline"
            enabled: !root.request
            onClicked: root.browse(root.currentQuery, root.nextPage)
        }
    }
}
