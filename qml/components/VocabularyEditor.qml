import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sori_qt_playback
import "../Theme.js" as Theme

Dialog {
    id: root

    property var entry: null
    property string error: ""

    title: entry?.word ?? "Edit saved word"
    anchors.centerIn: parent
    width: Math.min(500, parent.width - 48)
    modal: true

    function openEntry(entry) {
        root.entry = entry
        normalized.text = entry.normalizedForm ?? ""
        meaning.text = entry.definition?.text ?? ""
        note.text = entry.definition?.note ?? ""
        tags.text = entry.tags.join(", ")
        error = ""
        open()
    }

    function save() {
        error = Library.editWord(entry.id, {
            normalizedForm: normalized.text,
            meaning: meaning.text,
            note: note.text,
            tags: tags.text.split(",").map(tag => tag.trim()).filter(tag => tag !== "")
        })
        if (!error)
            close()
    }

    contentItem: ColumnLayout {
        spacing: 10

        AppText { text: "Dictionary form" }
        AppInput { id: normalized; Layout.fillWidth: true; Accessible.name: "Dictionary form" }
        AppText { text: "Meaning" }
        AppInput { id: meaning; Layout.fillWidth: true; Accessible.name: "Meaning" }
        AppText { text: "Note" }
        AppInput { id: note; Layout.fillWidth: true; Accessible.name: "Note" }
        AppText { text: "Tags" }
        AppInput {
            id: tags
            Layout.fillWidth: true
            placeholderText: "Separate tags with commas"
            Accessible.name: "Tags"
        }
        AppText {
            visible: text !== ""
            text: root.error
            color: Theme.destructive
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }
        RowLayout {
            Layout.alignment: Qt.AlignRight
            AppButton { text: "Cancel"; variant: "ghost"; onClicked: root.close() }
            AppButton { text: "Save changes"; onClicked: root.save() }
        }
    }
}
