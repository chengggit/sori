import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sori_qt_playback
import "../style"
import "../components"

Item {
    id: root

    property string error: ""
    property var selectedEntry: null
    readonly property var matchingEntries: {
        const query = search.text.trim().toLowerCase()
        return Library.vocabulary.filter(entry => [
            entry.word, entry.normalizedForm, entry.definition?.text,
            entry.definition?.note, entry.context, entry.sourceTitle, ...entry.tags
        ].filter(s => !!s).some(s => s.toLowerCase().includes(query)))
    }

    VocabularyEditor {
        id: editor
        parent: Overlay.overlay
    }

    Dialog {
        id: confirmRemoval
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        width: Math.min(380, parent.width - 48)
        title: "Remove saved word?"
        standardButtons: Dialog.Cancel | Dialog.Yes

        contentItem: AppText {
            text: "Remove “" + (root.selectedEntry?.word ?? "") + "” from Vocabulary?"
            wrapMode: Text.Wrap
        }

        onAccepted: root.error = Library.removeWord(root.selectedEntry.id)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 16

        AppInput {
            id: search
            Layout.fillWidth: true
            Layout.maximumWidth: 440
            placeholderText: "Search vocabulary"
            iconName: "search"
        }

        AppText {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.error || Library.error
            color: Theme.destructive
            wrapMode: Text.Wrap
        }

        ListView {
            id: entries
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: count > 0
            model: root.matchingEntries
            clip: true
            spacing: 10
            ScrollBar.vertical: AppScrollBar {}

            delegate: Rectangle {
                id: card
                required property var modelData
                width: ListView.view.width
                height: fields.implicitHeight + 28
                color: Theme.card
                border.color: Theme.border
                radius: Theme.radiusSmall

                ColumnLayout {
                    id: fields
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        AppText {
                            text: card.modelData.word
                            korean: true
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        AppButton { text: "Edit"; variant: "outline"; small: true; onClicked: editor.openEntry(card.modelData) }
                        AppButton {
                            text: "Remove"
                            variant: "ghost"
                            small: true
                            onClicked: {
                                root.selectedEntry = card.modelData
                                confirmRemoval.open()
                            }
                        }
                    }
                    AppText {
                        visible: text !== ""
                        text: card.modelData.normalizedForm ?? ""
                        korean: true
                        color: Theme.accent
                    }
                    AppText {
                        visible: text !== ""
                        text: card.modelData.definition?.text ?? ""
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }
                    AppText {
                        visible: text !== ""
                        text: card.modelData.definition?.note ?? ""
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }
                    AppText {
                        Layout.fillWidth: true
                        text: card.modelData.context
                        korean: true
                        wrapMode: Text.Wrap
                        color: Theme.mutedForeground
                    }
                    AppText {
                        Layout.fillWidth: true
                        text: [card.modelData.sourceTitle, ...card.modelData.tags].join(" · ")
                        elide: Text.ElideRight
                        color: Theme.mutedForeground
                        font.pixelSize: 12
                    }
                }
            }
        }

        EmptyState {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: entries.count === 0
            iconName: "bookmark"
            title: search.text.trim() ? "No matching words" : "No saved vocabulary yet"
            message: search.text.trim() ? "" : "Click a word in Reader or in a subtitle to analyze and save it."
        }
    }
}
