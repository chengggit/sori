import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sori_qt_playback
import "../style"

ColumnLayout {
    id: root

    property var entry: null
    property string error: ""
    property real documentId: 0
    property bool panelMode: false
    signal changed()
    signal closeRequested()

    spacing: 10

    function focusWord() {
        normalized.forceActiveFocus(Qt.TabFocusReason)
    }

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
        normalized.text = entry.normalizedForm || (panelMode ? entry.word : "")
        meaning.text = entry.definition?.text ?? ""
        note.text = entry.definition?.note ?? ""
        tags.text = entry.tags.join(", ")
        error = ""
        noteToggle.checked = !!note.text
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
            closeRequested()
        }
    }

    AppText { text: root.panelMode ? "Word" : "Dictionary form" }
    AppInput {
        id: normalized
        Layout.fillWidth: true
        surfaceColor: root.panelMode ? Theme.background : Theme.card
        Accessible.name: root.panelMode ? "Word" : "Dictionary form"
    }

    AppText { text: root.panelMode ? "Meanings" : "Meaning" }
    AppScrollView {
        Layout.fillWidth: true
        Layout.preferredHeight: 80
        contentWidth: availableWidth
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        background: Rectangle {
            color: root.panelMode ? Theme.background : Theme.card
            border.color: meaning.activeFocus ? Theme.accent : Theme.border
            radius: Theme.radiusSmall
        }

        TextArea {
            id: meaning
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
            color: Theme.foreground
            selectionColor: Theme.accent
            selectedTextColor: Theme.onAccent
            selectByMouse: true
            placeholderText: "Add a meaning for this word"
            placeholderTextColor: Theme.mutedForeground
            padding: 12
            font.family: "Inter"
            font.pixelSize: 14
            Accessible.name: root.panelMode ? "Meanings" : "Meaning"
            background: null
        }
    }

    AppText { text: "Tags" }
    AppInput {
        id: tags
        surfaceColor: root.panelMode ? Theme.background : Theme.card
        Layout.fillWidth: true
        placeholderText: root.panelMode ? "e.g. reading, verbs, science" : "Separate tags with commas"
        Accessible.name: "Tags"
    }
    AppText {
        visible: root.panelMode
        text: "Separate tags with commas."
        color: Theme.mutedForeground
        font.pixelSize: 12
    }

    AppText { visible: !root.panelMode; text: "Note" }
    Button {
        id: noteToggle
        visible: root.panelMode
        checkable: true
        text: checked ? "▾ Note (optional)" : "▸ Note (optional)"
        padding: 0
        background: Rectangle { color: "transparent" }
        contentItem: AppText {
            text: noteToggle.text
            color: Theme.mutedForeground
        }
    }
    AppScrollView {
        visible: !root.panelMode || noteToggle.checked
        Layout.fillWidth: true
        Layout.preferredHeight: 64
        contentWidth: availableWidth
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        background: Rectangle {
            color: root.panelMode ? Theme.background : Theme.card
            radius: Theme.radiusSmall
            border.color: note.activeFocus ? Theme.accent : Theme.border
        }

        TextArea {
            id: note
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
            color: Theme.foreground
            selectionColor: Theme.accent
            selectedTextColor: Theme.onAccent
            selectByMouse: true
            font.family: "Inter"
            font.pixelSize: 14
            padding: 12
            Accessible.name: "Note"
            background: null
        }
    }

    AppText {
        visible: text !== ""
        text: root.error
        Layout.fillWidth: true
        color: Theme.destructive
        wrapMode: Text.Wrap
    }
    RowLayout {
        Layout.fillWidth: true
        AppButton {
            visible: root.panelMode && !!root.entry?.id
            text: "Remove"
            variant: "outline"
            onClicked: {
                root.error = Library.removeWord(root.entry.id)
                if (!root.error) {
                    root.changed()
                    root.closeRequested()
                }
            }
        }
        Item { Layout.fillWidth: true }
        AppButton { text: "Cancel"; variant: "outline"; onClicked: root.closeRequested() }
        AppButton {
            text: root.documentId ? "Save word" : "Save changes"
            variant: "primary"
            onClicked: root.save()
        }
    }
}
