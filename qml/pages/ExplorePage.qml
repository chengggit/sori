import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import sori_core
import "../style"
import "../components"

Item {
    id: root

    signal openYouTubeRequested(string url, string title, string channel)
    required property var searchCache
    readonly property int cacheLifetime: 24 * 60 * 60 * 1000
    readonly property int subscriptionCacheLifetime: 15 * 60 * 1000
    readonly property int paginationDistance: 500
    property bool discovery: false
    property Component leadingContent
    property string feedKey: ""
    property int request: 0
    property var videos: []
    property string currentQuery: ""
    property string nextPage: ""
    property var nextPageTokens: ({})
    property string error: ""
    property bool loadingMore: false
    property bool paginationFailed: false
    property string linkError: ""
    readonly property int subscriptionCount: (YouTube.subscriptions ?? []).length
    readonly property string statusText: error || (!YouTube.configured
        ? "Add a YouTube API key in Settings to discover videos."
        : discovery && subscriptionCount === 0
            ? "Add a YouTube channel in Settings to build your feed."
            : request ? "Loading videos…"
            : currentQuery && !videos.length ? "No videos found." : "")

    readonly property var topics: [
        {
            label: "History",
            query: "한국 역사 다큐 한국어 자막"
        },
        {
            label: "Science & nature",
            query: "과학 자연 다큐 한국어 자막"
        },
        {
            label: "Food & cooking",
            query: "한국 전통 음식 요리 한국어 자막"
        },
        {
            label: "Comedy",
            query: "한국 코미디 스케치 한국어 자막"
        },
        {
            label: "Interviews",
            query: "한국 직업 인터뷰 한국어 자막"
        },
        {
            label: "Arts & crafts",
            query: "한국 공예 작업실 한국어 자막"
        },
        {
            label: "Music",
            query: "한국 음악 공연 인터뷰 한국어 자막"
        },
        {
            label: "Daily life",
            query: "한국 시골 일상 브이로그 한국어 자막"
        }
    ]

    // Append pages without resetting GridView's delegates and scroll position.
    ListModel {
        id: videoModel
        dynamicRoles: true
    }

    // Newest upload sits first; everything below is shuffled so Refresh gives
    // a different mix from the same set of subscribed channels.
    function showFeed(feedVideos, reposition) {
        const unique = [];
        const seen = new Set();
        for (const video of feedVideos) {
            if (!seen.has(video.id)) {
                seen.add(video.id);
                unique.push(video);
            }
        }
        videos = unique;
        videoModel.clear();
        if (videos.length) {
            videoModel.append({ video: videos[0] });
            const rest = videos.slice(1);
            for (let i = rest.length - 1; i > 0; i--) {
                const j = Math.floor(Math.random() * (i + 1));
                const temporary = rest[i];
                rest[i] = rest[j];
                rest[j] = temporary;
            }
            for (const video of rest)
                videoModel.append({ video: video });
        }
        if (reposition !== false)
            Qt.callLater(positionAtTop);
    }

    function subscriptionCacheKey() {
        const ids = (YouTube.subscriptions ?? []).map(entry => entry.channelId).join(",");
        return "subscriptions:" + ids;
    }

    function refreshDiscovery(force) {
        if (!YouTube.configured || root.subscriptionCount === 0) {
            videos = [];
            videoModel.clear();
            nextPage = "";
            nextPageTokens = ({});
            currentQuery = "";
            return;
        }
        const key = root.subscriptionCacheKey();
        if (!force) {
            const cached = root.freshCacheEntries().find(entry => entry.query === key);
            if (cached) {
                root.showFeed(cached.videos ?? [], false);
                root.nextPageTokens = cached.nextPageTokens ?? ({});
                return;
            }
        }
        // Keep the current feed on screen while refreshing so the view does
        // not collapse to zero height and jump back to the header.
        error = "";
        nextPage = "";
        nextPageTokens = ({});
        currentQuery = key;
        request = YouTube.subscriptionFeed();
    }

    function ensureDiscovery() {
        if (discovery && visible && YouTube.configured && !request && !videos.length)
            refreshDiscovery(false);
    }
    Component.onCompleted: Qt.callLater(ensureDiscovery)
    onVisibleChanged: Qt.callLater(ensureDiscovery)

    function showLinkForm() {
        linkError = "";
        pasteDialog.open();
        videoLink.forceActiveFocus();
    }

    function freshCacheEntries() {
        try {
            return JSON.parse(searchCache.firstPages).filter(entry => entry.expiresAt > Date.now() && Array.isArray(entry.videos));
        } catch (error) {
            return [];
        }
    }

    function loadMoreNearEnd() {
        if (!visible || request || !results.footerItem)
            return;
        if (results.footerItem.y - (results.contentY + results.height) > paginationDistance) {
            paginationFailed = false;
            return;
        }
        if (discovery) {
            if (Object.keys(root.nextPageTokens).length === 0)
                return;
            root.loadingMore = true;
            request = YouTube.subscriptionFeedPage(root.nextPageTokens);
            return;
        }
        if (!nextPage || paginationFailed)
            return;
        browse(currentQuery, nextPage);
    }

    function showFirstPage(firstPage) {
        videos = firstPage.videos;
        videoModel.clear();
        for (const video of videos)
            videoModel.append({
                video: video
            });
        nextPage = firstPage.nextPage;
        // Wait for Continue Watching and the grid to lay out the first page together.
        Qt.callLater(positionAtTop);
    }

    function positionAtTop() {
        wheelScroll.stop();
        results.forceLayout();
        results.positionViewAtBeginning();
    }

    function browse(query, pageToken) {
        const term = query.trim();
        if (!term || !YouTube.configured || (request && term === currentQuery))
            return;
        error = "";
        currentQuery = term;
        feedKey = "query:" + term;
        loadingMore = !!pageToken;
        if (!loadingMore) {
            wheelScroll.stop();
            paginationFailed = false;
            search.text = term;
            videos = [];
            videoModel.clear();
            nextPage = "";
            const cached = freshCacheEntries().find(entry => entry.query === feedKey);
            if (cached) {
                showFirstPage(cached);
                return;
            }
        }
        request = YouTube.search(term, pageToken || "");
    }

    Connections {
        target: YouTube

        function onConfigurationChanged() { Qt.callLater(root.ensureDiscovery) }

        function onSearchFinished(request, result) {
            if (request !== root.request)
                return;
            const wasLoadingMore = root.loadingMore;
            root.error = result.error ?? "";
            root.paginationFailed = wasLoadingMore && !!root.error;
            if (!root.error) {
                if (wasLoadingMore) {
                    const loaded = new Set(root.videos.map(video => video.id));
                    const added = result.videos.filter(video => !loaded.has(video.id));
                    root.videos = root.videos.concat(added);
                    for (const video of added)
                        videoModel.append({
                            video: video
                        });
                    root.nextPage = result.nextPage === root.nextPage ? "" : result.nextPage;
                } else {
                    root.showFirstPage(result);
                    const entries = root.freshCacheEntries().filter(entry => entry.query !== root.feedKey);
                    entries.unshift({
                        query: root.feedKey,
                        expiresAt: Date.now() + root.cacheLifetime,
                        videos: result.videos,
                        nextPage: root.nextPage
                    });
                    root.searchCache.firstPages = JSON.stringify(entries.slice(0, 30));
                }
            }
            root.loadingMore = false;
            root.request = 0;
        }

        function onSubscriptionFeedFinished(request, result) {
            if (request !== root.request)
                return;
            const wasLoadingMore = root.loadingMore;
            root.error = result.error ?? "";
            root.request = 0;
            root.loadingMore = false;
            if (root.error)
                return;
            const loaded = wasLoadingMore ? root.videos : [];
            root.showFeed(loaded.concat(result.videos ?? []), false);
            root.nextPageTokens = result.nextPageTokens ?? ({});
            if (!wasLoadingMore) {
                const entries = root.freshCacheEntries()
                    .filter(entry => entry.query !== root.currentQuery);
                entries.unshift({
                    query: root.currentQuery,
                    expiresAt: Date.now() + root.subscriptionCacheLifetime,
                    videos: result.videos ?? [],
                    nextPageTokens: root.nextPageTokens
                });
                root.searchCache.firstPages = JSON.stringify(entries.slice(0, 30));
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
        padding: 20
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        function submit() {
            const url = YouTube.resolveLink(videoLink.text);
            if (!url) {
                root.linkError = "Enter a YouTube video link.";
                return;
            }
            videoLink.clear();
            root.linkError = "";
            close();
            root.openYouTubeRequested(url, "", "");
        }

        background: Rectangle {
            color: Theme.card
            radius: Theme.radiusLarge
            border.width: 0
        }

        Overlay.modal: Rectangle {
            color: Qt.rgba(0, 0, 0, Theme.dark ? 0.55 : 0.2)
        }

        header: Item {
            implicitWidth: 0
            implicitHeight: 0
        }

        contentItem: ColumnLayout {
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    AppText {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: pasteDialog.title
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }

                    AppButton {
                        iconName: "x"
                        variant: "ghost"
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        Layout.alignment: Qt.AlignTop
                        Accessible.name: "Close"
                        onClicked: pasteDialog.close()
                    }
                }

                AppText {
                    Layout.fillWidth: true
                    text: "Paste a video link to watch it in Sori."
                    color: Theme.mutedForeground
                    wrapMode: Text.Wrap
                }
            }

            AppInput {
                id: videoLink
                Layout.fillWidth: true
                placeholderText: "Paste a YouTube video link"
                Accessible.name: "YouTube video link"
                onAccepted: pasteDialog.submit()
            }

            AppText {
                text: root.linkError
                visible: text !== ""
                color: Theme.destructive
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }

            AppButton {
                text: "Open video"
                iconName: "play"
                variant: "primary"
                Layout.alignment: Qt.AlignLeft
                Layout.topMargin: 2
                onClicked: pasteDialog.submit()
            }
        }
    }

    PageFrame {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        topPadding: root.discovery ? 0 : Theme.pagePadding
        bottomPadding: root.discovery ? 0 : Theme.pagePadding
        spacing: root.discovery ? 0 : 14

        RowLayout {
            Layout.fillWidth: true
            visible: !root.discovery

            AppInput {
                id: search
                enabled: YouTube.configured
                Layout.fillWidth: true
                Layout.maximumWidth: 520
                placeholderText: "Search YouTube"
                iconName: "search"
                onAccepted: root.browse(text)
            }

            AppButton {
                text: "Search"
                enabled: YouTube.configured && !!search.text.trim() && !root.request
                onClicked: root.browse(search.text)
            }

            Item {
                Layout.fillWidth: true
            }
            AppButton {
                text: "Paste video link"
                iconName: "play"
                variant: "outline"
                onClicked: root.showLinkForm()
            }
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

        GridView {
            id: results
            objectName: "discoveryResults"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: videoModel
            onContentYChanged: {
                if (moving || resultsScrollBar.pressed || wheelScroll.running)
                    root.loadMoreNearEnd();
            }
            onDraggingChanged: if (dragging) wheelScroll.stop()

            NumberAnimation {
                id: wheelScroll
                target: results
                property: "contentY"
                duration: 180
                easing.type: Easing.OutCubic
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                target: null
                blocking: true
                onWheel: event => {
                    if (event.angleDelta.y === 0 && event.pixelDelta.y === 0) {
                        event.accepted = false;
                        return;
                    }
                    event.accepted = true;
                    const precise = event.pixelDelta.y !== 0;
                    // A wheel notch is 120 angle units. Scroll by distance,
                    // rather than a flick velocity that Qt caps and decelerates.
                    const distance = precise ? event.pixelDelta.y * 2 : event.angleDelta.y / 120 * 300;
                    const previousTarget = wheelScroll.running ? wheelScroll.to : results.contentY;
                    wheelScroll.stop();
                    results.cancelFlick();
                    const minimum = results.originY;
                    const maximum = Math.max(minimum, minimum + results.contentHeight - results.height);
                    const destination = Math.max(minimum, Math.min(maximum,
                        (precise ? results.contentY : previousTarget) - distance));
                    if (precise) {
                        // Pixel-based input already supplies smooth motion and inertia.
                        results.contentY = destination;
                        root.loadMoreNearEnd();
                    } else {
                        wheelScroll.from = results.contentY;
                        wheelScroll.to = destination;
                        wheelScroll.restart();
                    }
                }
            }
            readonly property int columns: Math.min(4, Math.max(1, Math.floor(width / (root.discovery ? 330 : 290))))
            cellWidth: Math.floor(width / columns)
            readonly property real tileWidth: cellWidth - Theme.dashboardColumnGap + Theme.dashboardColumnGap / columns
            readonly property int titleHeight: 2 * Theme.videoTitleLineHeight
            cellHeight: Math.ceil(tileWidth * 9 / 16) + titleHeight + Theme.videoChannelHeight + Theme.controlGap + 4 + Theme.dashboardRowGap
            ScrollBar.vertical: AppScrollBar {
                id: resultsScrollBar
                onPressedChanged: if (pressed) wheelScroll.stop()
                parent: root.discovery ? root : results
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
            }

            header: ColumnLayout {
                width: results.width
                spacing: 0

                Item {
                    visible: root.discovery
                    Layout.preferredHeight: Theme.dashboardPadding
                }

                Loader {
                    visible: status === Loader.Ready
                    Layout.fillWidth: true
                    Layout.bottomMargin: Theme.dashboardSectionGap
                    sourceComponent: root.leadingContent
                }

                GridLayout {
                    Layout.fillWidth: true
                    visible: root.discovery
                    columns: 2
                    columnSpacing: Theme.controlGap
                    rowSpacing: Theme.controlGap

                    ColumnLayout {
                        id: discoverHeading
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 5
                        AppText {
                            text: "DISCOVER"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Theme.mutedForeground
                            font.letterSpacing: 1
                        }
                        AppText {
                            Layout.fillWidth: true
                            text: "Korean videos on YouTube"
                            font.pixelSize: 24
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }
                    RowLayout {
                        id: discoverActions
                        Layout.alignment: Qt.AlignRight | Qt.AlignBottom
                        spacing: Theme.controlGap
                        AppButton {
                            text: "Paste YouTube link"
                            iconName: "link"
                            variant: "outline"
                            compact: true
                            onClicked: root.showLinkForm()
                        }
                        AppButton {
                            text: "Refresh"
                            iconName: "refresh"
                            variant: "outline"
                            compact: true
                            enabled: YouTube.configured && !root.request
                            onClicked: root.refreshDiscovery(true)
                        }
                    }
                }

                AppText {
                    visible: text !== ""
                    text: root.statusText
                    Layout.fillWidth: true
                    color: root.error ? Theme.destructive : Theme.mutedForeground
                    wrapMode: Text.Wrap
                }

                Item {
                    visible: root.discovery || root.statusText !== ""
                    Layout.preferredHeight: Theme.dashboardColumnGap
                }
            }

            delegate: Item {
                id: cell
                required property var video
                readonly property var modelData: video
                required property int index
                width: results.cellWidth
                height: results.cellHeight

                ItemDelegate {
                    id: tile
                    readonly property var modelData: cell.modelData
                    x: (cell.index % results.columns) * Theme.dashboardColumnGap / results.columns
                    width: results.tileWidth
                    height: results.cellHeight - Theme.dashboardRowGap
                    padding: 0
                    hoverEnabled: true
                    Accessible.name: modelData.title

                    background: Rectangle {
                        color: tile.activeFocus ? Theme.hero : "transparent"
                        border.width: 0
                        radius: Theme.radiusSmall
                    }

                    contentItem: ColumnLayout {
                        spacing: 0

                        Item {
                            id: artwork
                            readonly property bool highlighted: tile.hovered || tile.visualFocus
                            readonly property int transitionDuration: 200

                            Layout.fillWidth: true
                            Layout.preferredHeight: width * 9 / 16
                            clip: true

                            Image {
                                anchors.fill: parent
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                                source: "https://i.ytimg.com/vi/" + tile.modelData.id + "/mqdefault.jpg"
                                scale: artwork.highlighted ? 1.02 : 1

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: artwork.transitionDuration
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: Qt.alpha(Theme.darkBackground, 0.28)
                                opacity: artwork.highlighted ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: artwork.transitionDuration
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: 40
                                height: width
                                radius: width / 2
                                color: Theme.card
                                scale: artwork.highlighted ? 1 : 0.9
                                opacity: artwork.highlighted ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: artwork.transitionDuration
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: artwork.transitionDuration
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Icon {
                                    anchors.centerIn: parent
                                    name: "play-filled"
                                    size: 18
                                    color: Theme.dashboardAccent
                                }
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
                                        fillColor: tile.activeFocus ? Theme.hero : Theme.background
                                        PathSvg {
                                            path: "M 0 0 H %1 A %1 %1 0 0 0 0 %1 Z".arg(corner.width)
                                        }
                                    }
                                }
                            }
                        }

                        AppText {
                            id: videoTitle
                            Layout.fillWidth: true
                            text: tile.modelData.title
                            Layout.topMargin: Theme.controlGap
                            Layout.preferredHeight: Math.min(results.titleHeight, videoTitle.implicitHeight)
                            verticalAlignment: Text.AlignTop
                            lineHeightMode: Text.FixedHeight
                            lineHeight: Theme.videoTitleLineHeight
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            wrapMode: Text.Wrap
                            maximumLineCount: 2

                            ToolTip {
                                delay: 1500
                                visible: (tile.hovered || tile.visualFocus) && videoTitle.truncated
                                x: videoTitle.mapToItem(parent, 0, 0).x
                                y: -implicitHeight - 4
                                padding: 10
                                width: Math.min(tile.width, titleTip.implicitWidth + leftPadding + rightPadding)

                                background: Rectangle {
                                    color: Qt.alpha(Theme.card, 0.75)
                                    radius: Theme.radiusSmall
                                    border.width: 1
                                    border.color: Theme.border
                                }

                                contentItem: AppText {
                                    id: titleTip
                                    text: videoTitle.text
                                    font.pixelSize: 13
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        AppText {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            text: tile.modelData.channel
                            color: Theme.mutedForeground
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        // Keep artwork and titles top-aligned; short titles
                        // leave their unused second-line space below the channel.
                        Item {
                            Layout.fillHeight: true
                        }
                    }

                    onClicked: root.openYouTubeRequested("https://www.youtube.com/watch?v=" + modelData.id, modelData.title, modelData.channel)
                }
            }
            footer: Item {
                width: results.width
                height: (loadingLabel.visible ? loadingLabel.implicitHeight : 0) + (root.discovery ? Theme.dashboardBottomPadding : 0)

                AppText {
                    id: loadingLabel
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.loadingMore
                    text: "Loading more videos…"
                    color: Theme.mutedForeground
                }
            }
        }
    }
}
