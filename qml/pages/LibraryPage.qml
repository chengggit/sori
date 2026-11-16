import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs as Native
import QtQuick.Layouts
import sori_qt_playback
import "../style"
import "../components"

Item {
    id: root

    required property var renderHost
    property string error: ""
    property var selectedDocument: null
    readonly property var matchingItems: {
        const query = search.text.trim().toLowerCase()
        return Library.documents.map(item => ({ id: item.id, title: item.title, video: false }))
            .concat(Library.videos.map(item => ({ id: item.id, title: item.title, video: true })))
            .filter(item => item.title.toLowerCase().includes(query))
    }

    signal openReaderRequested(real documentId, string title)
    signal openWatchRequested(real videoId)
    signal importVideoRequested()

    function importText() {
        selectedDocument = null
        editor.showEditor(true, "", "")
    }

    function editDocument(document) {
        const result = Library.readDocument(document.id)
        if (result.error) {
            error = result.error
            return
        }
        selectedDocument = document
        editor.showEditor(false, document.title, result.content)
    }

    DocumentEditor {
        id: editor
        parent: Overlay.overlay
        onChooseFileRequested: textPicker.open()
        onSaveRequested: (title, content) => {
            error = importing
                ? Library.addDocument(title, content)
                : Library.updateDocument(root.selectedDocument.id, title, content)
            if (!error) {
                if (importing)
                    search.clear()
                root.error = ""
                close()
            }
        }
    }

    Native.FileDialog {
        id: textPicker
        title: "Import a text file"
        nameFilters: ["Text files (*.txt *.TXT)", "All files (*)"]
        onAccepted: {
            editor.error = Library.importDocument(root.renderHost.localPath(selectedFile))
            if (!editor.error) {
                search.clear()
                root.error = ""
                editor.close()
            }
        }
    }

    Dialog {
        id: confirmRemoval
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        width: Math.min(380, parent.width - 48)
        title: root.selectedDocument?.video ? "Remove video?" : "Delete document?"
        standardButtons: Dialog.Cancel | Dialog.Yes
        contentItem: AppText {
            text: root.selectedDocument?.video
                ? "Remove “" + root.selectedDocument.title + "” from your library? The video file stays on disk."
                : "Delete “" + (root.selectedDocument?.title ?? "") + "” from your library?"
            wrapMode: Text.Wrap
        }
        onAccepted: root.error = root.selectedDocument.video
            ? Library.removeVideo(root.selectedDocument.id)
            : Library.removeDocument(root.selectedDocument.id)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
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
            Item { Layout.fillWidth: true }
            AppButton { text: "Import text"; iconName: "plus"; onClicked: root.importText() }
            AppButton { text: "Import video"; iconName: "film"; variant: "outline"; onClicked: root.importVideoRequested() }
        }

        AppText {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.error || Library.error
            color: Theme.destructive
            wrapMode: Text.Wrap
        }

        ListView {
            id: documents
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: count > 0
            clip: true
            spacing: 8
            model: root.matchingItems
            ScrollBar.vertical: ScrollBar {}

            delegate: Rectangle {
                id: row
                required property var modelData
                width: ListView.view.width
                height: 58
                radius: Theme.radiusSmall
                color: Theme.card
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    Icon { name: row.modelData.video ? "film" : "file-text"; color: Theme.accent }
                    AppText {
                        Layout.fillWidth: true
                        text: row.modelData.title
                        elide: Text.ElideRight
                    }
                    AppButton {
                        text: row.modelData.video ? "Watch" : "Read"
                        variant: "outline"
                        small: true
                        onClicked: {
                            if (row.modelData.video)
                                root.openWatchRequested(row.modelData.id)
                            else
                                root.openReaderRequested(row.modelData.id, row.modelData.title)
                        }
                    }
                    AppButton {
                        text: "Edit"
                        visible: !row.modelData.video
                        variant: "ghost"
                        small: true
                        onClicked: root.editDocument(row.modelData)
                    }
                    AppButton {
                        text: row.modelData.video ? "Remove" : "Delete"
                        variant: "ghost"
                        small: true
                        onClicked: {
                            root.selectedDocument = row.modelData
                            confirmRemoval.open()
                        }
                    }
                }
            }
        }

        EmptyState {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: documents.count === 0 && Library.error === ""
            iconName: "library"
            title: search.text.trim() ? "No matching items" : "Your library is empty"
            message: search.text.trim() ? "" : "Import a video, a .txt file, or pasted Korean text."
            actionText: search.text.trim() ? "" : "Import text"
            onActionRequested: root.importText()
        }
    }
}
