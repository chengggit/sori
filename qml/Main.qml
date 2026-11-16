import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Sori 1.0
import sori_qt_playback
import "components"
import "pages"
import "style"

ApplicationWindow {
    id: root

    required property var renderHost
    required property string dataDirectory
    required property string kiwiDirectory
    required property string startupPath
    readonly property var player: Player
    readonly property var subtitles: Subtitles
    readonly property bool fullScreen: visibility === Window.FullScreen
    readonly property bool watchShortcutsEnabled: page === "watch" && player.loaded
        && !watchPage.trackMenu.opened && !watchPage.analysisOpened && !settingsSheet.visible
    readonly property string pageTitle: page === "watch" ? "Watch"
        : page === "library" ? "My Library"
        : page === "reader" ? "Reader"
        : page === "explore" ? "Explore"
        : page === "vocabulary" ? "Vocabulary"
        : page === "history" ? "History" : "Home"

    property string page: "home"
    property bool sidebarExpanded: true
    property bool controlsAwake: true
    property bool captionsVisible: true
    property int previousVisibility: Window.Windowed
    property var pageStack: []
    property var currentVideo: null
    property bool videoReady: false
    property bool awaitingVideoPosition: false
    property string videoError: ""

    width: 1280
    height: 840
    minimumWidth: 860
    minimumHeight: 600
    visible: true
    title: pageTitle === "Home" ? "Sori" : pageTitle + " · Sori"
    color: fullScreen ? "#000000" : Theme.background
    font.family: "Inter"
    palette.window: Theme.background
    palette.base: Theme.card
    palette.alternateBase: Theme.sidebar
    palette.text: Theme.foreground
    palette.windowText: Theme.foreground
    palette.button: Theme.card
    palette.buttonText: Theme.foreground
    palette.highlight: Theme.accent
    palette.highlightedText: Theme.onAccent
    palette.mid: Theme.border

    function navigate(nextPage, pushHistory) {
        if (nextPage === page)
            return
        if (pushHistory !== false)
            pageStack = pageStack.concat([page])
        changePage(nextPage)
    }

    function goBack(fallback) {
        if (pageStack.length > 0) {
            const previous = pageStack[pageStack.length - 1]
            pageStack = pageStack.slice(0, -1)
            changePage(previous)
        } else {
            navigate(fallback || "home", false)
        }
    }

    function changePage(nextPage) {
        if (page === "reader" && nextPage !== "reader")
            readerPage.leave()
        if (page === "watch" && nextPage !== "watch" && videoReady) {
            saveVideoProgress()
            player.pause()
            watchPage.closeAnalysis()
        }
        page = nextPage
    }

    function wakeControls() {
        controlsAwake = true
        hideControls.restart()
    }

    function openLocalVideo(url) {
        const path = renderHost.localPath(url)
        if (path)
            openVideoPath(path)
    }

    function openVideoPath(path) {
        if (player.loading)
            return
        const imported = Library.importVideo(path)
        if (imported.id) {
            openSavedVideo(imported.id)
            return
        }
        if (page === "watch")
            saveVideoProgress()
        beginVideo({ path: path })
    }

    function openSavedVideo(id) {
        if (player.loading)
            return "Wait for the current video to finish opening."
        if (page === "watch")
            saveVideoProgress()
        const video = Library.readVideo(id)
        if (video.error)
            return video.error
        video.id = id
        beginVideo(video)
        return ""
    }

    function beginVideo(video) {
        currentVideo = video
        videoReady = false
        awaitingVideoPosition = (video.seconds ?? 0) > 0
        videoError = ""
        navigate("watch")
        player.open(video.path)
        wakeControls()
    }

    function saveVideoProgress() {
        videoProgressTimer.stop()
        if (videoReady && !awaitingVideoPosition && currentVideo?.id)
            videoError = Library.saveVideoProgress(currentVideo.id, player.ended ? 0 : player.position, player.duration)
    }

    function attachSubtitles(url) {
        const path = renderHost.localPath(url)
        if (!videoReady || !currentVideo?.id) {
            subtitles.attach(path)
            return
        }
        const result = Library.saveVideoSubtitles(currentVideo.id, path)
        videoError = result.error || ""
        if (result.text)
            subtitles.attachSaved(result.text)
    }

    function toggleFullscreen() {
        watchPage.trackMenu.close()
        if (fullScreen) {
            visibility = previousVisibility
        } else {
            previousVisibility = visibility
            root.showFullScreen()
        }
        wakeControls()
    }

    Component.onCompleted: {
        Library.initialize(dataDirectory)
        Analysis.initialize(kiwiDirectory)
        wakeControls()
        if (startupPath)
            openVideoPath(startupPath)
    }
    onClosing: {
        readerPage.flushProgress()
        if (page === "watch")
            saveVideoProgress()
    }

    Connections {
        target: root.renderHost
        function onRendererReady(ready) { root.player.rendererReady(ready) }
        function onRendererFailed(result) { root.player.rendererFailed(result) }
    }

    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: {
            root.player.poll()
            if (root.player.loaded && !root.player.paused && !root.player.ended)
                root.renderHost.checkFrame()
        }
    }

    Connections {
        target: root.player
        function onMediaOpening() {
            watchPage.closeAnalysis()
            root.subtitles.reset()
            root.captionsVisible = true
            root.wakeControls()
        }
        function onMediaReady(path) {
            root.subtitles.probe(path)
            root.wakeControls()
            const video = root.currentVideo
            if (video?.sidecar)
                root.subtitles.attachSaved(video.sidecar)
            Qt.callLater(() => {
                if (root.currentVideo !== video)
                    return
                const savedPosition = video?.seconds ?? 0
                const resumeAt = root.player.duration > 0
                    ? Math.min(savedPosition, Math.max(0, root.player.duration - 0.1))
                    : savedPosition
                root.awaitingVideoPosition = resumeAt > 0
                if (resumeAt > 0)
                    root.player.seek(resumeAt)
                root.videoReady = true
                if (root.page === "watch")
                    videoProgressTimer.start()
                else
                    root.player.pause()
            })
        }
        function onPositionChanged() {
            root.subtitles.update(root.player.position)
            if (!root.videoReady || root.page !== "watch" || !root.currentVideo?.id)
                return
            if (root.player.position > 0)
                root.awaitingVideoPosition = false
            if (!videoProgressTimer.running)
                videoProgressTimer.start()
        }
    }

    Timer {
        id: videoProgressTimer
        interval: 3000
        onTriggered: root.saveVideoProgress()
    }

    Timer {
        id: hideControls
        interval: 2300
        onTriggered: root.controlsAwake = false
    }

    Shortcut {
        sequence: "F"
        enabled: root.watchShortcutsEnabled
        onActivated: root.toggleFullscreen()
    }
    Shortcut {
        sequence: "Esc"
        enabled: root.fullScreen && !watchPage.trackMenu.opened && !watchPage.analysisOpened && !settingsSheet.visible
        onActivated: root.toggleFullscreen()
    }
    Shortcut {
        sequence: "C"
        enabled: root.watchShortcutsEnabled
        onActivated: {
            root.captionsVisible = !root.captionsVisible
            root.wakeControls()
        }
    }
    Shortcut {
        sequence: "Space"
        enabled: root.watchShortcutsEnabled
        onActivated: {
            root.player.togglePlay()
            root.wakeControls()
        }
    }
    Shortcut {
        sequence: "Left"
        enabled: root.watchShortcutsEnabled
        onActivated: {
            root.player.seek(root.player.position - 5)
            root.wakeControls()
        }
    }
    Shortcut {
        sequence: "Right"
        enabled: root.watchShortcutsEnabled
        onActivated: {
            root.player.seek(root.player.position + 5)
            root.wakeControls()
        }
    }
    Shortcut {
        sequences: [StandardKey.Back]
        enabled: !root.fullScreen && !settingsSheet.visible && !watchPage.trackMenu.opened
        onActivated: root.goBack(root.page === "reader" ? "library" : "home")
    }
    Shortcut {
        sequence: "Ctrl+B"
        enabled: !root.fullScreen && !settingsSheet.visible
        onActivated: root.sidebarExpanded = !root.sidebarExpanded
    }

    FileDialog {
        id: videoPicker
        title: "Open a local video"
        nameFilters: ["Video files (*.mkv *.mp4 *.m4v *.mov *.webm *.avi *.ts)", "All files (*)"]
        onAccepted: root.openLocalVideo(selectedFile)
    }
    FileDialog {
        id: subtitlePicker
        title: "Attach subtitles"
        nameFilters: ["Subtitle files (*.srt *.vtt)", "All files (*)"]
        onAccepted: root.attachSubtitles(selectedFile)
    }

    Rectangle {
        anchors.fill: parent
        color: root.fullScreen ? "#000000" : Theme.background
    }

    AppSidebar {
        id: sidebar
        objectName: "appSidebar"
        visible: !root.fullScreen
        width: implicitWidth
        height: parent.height
        currentPage: root.page === "reader" ? "library" : root.page
        expanded: root.sidebarExpanded
        vocabularyCount: Library.vocabulary.length
        onToggleRequested: root.sidebarExpanded = !root.sidebarExpanded
        onPageRequested: pageName => root.navigate(pageName)
        onSettingsRequested: settingsSheet.open()
    }

    Item {
        id: content
        anchors.left: root.fullScreen ? parent.left : sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            visible: !root.fullScreen && root.page !== "watch"

            PageHeader {
                Layout.fillWidth: true
                title: root.page === "reader" ? readerPage.documentTitle : root.pageTitle
                backLabel: root.page === "reader" ? "My Library" : ""
                searchVisible: root.page === "home"
                searchEnabled: YouTube.configured
                maximumContentWidth: root.page === "home" ? 1528 : 0
                placeholder: "Search YouTube for Korean videos"
                onBackRequested: root.goBack("library")
                onSearchAccepted: query => {
                    if (query.trim()) {
                        root.navigate("explore")
                        explorePage.browse(query)
                    }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: {
                    switch (root.page) {
                    case "home": return 0
                    case "explore": return 1
                    case "library": return 2
                    case "reader": return 3
                    case "vocabulary": return 4
                    case "history": return 5
                    default: return 0
                    }
                }

                HomePage {
                    id: homePage
                    onOpenLibraryRequested: root.navigate("library")
                    onOpenVideoRequested: videoPicker.open()
                    onResumeVideoRequested: id => homePage.resumeError = root.openSavedVideo(id)
                }
                ExplorePage {
                    id: explorePage
                }
                LibraryPage {
                    renderHost: root.renderHost
                    onOpenReaderRequested: (id, title) => {
                        readerPage.openDocument(id, title)
                        root.navigate("reader")
                    }
                    onOpenWatchRequested: id => error = root.openSavedVideo(id)
                    onImportVideoRequested: videoPicker.open()
                }
                ReaderPage {
                    id: readerPage
                    active: root.page === "reader"
                }
                VocabularyPage {}
                HistoryPage {
                    onOpenLibraryRequested: root.navigate("library")
                    onOpenWatchRequested: id => error = root.openSavedVideo(id)
                }
            }
        }

        Item {
            anchors.fill: parent
            visible: root.page === "watch"

            Rectangle {
                anchors.fill: parent
                color: root.fullScreen ? "#000000" : Theme.background
            }

            WatchPage {
                id: watchPage
                anchors.fill: parent
                player: root.player
                subtitles: root.subtitles
                renderHost: root.renderHost
                fullScreen: root.fullScreen
                controlsAwake: root.controlsAwake
                captionsVisible: root.captionsVisible
                nativeText: Theme.nativeText
                libraryError: root.videoError
                videoId: root.currentVideo?.id ?? 0
                backLabel: root.pageStack[root.pageStack.length - 1] === "library" ? "My Library" : "Back"
                onNativeTextRequested: enabled => Theme.nativeText = enabled
                onWakeControlsRequested: root.wakeControls()
                onToggleFullscreenRequested: root.toggleFullscreen()
                onCaptionsToggleRequested: root.captionsVisible = !root.captionsVisible
                onOpenVideoRequested: videoPicker.open()
                onOpenSubtitlesRequested: subtitlePicker.open()
                onBackRequested: root.goBack("home")
            }
        }
    }

    SettingsSheet {
        id: settingsSheet
        parent: root.contentItem
    }
}
