import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs as Native
import QtQuick.Layouts
import sori_core
import "../style"
import "../components"

Item {
    id: root

    required property var renderHost
    property string error: ""
    property var selectedDocument: null

    readonly property string query: search.text.trim().toLowerCase()
    readonly property bool searching: query !== ""
    readonly property bool libraryEmpty: Library.documents.length === 0
        && Library.videos.length === 0
    readonly property var matchingDocuments: Library.documents.filter(document =>
        (document.title ?? "").toLowerCase().includes(root.query))
    readonly property var matchingVideos: Library.videos.filter(video =>
        ((video.displayTitle ?? "") + " " + (video.title ?? "")).toLowerCase().includes(root.query))
    readonly property bool nothingMatches: searching && matchingDocuments.length === 0
        && matchingVideos.length === 0

    signal openReaderRequested(real documentId, string title)
    signal openWatchRequested(real videoId)
    signal importVideoRequested

    function importText() {
        selectedDocument = null;
        editor.showEditor(true, "", "");
    }

    function editDocument(document) {
        const result = Library.readDocument(document.id);
        if (result.error) {
            error = result.error;
            return;
        }
        selectedDocument = document;
        editor.showEditor(false, document.title, result.content);
    }

    function requestThumbnails() {
        for (const video of Library.videos) {
            if (!video.thumbnailUrl)
                Library.ensureVideoThumbnail(video.id);
        }
    }

    function confirmRemoval(item, video) {
        selectedDocument = {
            id: item.id,
            title: video ? (item.displayTitle || item.title) : item.title,
            video: video
        };
        confirmRemovalDialog.open();
    }

    Component.onCompleted: requestThumbnails()
    onVisibleChanged: if (visible)
        requestThumbnails()

    Connections {
        target: Library

        function onVideosChanged() {
            root.requestThumbnails();
        }

        function onDocumentImportFinished(error) {
            editor.working = false;
            if (error) {
                if (editor.visible)
                    editor.error = error;
                else
                    root.error = error;
                return;
            }
            search.clear();
            root.error = "";
            editor.close();
        }
    }

    DocumentEditor {
        id: editor
        parent: Overlay.overlay
        onChooseFileRequested: textPicker.open()
        onSaveRequested: (title, content) => {
            error = importing ? Library.addDocument(title, content) : Library.updateDocument(root.selectedDocument.id, title, content);
            if (!error) {
                if (importing)
                    search.clear();
                root.error = "";
                close();
            }
        }
    }

    Native.FileDialog {
        id: textPicker
        title: "Import a text or PDF file"
        nameFilters: [
            "Text and PDF files (*.txt *.TXT *.pdf *.PDF)",
            "Text files (*.txt *.TXT)",
            "PDF files (*.pdf *.PDF)",
            "All files (*)"
        ]
        onAccepted: {
            const path = root.renderHost.localPath(selectedFile);
            if (!path) {
                editor.error = "Choose a .txt or .pdf file.";
                return;
            }
            editor.error = "";
            editor.working = true;
            Library.importDocument(path);
        }
    }

    Dialog {
        id: confirmRemovalDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        width: Math.min(380, parent.width - 48)
        title: root.selectedDocument?.video ? "Remove video?" : "Delete document?"
        standardButtons: Dialog.NoButton
        padding: 0

        background: Rectangle {
            color: Theme.card
            radius: Theme.radiusLarge
            border.width: 1
            border.color: Theme.border
        }

        header: Item {
            implicitHeight: headerContent.implicitHeight + 40

            ColumnLayout {
                id: headerContent
                anchors.fill: parent
                anchors.margins: 20
                spacing: 6

                AppText {
                    text: confirmRemovalDialog.title
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }

                AppText {
                    text: root.selectedDocument?.video ? "Remove “" + root.selectedDocument.title + "” from your library? The video file stays on disk." : "Delete “" + (root.selectedDocument?.title ?? "") + "” from your library?"
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: Theme.mutedForeground
                }
            }
        }

        contentItem: Item {
            implicitHeight: actionsContent.implicitHeight + 40

            RowLayout {
                id: actionsContent
                anchors.fill: parent
                anchors.margins: 20
                spacing: 8

                Item {
                    Layout.fillWidth: true
                }

                AppButton {
                    text: "Cancel"
                    variant: "outline"
                    small: true
                    onClicked: confirmRemovalDialog.close()
                }

                AppButton {
                    text: root.selectedDocument?.video ? "Remove" : "Delete"
                    variant: "primary"
                    small: true
                    onClicked: {
                        root.error = root.selectedDocument.video ? Library.removeVideo(root.selectedDocument.id) : Library.removeDocument(root.selectedDocument.id);
                        confirmRemovalDialog.close();
                    }
                }
            }
        }
    }

    PageFrame {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: 16

        RowLayout {
            Layout.fillWidth: true

            AppInput {
                id: search
                Layout.fillWidth: true
                Layout.maximumWidth: 440
                placeholderText: "Search your library"
                iconName: "search"
            }
            Item {
                Layout.fillWidth: true
            }
            AppButton {
                text: "Import text"
                iconName: "plus"
                variant: "outline"
                onClicked: root.importText()
            }
            AppButton {
                text: "Import video"
                iconName: "film"
                variant: "outline"
                onClicked: root.importVideoRequested()
            }
        }

        AppText {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.error || Library.error
            color: Theme.destructive
            wrapMode: Text.Wrap
        }

        ScrollView {
            id: scroller
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.libraryEmpty && !root.nothingMatches
            contentWidth: availableWidth
            clip: true
            ScrollBar.vertical: AppScrollBar {}

            ColumnLayout {
                width: scroller.availableWidth
                spacing: Theme.dashboardRowGap

                MediaShelf {
                    id: textShelf
                    Layout.fillWidth: true
                    visible: root.searching ? count > 0 : !root.libraryEmpty
                    title: "Text materials"
                    model: root.matchingDocuments
                    cardsPerView: 5.2
                    minimumCardWidth: 150
                    maximumCardWidth: 220
                    coverRatio: 0.75
                    emptyText: "No text yet"
                    emptyActionText: "Import text"
                    onOpenRequested: item => root.openReaderRequested(item.id, item.title)
                    onEditRequested: item => root.editDocument(item)
                    onRemoveRequested: item => root.confirmRemoval(item, false)
                    onEmptyActionRequested: root.importText()
                }

                MediaShelf {
                    id: videoShelf
                    Layout.fillWidth: true
                    visible: root.searching ? count > 0 : !root.libraryEmpty
                    title: "Videos"
                    model: root.matchingVideos
                    video: true
                    cardsPerView: 3.2
                    minimumCardWidth: 220
                    maximumCardWidth: 340
                    coverRatio: 16 / 9
                    showMeta: true
                    emptyText: "No videos yet"
                    emptyActionText: "Import video"
                    onOpenRequested: item => root.openWatchRequested(item.id)
                    onRemoveRequested: item => root.confirmRemoval(item, true)
                    onEmptyActionRequested: root.importVideoRequested()
                }
            }
        }

        EmptyState {
            Layout.fillWidth: true
            Layout.preferredHeight: 288
            Layout.alignment: Qt.AlignTop
            visible: root.libraryEmpty || root.nothingMatches
            iconName: "library"
            title: root.nothingMatches ? "No matching items" : "Your library is empty"
            message: root.nothingMatches ? "" : "Import a video, a .txt or .pdf file, or pasted Korean text."
            actionText: root.nothingMatches ? "" : "Import text"
            onActionRequested: root.importText()
        }

        Item {
            visible: root.libraryEmpty || root.nothingMatches
            Layout.fillHeight: true
        }
    }
}
