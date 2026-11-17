import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sori_qt_playback
import "../style"

Dialog {
    id: root

    property var entry: null
    property string error: ""
    property real documentId: 0
    property bool allowRemoval: false
    signal changed()

    title: entry?.word ?? "Edit saved word"
    anchors.centerIn: parent
    width: Math.min(500, parent.width - 48)
    modal: true

    function openEntry(entry) {
        documentId = 0
        setFields(entry)
    }

    function openDraft(sourceId, analysis, definition) {
        documentId = sourceId
        setFields({
            word: analysis.word,
            normalizedForm: definition?.term || analysis.normalizedForm,
            context: analysis.context,
            definition: definition,
            tags: []
        })
    }

    function setFields(entry) {
        root.entry = entry
        normalized.text = entry.normalizedForm ?? ""
        meaning.text = entry.definition?.text ?? ""
        note.text = entry.definition?.note ?? ""
        tags.text = entry.tags.join(", ")
        error = ""
        open()
    }

    function save() {
        const updates = {
            normalizedForm: normalized.text.trim(),
            meaning: meaning.text.trim(),
            note: note.text.trim(),
            tags: tags.text.split(",").map(tag => tag.trim()).filter(tag => tag !== "")
        }
        if (updates.note && !updates.meaning) {
            error = "Enter a meaning to save a note."
            return
        }
        if (!documentId) {
            error = Library.editWord(entry.id, updates)
        } else {
            const imported = entry.definition && updates.meaning === entry.definition.text
            const definition = updates.meaning ? {
                term: imported ? entry.definition.term : (updates.normalizedForm || entry.word),
                partOfSpeech: imported ? entry.definition.partOfSpeech : "",
                sourceUrl: imported ? entry.definition.sourceUrl : "",
                hanja: imported ? entry.definition.hanja : null,
                text: updates.meaning,
                note: updates.note,
                custom: !imported || entry.definition.custom
            } : null
            const saved = Library.saveWord("document", documentId, {
                word: entry.word,
                context: entry.context,
                normalizedForm: updates.normalizedForm === entry.word ? null : updates.normalizedForm,
                definition: definition,
                tags: updates.tags
            })
            error = saved.error || ""
        }
        if (!error) {
            changed()
            close()
        }
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
            Layout.fillWidth: true
            AppButton {
                visible: root.allowRemoval && !!root.entry?.id
                text: "Remove"
                variant: "outline"
                onClicked: {
                    root.error = Library.removeWord(root.entry.id)
                    if (!root.error) {
                        root.changed()
                        root.close()
                    }
                }
            }
            Item { Layout.fillWidth: true }
            AppButton { text: "Cancel"; variant: "ghost"; onClicked: root.close() }
            AppButton {
                text: root.documentId ? "Save word" : "Save changes"
                onClicked: root.save()
            }
        }
    }
}
