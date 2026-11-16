import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Sori 1.0
import sori_qt_playback
import "components"
import "pages"
import "Theme.js" as Theme

ApplicationWindow {
    id: root

    required property var renderHost
    required property string dataDirectory
    required property string startupPath
    readonly property var player: Player
    readonly property var subtitles: Subtitles
    readonly property bool fullScreen: visibility === Window.FullScreen
    readonly property bool watchShortcutsEnabled: page === "watch" && player.loaded
        && !watchPage.trackMenu.opened && !settingsSheet.visible
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
    property bool followPlayback: true
    property bool nativeText: true
    property int previousVisibility: Window.Windowed
    property string appearance: "system"
    property var pageStack: []

    width: 1280
    height: 840
    minimumWidth: 860
    minimumHeight: 600
    visible: true
    title: pageTitle === "Home" ? "Sori" : pageTitle + " · Sori"
    color: page === "watch" ? Theme.darkBackground : Theme.background
    font.family: "Inter"

    function navigate(nextPage, pushHistory) {
        if (nextPage === page)
            return
        if (pushHistory !== false)
            pageStack = pageStack.concat([page])
        page = nextPage
    }

    function goBack(fallback) {
        if (pageStack.length > 0) {
            const previous = pageStack[pageStack.length - 1]
            pageStack = pageStack.slice(0, -1)
            page = previous
        } else {
            navigate(fallback || "home", false)
        }
    }

    function wakeControls() {
        controlsAwake = true
        hideControls.restart()
    }

    function openLocalVideo(url) {
        const path = renderHost.localPath(url)
        if (!path)
            return
        navigate("watch")
        player.open(path)
        wakeControls()
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
        wakeControls()
        if (startupPath) {
            navigate("watch")
            player.open(startupPath)
        }
    }
    onPageChanged: if (page !== "reader") readerPage.flushProgress()
    onClosing: readerPage.flushProgress()

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
            root.navigate("watch")
            root.subtitles.reset()
            root.followPlayback = true
            root.captionsVisible = true
            root.wakeControls()
        }
        function onMediaReady(path) {
            root.subtitles.probe(path)
            root.wakeControls()
        }
        function onPositionChanged() { root.subtitles.update(root.player.position) }
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
        enabled: root.fullScreen && !watchPage.trackMenu.opened && !settingsSheet.visible
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
        onAccepted: root.subtitles.attach(root.renderHost.localPath(selectedFile))
    }

    Rectangle {
        anchors.fill: parent
        color: root.page === "watch" ? Theme.darkBackground : Theme.background
    }

    AppSidebar {
        id: sidebar
        objectName: "appSidebar"
        visible: !root.fullScreen
        width: implicitWidth
        height: parent.height
        currentPage: root.page === "reader" ? "library" : root.page
        expanded: root.sidebarExpanded
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
                placeholder: "Search videos, podcasts, articles, or creators"
                onBackRequested: root.goBack("library")
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
                    onOpenLibraryRequested: root.navigate("library")
                    onOpenVideoRequested: videoPicker.open()
                }
                ExplorePage {}
                LibraryPage {
                    renderHost: root.renderHost
                    onOpenReaderRequested: (id, title) => {
                        readerPage.openDocument(id, title)
                        root.navigate("reader")
                    }
                    onOpenWatchRequested: id => root.navigate("watch")
                }
                ReaderPage {
                    id: readerPage
                    active: root.page === "reader"
                }
                VocabularyPage {}
                HistoryPage { onExploreRequested: root.navigate("explore") }
            }
        }

        Item {
            anchors.fill: parent
            visible: root.page === "watch"

            Rectangle {
                anchors.fill: parent
                color: Theme.darkBackground
            }

            WatchPage {
                id: watchPage
                anchors.fill: parent
                anchors.margins: root.fullScreen ? 0 : 24
                player: root.player
                subtitles: root.subtitles
                renderHost: root.renderHost
                fullScreen: root.fullScreen
                controlsAwake: root.controlsAwake
                captionsVisible: root.captionsVisible
                followPlayback: root.followPlayback
                nativeText: root.nativeText
                onNativeTextRequested: enabled => root.nativeText = enabled
                onWakeControlsRequested: root.wakeControls()
                onToggleFullscreenRequested: root.toggleFullscreen()
                onCaptionsToggleRequested: root.captionsVisible = !root.captionsVisible
                onOpenVideoRequested: videoPicker.open()
                onOpenSubtitlesRequested: subtitlePicker.open()
                onFollowPlaybackRequested: follow => root.followPlayback = follow
                onBackRequested: root.goBack("home")
            }
        }
    }

    SettingsSheet {
        id: settingsSheet
        parent: root.contentItem
        appearance: root.appearance
        nativeText: root.nativeText
        onAppearanceChanged: root.appearance = appearance
        onNativeTextRequested: enabled => root.nativeText = enabled
    }
}
