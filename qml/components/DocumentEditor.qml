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

    title: importing ? "Import text or PDF" : "Edit document"
    anchors.centerIn: parent
    width: Math.min(560, parent.width - 48)
    height: Math.min(520, parent.height - 48)
    modal: true
    padding: 20
    header: null

    background: Rectangle {
        color: Theme.card
        radius: Theme.radiusLarge
        border.width: 0
    }

    function showEditor(importing, title, content) {
        root.importing = importing
        titleInput.text = title
        body.text = content
        error = ""
        open()
        titleInput.forceActiveFocus()
    }

    contentItem: ColumnLayout {
        spacing: 6

        AppText {
            text: root.title
            font.pixelSize: 18
            font.weight: Font.DemiBold
            Layout.bottomMargin: 8
        }

        AppButton {
            visible: root.importing
            text: "Choose a text or PDF file"
            iconName: "folder-open"
            variant: "outline"
            Layout.bottomMargin: 8
            onClicked: root.chooseFileRequested()
        }

        AppText {
            text: "Title"
            font.weight: Font.Medium
        }

        AppInput {
            id: titleInput
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            placeholderText: "Title"
            Accessible.name: "Document title"
        }

        AppText {
            text: "Text"
            font.weight: Font.Medium
        }

        AppScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            background: Rectangle {
                radius: Theme.radius
                color: Theme.card
                border.width: body.activeFocus ? 2 : 1
                border.color: body.activeFocus ? Theme.accent : Theme.border
            }

            TextArea {
                id: body
                placeholderText: "Paste or type Korean text"
                textFormat: TextEdit.PlainText
                wrapMode: TextEdit.Wrap
                padding: 12
                rightPadding: 16
                selectByMouse: true
                color: Theme.foreground
                placeholderTextColor: Theme.mutedForeground
                selectionColor: Theme.accent
                selectedTextColor: Theme.onAccent
                font.family: "Noto Sans KR"
                font.pixelSize: 15
                Accessible.name: "Document text"
                background: null
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
            Layout.topMargin: 8
            spacing: Theme.controlGap

            AppButton {
                text: "Cancel"
                variant: "outline"
                onClicked: root.close()
            }
            AppButton {
                text: root.importing ? "Import text" : "Save changes"
                variant: "primary"
                enabled: body.text.trim() !== ""
                    && (root.importing || titleInput.text.trim() !== "")
                onClicked: root.saveRequested(titleInput.text, body.text)
            }
        }
    }
}
