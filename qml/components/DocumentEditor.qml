import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../style"

Dialog {
    id: root

    property bool importing: true
    property string error: ""
    signal saveRequested(string title, string content)
    signal chooseFileRequested()

    title: importing ? "Import text" : "Edit document"
    anchors.centerIn: parent
    width: Math.min(560, parent.width - 48)
    height: Math.min(520, parent.height - 48)
    modal: true

    function showEditor(importing, title, content) {
        root.importing = importing
        titleInput.text = title
        body.text = content
        error = ""
        open()
        titleInput.forceActiveFocus()
    }

    contentItem: ColumnLayout {
        spacing: 12

        AppButton {
            visible: root.importing
            text: "Choose a .txt file"
            iconName: "folder-open"
            variant: "outline"
            onClicked: root.chooseFileRequested()
        }

        AppInput {
            id: titleInput
            Layout.fillWidth: true
            placeholderText: "Title"
            Accessible.name: "Document title"
        }

        AppScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            TextArea {
                id: body
                placeholderText: "Paste or type Korean text"
                textFormat: TextEdit.PlainText
                wrapMode: TextEdit.Wrap
                color: Theme.foreground
                font.family: "Noto Sans KR"
                font.pixelSize: 15
                Accessible.name: "Document text"

                background: Rectangle {
                    radius: Theme.radiusSmall
                    color: Theme.card
                    border.color: Theme.border
                }
            }
        }

        AppText {
            visible: text !== ""
            text: root.error
            color: Theme.destructive
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight

            AppButton { text: "Cancel"; variant: "ghost"; onClicked: root.close() }
            AppButton {
                text: root.importing ? "Import text" : "Save changes"
                enabled: body.text.trim() !== "" && (root.importing || titleInput.text.trim() !== "")
                onClicked: root.saveRequested(titleInput.text, body.text)
            }
        }
    }
}
