import QtQuick
import QtQuick.Controls

Dialog {
    id: root

    title: form.entry?.word ?? "Edit saved word"
    anchors.centerIn: parent
    width: Math.min(500, parent.width - 48)
    modal: true

    function openEntry(entry) {
        form.openEntry(entry)
        open()
    }

    contentItem: VocabularyForm {
        id: form
        onCloseRequested: root.close()
    }
}
