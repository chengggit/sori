import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sori_core
import "../style"
import "../components"

Item {
    id: root

    property string error: ""
    property var selectedEntry: null
    property var detailEntry: null
    property bool detailsOpen: false
    property string typeFilter: "All types"
    property int sortIndex: 0

    readonly property string query: search.text.trim().toLowerCase()
    readonly property var typeOptions: {
        const types = {};
        for (const entry of Library.vocabulary) {
            const type = root.partOfSpeech(entry);
            if (type !== "")
                types[root.capitalize(type)] = true;
        }
        return ["All types", ...Object.keys(types).sort((a, b) => a.localeCompare(b))];
    }
    readonly property var sortOptions: ["Recent", "Oldest", "A–Z", "Z–A"]
    readonly property var matchingEntries: {
        const filtered = Library.vocabulary.filter(entry => {
            if (root.typeFilter !== "All types"
                    && root.partOfSpeech(entry) !== root.typeFilter.toLowerCase())
                return false;
            if (root.query === "")
                return true;
            return [entry.word, entry.normalizedForm, entry.definition?.text,
                entry.definition?.note, entry.context, entry.sourceTitle, ...(entry.tags ?? [])]
                .filter(value => !!value)
                .some(value => value.toLowerCase().includes(root.query));
        });
        const sorted = filtered.slice();
        const savedAt = entry => Number(entry.createdAt) || 0;
        if (root.sortIndex === 1)
            sorted.sort((a, b) => savedAt(a) - savedAt(b) || a.id - b.id);
        else if (root.sortIndex === 2)
            sorted.sort((a, b) => String(root.displayWord(a)).localeCompare(String(root.displayWord(b))));
        else if (root.sortIndex === 3)
            sorted.sort((a, b) => String(root.displayWord(b)).localeCompare(String(root.displayWord(a))));
        else
            sorted.sort((a, b) => savedAt(b) - savedAt(a) || b.id - a.id);
        return sorted;
    }
    readonly property string countLabel: {
        const total = Library.vocabulary.length;
        const shown = root.matchingEntries.length;
        if (root.query !== "" || root.typeFilter !== "All types")
            return shown + " of " + total + (total === 1 ? " saved word" : " saved words");
        return total + (total === 1 ? " saved word" : " saved words");
    }

    onTypeOptionsChanged: if (typeOptions.indexOf(typeFilter) < 0)
        typeFilter = "All types"
    onVisibleChanged: if (!visible)
        closeDetails()

    function partOfSpeech(entry) {
        const value = (entry.definition?.partOfSpeech ?? "").trim().toLowerCase();
        if (value !== "")
            return value;
        // Saved words without a dictionary entry often carry a part-of-speech
        // tag instead. Use it for the type label when it names a known class.
        const classes = ["noun", "verb", "adjective", "adverb", "pronoun",
            "determiner", "particle", "conjunction", "interjection", "numeral"];
        for (const tag of entry.tags ?? []) {
            const normalized = tag.trim().toLowerCase().replace(/s$/, "");
            if (classes.indexOf(normalized) >= 0)
                return normalized;
        }
        return "";
    }

    function capitalize(value) {
        return value === "" ? "" : value.charAt(0).toUpperCase() + value.slice(1);
    }

    function displayWord(entry) {
        const normalized = (entry.normalizedForm ?? "").trim();
        return normalized !== "" && normalized !== entry.word ? normalized : entry.word;
    }

    function formatMeaning(entry) {
        return (entry.definition?.text ?? "")
            .trim()
            .replace(/\s*\n+\s*/g, "; ")
            .replace(/[ \t]+/g, " ");
    }

    function clearFilters() {
        search.clear();
        typeFilter = "All types";
    }

    function openDetails(entry) {
        detailEntry = entry;
        detailsOpen = true;
    }

    function closeDetails() {
        detailsOpen = false;
    }

    component SelectCombo: ComboBox {
        id: combo

        property string leadingIcon: ""

        implicitWidth: 132
        implicitHeight: Theme.inputHeight
        padding: 0
        font.family: "Inter"
        font.pixelSize: 13
        hoverEnabled: true

        background: Rectangle {
            radius: Theme.radiusSmall
            color: combo.hovered || combo.popup.visible ? Theme.neutralHover : Theme.card
            border.width: 1
            border.color: combo.activeFocus ? Theme.accent : Theme.border

            Behavior on color {
                ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }

        contentItem: Item {
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 30
                spacing: 6

                Icon {
                    visible: combo.leadingIcon !== ""
                    name: combo.leadingIcon
                    size: 14
                    color: Theme.mutedForeground
                }

                AppText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: combo.displayText
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }
        }

        indicator: Icon {
            x: combo.width - width - 12
            y: (combo.height - height) / 2
            name: "chevron-down"
            size: 12
            color: Theme.mutedForeground
        }

        delegate: ItemDelegate {
            id: option
            required property var modelData
            required property int index

            width: combo.width - combo.popup.padding * 2
            height: 32
            highlighted: combo.highlightedIndex === index

            contentItem: RowLayout {
                spacing: 8

                AppText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: option.modelData
                    font.pixelSize: 13
                    font.weight: combo.currentIndex === option.index ? Font.Medium : Font.Normal
                    elide: Text.ElideRight
                }

                Icon {
                    visible: combo.currentIndex === option.index
                    name: "check"
                    size: 14
                    color: Theme.foreground
                }
            }

            background: Rectangle {
                radius: 6
                color: option.highlighted || option.hovered ? Theme.neutralHover : "transparent"
            }
        }

        popup: Popup {
            y: combo.height + 4
            width: combo.width
            padding: 4

            background: Rectangle {
                radius: Theme.radiusSmall
                color: Theme.card
                border.width: 1
                border.color: Theme.border
            }

            contentItem: ListView {
                clip: true
                implicitHeight: Math.min(contentHeight, 256)
                model: combo.popup.visible ? combo.delegateModel : null
                currentIndex: combo.highlightedIndex

                ScrollBar.vertical: AppScrollBar {}
            }
        }
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
            border.width: 0
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

    Connections {
        target: Library

        function onVocabularyChanged() {
            if (!root.detailEntry)
                return;
            const updated = Library.vocabulary.find(item => item.id === root.detailEntry.id);
            if (updated)
                root.detailEntry = updated;
            else
                root.closeDetails();
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.detailsOpen && !editor.visible && !confirmRemoval.visible
        onActivated: root.closeDetails()
    }

    PageFrame {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: 14

        AppText {
            Layout.fillWidth: true
            text: root.countLabel
            color: Theme.mutedForeground
            font.pixelSize: 13
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.controlGap

            AppInput {
                id: search
                Layout.fillWidth: true
                Layout.minimumWidth: 200
                placeholderText: "Search vocabulary…"
                iconName: "search"
            }

            SelectCombo {
                id: typeCombo
                Layout.preferredWidth: 132
                model: root.typeOptions
                Accessible.name: "Filter saved words by type"
                onActivated: root.typeFilter = root.typeOptions[currentIndex]

                Binding {
                    target: typeCombo
                    property: "currentIndex"
                    value: Math.max(0, root.typeOptions.indexOf(root.typeFilter))
                }
            }

            SelectCombo {
                id: sortCombo
                Layout.preferredWidth: 132
                leadingIcon: "arrow-up-down"
                model: root.sortOptions
                Accessible.name: "Sort saved words"
                onActivated: root.sortIndex = currentIndex

                Binding {
                    target: sortCombo
                    property: "currentIndex"
                    value: root.sortIndex
                }
            }
        }

        AppText {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.error || Library.error
            color: Theme.destructive
            wrapMode: Text.Wrap
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.matchingEntries.length > 0

            ListView {
                id: entries
                anchors.fill: parent
                model: root.matchingEntries
                spacing: 8
                clip: true
                ScrollBar.vertical: AppScrollBar {}

                delegate: ItemDelegate {
                    id: card
                    required property var modelData
                    required property int index

                    readonly property string partOfSpeech: root.partOfSpeech(card.modelData)
                    readonly property string hanja: card.modelData.definition?.hanja ?? ""
                    readonly property string note: card.modelData.definition?.note ?? ""
                    readonly property string meaning: root.formatMeaning(card.modelData)

                    width: ListView.view.width
                    height: content.implicitHeight + 32
                    padding: 0
                    leftPadding: 20
                    rightPadding: 16
                    topPadding: 16
                    bottomPadding: 16
                    hoverEnabled: true
                    Accessible.name: "Open details for " + root.displayWord(card.modelData)
                    onClicked: root.openDetails(card.modelData)

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }

                    background: Rectangle {
                        radius: Theme.radius
                        color: card.hovered || card.visualFocus
                            ? Theme.neutralHover : Theme.card
                        border.width: card.visualFocus ? 1 : 0
                        border.color: Theme.accent

                        Behavior on color {
                            ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                    }

                    contentItem: RowLayout {
                        id: content
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                AppText {
                                    Layout.maximumWidth: Math.max(120, content.width * 0.5)
                                    text: root.displayWord(card.modelData)
                                    korean: true
                                    font.pixelSize: 17
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                AppText {
                                    visible: text !== ""
                                    Layout.maximumWidth: content.width * 0.25
                                    text: card.hanja
                                    color: Theme.mutedForeground
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    visible: card.partOfSpeech !== ""
                                    implicitWidth: partOfSpeechLabel.implicitWidth + 14
                                    implicitHeight: 22
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

                                Item {
                                    Layout.fillWidth: true
                                }
                            }

                            AppText {
                                visible: card.meaning !== ""
                                Layout.fillWidth: true
                                text: card.meaning
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                lineHeightMode: Text.ProportionalHeight
                            }

                            AppText {
                                visible: card.meaning === "" && text !== ""
                                Layout.fillWidth: true
                                text: card.modelData.context
                                color: Theme.mutedForeground
                                font.pixelSize: 13
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            AppText {
                                visible: text !== ""
                                Layout.fillWidth: true
                                text: card.note
                                color: Theme.mutedForeground
                                font.pixelSize: 12
                                wrapMode: Text.Wrap
                                maximumLineCount: 1
                                elide: Text.ElideRight
                            }
                        }

                        AppButton {
                            id: actionsButton
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            iconName: "ellipsis-vertical"
                            iconSize: 14
                            variant: "ghost"
                            Accessible.name: "More actions for " + root.displayWord(card.modelData)
                            onClicked: actionsMenu.open()
                        }
                    }

                    Menu {
                        id: actionsMenu
                        parent: card
                        implicitWidth: 144
                        padding: 4
                        x: Math.round(card.width - width - 16)
                        y: 48

                        background: Rectangle {
                            color: Theme.card
                            radius: Theme.radiusSmall
                            border.width: 0
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

        EmptyState {
            Layout.fillWidth: true
            Layout.preferredHeight: 288
            Layout.alignment: Qt.AlignTop
            visible: Library.vocabulary.length === 0
            iconName: "bookmark"
            title: "No saved words yet"
            message: "Save a word from Reader or a video to see it here."
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 48
            visible: Library.vocabulary.length > 0 && root.matchingEntries.length === 0
            spacing: 12

            AppText {
                Layout.fillWidth: true
                text: "No words match your search and filters."
                color: Theme.mutedForeground
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            AppButton {
                Layout.alignment: Qt.AlignHCenter
                text: "Clear filters"
                variant: "outline"
                small: true
                onClicked: root.clearFilters()
            }
        }
    }

    VocabularyDetails {
        id: detailsPanel
        objectName: "vocabularyDetailsSidebar"
        z: 1

        property real revealProgress: root.detailsOpen ? 1 : 0

        width: Math.min(Theme.readerAnalysisWidth, root.width * 0.45)
        height: parent.height
        x: root.width - revealProgress * width
        visible: revealProgress > 0
        entry: root.detailEntry
        onCloseRequested: root.closeDetails()

        Behavior on revealProgress {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }
    }
}
