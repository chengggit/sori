import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sori_qt_playback
import "../style"

Popup {
    id: root

    property int request: 0
    property string selectedWord: ""
    property var result: null
    property string sourceKind: "document"
    property real sourceId: 0
    property var savedWord: null
    property string saveError: ""
    property int dictionaryRequest: 0
    property string dictionaryError: ""
    property var definitions: []
    readonly property string lookupTerm: normalizedForm || result?.word || ""
    readonly property bool canSave: !!result?.word && sourceId > 0
    readonly property string normalizedForm: {
        const form = result?.normalizedForm || ""
        return form === result?.word ? "" : form
    }

    width: Math.min(340, parent.width - 40)
    height: Math.min(contentItem.implicitHeight + 32, parent.height - y - 20)
    padding: 16
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape

    function lookup(source, start, end) {
        selectedWord = source.slice(start, end)
        result = null
        savedWord = null
        dictionaryRequest = 0
        dictionaryError = ""
        definitions = []
        meaning.clear()
        saveError = ""
        request = Analysis.analyze(source, start, end)
        open()
    }

    onClosed: {
        dictionaries.close()
        request = 0
        dictionaryRequest = 0
    }

    function lookupDictionary() {
        dictionaryError = ""
        dictionaryRequest = Analysis.lookupDictionary(lookupTerm)
    }

    function saveWord() {
        const chosen = definitions[definitionPicker.currentIndex]
        const imported = chosen && meaning.text.trim() === chosen.text
        const input = {
            word: result.word,
            normalizedForm: normalizedForm || null,
            context: result.context,
            tags: [],
            definition: imported ? chosen : meaning.text.trim() ? {
                term: normalizedForm || result.word,
                text: meaning.text.trim(),
                partOfSpeech: "",
                sourceUrl: "",
                custom: true
            } : null
        }
        const saved = Library.saveWord(sourceKind, sourceId, input)
        saveError = saved.error || ""
        if (!saveError)
            savedWord = saved
    }

    Connections {
        target: Analysis
        function onFinished(request, result) {
            if (request === root.request) {
                root.result = result
                if (root.canSave)
                    root.savedWord = Library.findWord(root.sourceKind, root.sourceId, result.word, result.context)
            }
        }
        function onDictionaryFinished(request, result) {
            if (request !== root.dictionaryRequest)
                return
            root.dictionaryRequest = 0
            root.definitions = result.definitions ?? []
            root.dictionaryError = result.error || (root.definitions.length ? "" : "No Korean definitions found.")
            if (root.definitions.length) {
                definitionPicker.currentIndex = 0
                if (!meaning.text.trim())
                    meaning.text = root.definitions[0].text
            }
        }
    }

    background: Rectangle {
        color: Theme.card
        border.color: Theme.border
        radius: Theme.radius
    }

    contentItem: ColumnLayout {
        spacing: 10
        RowLayout {
            Layout.fillWidth: true

            AppText {
                Layout.fillWidth: true
                text: root.selectedWord
                korean: true
                font.pixelSize: 24
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            AppButton {
                text: "Close"
                variant: "ghost"
                small: true
                onClicked: root.close()
            }
        }

        AppScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            implicitHeight: analysisContent.implicitHeight
            clip: true

            ColumnLayout {
                id: analysisContent
                width: parent.width
                spacing: 8

                AppText {
                    Layout.fillWidth: true
                    text: root.result ? (root.result.error || root.result.context) : "Analyzing Korean text…"
                    visible: text !== ""
                    color: root.result?.error ? Theme.destructive : Theme.mutedForeground
                    korean: !!root.result && !root.result.error
                    wrapMode: Text.Wrap
                }

                AppButton {
                    readonly property string entryUrl: (root.savedWord?.definition ?? root.definitions[definitionPicker.currentIndex])?.sourceUrl || ""
                    visible: entryUrl.startsWith("https://en.wiktionary.org/wiki/")
                    text: "Open full entry"
                    variant: "ghost"
                    small: true
                    onClicked: Qt.openUrlExternally(entryUrl)
                }

                RowLayout {
                    visible: root.lookupTerm !== "" && !root.savedWord?.id
                    Layout.fillWidth: true
                    AppButton {
                        text: root.dictionaryRequest ? "Looking up…" : "Look up on Wiktionary"
                        enabled: root.dictionaryRequest === 0
                        variant: "outline"
                        small: true
                        onClicked: root.lookupDictionary()
                    }
                    AppButton {
                        visible: DictionaryTabs.enabled.length > 0
                        text: "Dictionaries"
                        variant: "ghost"
                        small: true
                        onClicked: {
                            dictionaries.term = root.lookupTerm
                            dictionaries.open()
                        }
                    }
                }

                AppText {
                    visible: text !== "" && !root.savedWord?.id
                    text: root.dictionaryError
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: Theme.mutedForeground
                }

                ComboBox {
                    id: definitionPicker
                    visible: root.definitions.length > 0 && !root.savedWord?.id
                    Layout.fillWidth: true
                    model: root.definitions
                    textRole: "text"
                    Accessible.name: "Dictionary meaning"
                    onActivated: meaning.text = root.definitions[index].text
                }

                AppText {
                    readonly property var definition: root.definitions[definitionPicker.currentIndex]
                    visible: !!definition && !root.savedWord?.id
                    Layout.fillWidth: true
                    text: definition ? [definition.hanja, definition.partOfSpeech, definition.text].filter(s => !!s).join(" · ") : ""
                    wrapMode: Text.Wrap
                }

                Repeater {
                    model: root.result?.morphemes ?? []

                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true

                        AppText {
                            Layout.fillWidth: true
                            text: modelData.form
                            korean: true
                            elide: Text.ElideRight
                        }
                        AppText {
                            text: modelData.tag
                            color: Theme.mutedForeground
                            font.pixelSize: 12
                        }
                    }
                }

                AppInput {
                    id: meaning
                    visible: root.canSave && !root.savedWord?.id
                    Layout.fillWidth: true
                    placeholderText: "Meaning (optional)"
                }

                AppText {
                    visible: !!root.savedWord?.definition?.text
                    text: root.savedWord?.definition?.text || ""
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }

                AppButton {
                    visible: root.canSave
                    enabled: !root.savedWord?.id
                    text: root.savedWord?.id ? "Saved to Vocabulary" : "Save word"
                    iconName: "bookmark"
                    Layout.fillWidth: true
                    onClicked: root.saveWord()
                }

                AppText {
                    visible: text !== ""
                    text: root.saveError
                    Layout.fillWidth: true
                    color: Theme.destructive
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    DictionaryLookup {
        id: dictionaries
        parent: root.parent
    }

}
