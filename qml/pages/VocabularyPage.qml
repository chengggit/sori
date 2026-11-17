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
        const query = search.text.trim().toLowerCase();
        return Library.vocabulary.filter(entry => [entry.word, entry.normalizedForm, entry.definition?.text, entry.definition?.note, entry.context, entry.sourceTitle, ...entry.tags].filter(s => !!s).some(s => s.toLowerCase().includes(query)));
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
        padding: 20
        header: null

        background: Rectangle {
            color: Theme.card
            radius: Theme.radiusLarge
            border.width: 1
            border.color: Theme.border
        }

        contentItem: ColumnLayout {
            spacing: 16

            AppText {
                text: confirmRemoval.title
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }

            AppText {
                text: "Remove “" + (root.selectedEntry?.word ?? "") + "” from Vocabulary?"
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.mutedForeground
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: Theme.controlGap

                AppButton {
                    text: "Cancel"
                    variant: "outline"
                    onClicked: confirmRemoval.close()
                }

                AppButton {
                    text: "Remove"
                    variant: "primary"
                    onClicked: confirmRemoval.accept()
                }
            }
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
            spacing: 12
            ScrollBar.vertical: AppScrollBar {}

            delegate: Rectangle {
                id: card
                required property var modelData
                width: ListView.view.width
                readonly property string partOfSpeech: {
                    const value = card.modelData.definition?.partOfSpeech ?? "";
                    return value.toLowerCase();
                }
                height: fields.implicitHeight + 32
                color: Theme.card
                border.width: 1
                border.color: Theme.border
                radius: Theme.radius

                ColumnLayout {
                    id: fields
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        AppText {
                            text: card.modelData.word
                            korean: true
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Button {
                            id: actionsButton
                            Layout.alignment: Qt.AlignTop
                            implicitWidth: 28
                            implicitHeight: 28
                            padding: 0
                            hoverEnabled: true
                            Accessible.name: "More actions"

                            contentItem: Item {
                                Icon {
                                    anchors.centerIn: parent
                                    name: "ellipsis-vertical"
                                    size: 12
                                    color: Theme.foreground
                                }
                            }

                            background: Rectangle {
                                radius: Theme.radiusSmall
                                color: actionsButton.hovered && !actionsMenu.opened
                                    ? Theme.neutralHover : "transparent"
                            }

                            onClicked: actionsMenu.open()
                        }
                    }

                    AppText {
                        visible: text !== ""
                        text: card.modelData.definition?.text ?? ""
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        lineHeightMode: Text.ProportionalHeight
                    }

                    AppText {
                        visible: text !== ""
                        text: card.modelData.definition?.note ?? ""
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: Theme.mutedForeground
                    }

                    Rectangle {
                        visible: card.partOfSpeech !== ""
                        implicitWidth: partOfSpeechLabel.implicitWidth + 16
                        Layout.preferredHeight: 22
                        radius: height / 2
                        color: Theme.neutralHover

                        AppText {
                            id: partOfSpeechLabel
                            anchors.centerIn: parent
                            text: card.partOfSpeech
                            color: Theme.mutedForeground
                            font.pixelSize: 12
                        }
                    }

                    Menu {
                        id: actionsMenu
                        parent: card
                        implicitWidth: 144
                        padding: 4
                        x: card.width - width - fields.anchors.margins
                        y: fields.y + actionsButton.y + actionsButton.height

                        background: Rectangle {
                            color: Theme.card
                            radius: Theme.radiusSmall
                            border.width: 1
                            border.color: Theme.border
                        }

                        MenuItem {
                            id: editAction
                            text: "Edit"
                            implicitHeight: 32
                            padding: 0
                            leftPadding: 10
                            rightPadding: 10

                            contentItem: RowLayout {
                                spacing: 8

                                Icon {
                                    name: "pencil"
                                    size: 16
                                    color: Theme.foreground
                                }

                                AppText {
                                    text: editAction.text
                                    Layout.fillWidth: true
                                }
                            }

                            background: Rectangle {
                                radius: 6
                                color: editAction.hovered ? Theme.neutralHover : "transparent"
                            }

                            onTriggered: editor.openEntry(card.modelData)
                        }

                        MenuItem {
                            id: removeAction
                            text: "Remove"
                            implicitHeight: 32
                            padding: 0
                            leftPadding: 10
                            rightPadding: 10

                            contentItem: RowLayout {
                                spacing: 8

                                Icon {
                                    name: "trash"
                                    size: 16
                                    color: Theme.destructive
                                }

                                AppText {
                                    text: removeAction.text
                                    color: Theme.destructive
                                    Layout.fillWidth: true
                                }
                            }

                            background: Rectangle {
                                radius: 6
                                color: removeAction.hovered ? Qt.alpha(Theme.destructive, 0.1) : "transparent"
                            }

                            onTriggered: {
                                root.selectedEntry = card.modelData;
                                confirmRemoval.open();
                            }
                        }
                    }
                }
            }
        }

        AppText {
            Layout.fillWidth: true
            visible: entries.count === 0
            text: search.text.trim() ? "No matching words" : "Save a word from Reader or a subtitle to see it here."
            color: Theme.mutedForeground
            wrapMode: Text.Wrap
        }

        Item {
            visible: entries.count === 0
            Layout.fillHeight: true
        }
    }
}
