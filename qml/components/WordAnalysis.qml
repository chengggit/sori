import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sori_qt_playback
import "../Theme.js" as Theme

Popup {
    id: root

    property int request: 0
    property string selectedWord: ""
    property var result: null
    property string sourceKind: "document"
    property real sourceId: 0
    property var savedWord: null
    property string saveError: ""
    readonly property bool canSave: !!result?.word && sourceId > 0
    readonly property string normalizedForm: {
        const token = result?.morphemes?.[0]
        if (!token)
            return ""
        const form = /^(VV|VA)/.test(token.tag) ? token.form + "다" : token.form
        return form === result.word ? "" : form
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
        meaning.clear()
        saveError = ""
        request = Analysis.analyze(source, start, end)
        open()
    }

    onClosed: request = 0

    function saveWord() {
        const input = {
            word: result.word,
            normalizedForm: normalizedForm || null,
            context: result.context,
            tags: [],
            definition: meaning.text.trim() ? {
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

        ScrollView {
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
}
