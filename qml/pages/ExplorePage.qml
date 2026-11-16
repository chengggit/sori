import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import sori_qt_playback
import "../style"
import "../components"

Item {
    id: root

    property bool discovery: false
    property Component leadingContent
    property int discoveryIndex: 0
    readonly property var discoveryQueries: ["한국 집밥 요리 브이로그", "한국 일상 브이로그", "한국 여행 브이로그"]
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

    function refreshDiscovery() {
        browse(discoveryQueries[discoveryIndex])
        discoveryIndex = (discoveryIndex + 1) % discoveryQueries.length
    }

    Component.onCompleted: if (discovery && YouTube.configured) refreshDiscovery()

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
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: root.discovery ? 28 : 32
        anchors.bottomMargin: root.discovery ? 0 : 32
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.discovery ? Math.min(1528, parent.width - 64) : parent.width - 64
        spacing: root.discovery ? 20 : 14

        Loader {
            visible: status === Loader.Ready
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            sourceComponent: root.leadingContent
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.discovery
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5
                AppText { text: "DISCOVER"; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.mutedForeground; font.letterSpacing: 1 }
                AppText { text: "Korean videos on YouTube"; font.pixelSize: 24; font.weight: Font.DemiBold }
            }
            AppButton { text: "Paste YouTube link"; variant: "outline"; small: true; onClicked: root.showLinkForm() }
            AppButton { text: "Refresh Discover"; variant: "outline"; small: true; enabled: YouTube.configured && !root.request; onClicked: root.refreshDiscovery() }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !root.discovery

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
            visible: YouTube.configured && !root.discovery
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
            readonly property int columns: Math.max(1, Math.floor(width / (root.discovery ? 330 : 290)))
            cellWidth: Math.floor(width / columns)
            cellHeight: (cellWidth - 20 + 20 / columns) * 9 / 16 + 92
            ScrollBar.vertical: ScrollBar {}

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                width: results.cellWidth
                height: results.cellHeight

                ItemDelegate {
                    id: tile
                    readonly property var modelData: cell.modelData
                    x: (cell.index % results.columns) * 20 / results.columns
                    width: results.cellWidth - 20 + 20 / results.columns
                    height: results.cellHeight - 16
                    padding: 0
                    Accessible.name: modelData.title + ", open in browser"

                    background: Rectangle {
                        color: tile.activeFocus ? Theme.hero : "transparent"
                        border.width: 0
                        radius: Theme.radiusSmall
                    }

                    contentItem: ColumnLayout {
                        spacing: 6

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: width * 9 / 16
                            Image {
                                anchors.fill: parent
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                                source: "https://i.ytimg.com/vi/" + tile.modelData.id + "/mqdefault.jpg"
                            }
                            Repeater {
                                model: 4
                                delegate: Shape {
                                    required property int index
                                    width: 14
                                    height: 14
                                    x: index === 1 || index === 2 ? parent.width - width : 0
                                    y: index >= 2 ? parent.height - height : 0
                                    rotation: index * 90
                                    preferredRendererType: Shape.CurveRenderer
                                    ShapePath {
                                        strokeWidth: 0
                                        fillColor: tile.activeFocus ? Theme.hero : Theme.background
                                        PathSvg { path: "M 0 0 H 14 A 14 14 0 0 0 0 14 Z" }
                                    }
                                }
                            }
                        }

                        AppText {
                            Layout.fillWidth: true
                            text: tile.modelData.title
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
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
            footer: Item {
                width: results.width
                height: root.nextPage ? loadMore.implicitHeight : 0

                AppButton {
                    id: loadMore
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !!root.nextPage
                    text: root.request ? "Loading…" : "Load more"
                    variant: "outline"
                    enabled: !root.request
                    onClicked: root.browse(root.currentQuery, root.nextPage)
                }
            }
        }
    }
}
