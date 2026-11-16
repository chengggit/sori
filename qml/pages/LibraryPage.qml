import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs as Native
import QtQuick.Layouts
import sori_qt_playback
import "../Theme.js" as Theme
import "../components"

Item {
    id: root

    required property var renderHost
    property string error: ""
    property var selectedDocument: null
    readonly property var matchingDocuments: {
        const query = search.text.trim().toLowerCase()
        return Library.documents.filter(document => document.title.toLowerCase().includes(query))
    }

    signal openReaderRequested(real documentId, string title)
    signal openWatchRequested(real videoId)

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
        title: "Delete document?"
        standardButtons: Dialog.Cancel | Dialog.Yes
        contentItem: AppText {
            text: "Delete “" + (root.selectedDocument?.title ?? "") + "” from your library?"
            wrapMode: Text.Wrap
        }
        onAccepted: root.error = Library.removeDocument(root.selectedDocument.id)
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
            AppButton { text: "Import"; iconName: "plus"; onClicked: root.importText() }
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
            model: root.matchingDocuments
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

                    Icon { name: "file-text"; color: Theme.accent }
                    AppText {
                        Layout.fillWidth: true
                        text: row.modelData.title
                        elide: Text.ElideRight
                    }
                    AppButton {
                        text: "Read"
                        variant: "outline"
                        small: true
                        onClicked: root.openReaderRequested(row.modelData.id, row.modelData.title)
                    }
                    AppButton {
                        text: "Edit"
                        variant: "ghost"
                        small: true
                        onClicked: root.editDocument(row.modelData)
                    }
                    AppButton {
                        text: "Delete"
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
            title: Library.documents.length ? "No matching documents" : "Your library is empty"
            message: Library.documents.length ? "" : "Import a .txt file or paste Korean text."
            actionText: Library.documents.length ? "" : "Import text"
            onActionRequested: root.importText()
        }
    }
}
