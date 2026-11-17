import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../style"

Dialog {
    id: root

    title: "Edit saved word"
    anchors.centerIn: parent
    width: Math.min(500, parent.width - 48)
    height: Math.min(form.implicitHeight + heading.implicitHeight + 56, parent.height - 48)
    padding: 20
    modal: true
    header: null

    function openEntry(entry) {
        form.openEntry(entry)
        open()
        scroll.contentItem.contentY = 0
        form.focusWord()
    }

    background: Rectangle {
        color: Theme.card
        radius: Theme.radiusLarge
        border.width: 1
        border.color: Theme.border
    }

    contentItem: ColumnLayout {
        spacing: 16

        AppText {
            id: heading
            text: root.title
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }

        AppScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            contentHeight: form.implicitHeight
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            clip: true

            VocabularyForm {
                id: form
                width: scroll.availableWidth
                onCloseRequested: root.close()
            }
        }
    }
}
