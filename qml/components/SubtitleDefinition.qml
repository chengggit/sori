import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sori_core
import "../style"

Popup {
    id: root

    required property real videoId
    required property real maximumHeight
    property string word: ""
    property var analysis: null
    property var savedDefinition: null
    property var savedEntry: null
    property string saveError: ""
    property int analysisRequest: 0
    property int selection: 0
    property var pending: ({})
    property var lookups: ({})
    property bool expanded: false
    property string sourceText: ""
    property int sourceStart: 0
    property int sourceEnd: 0
    signal sidebarRequested(string text, int start, int end)
    readonly property var wholeDefinitions: {
        if (savedDefinition)
            return [savedDefinition]
        for (const term of analysis?.lookupTerms ?? []) {
            const lookup = lookups[term]
            if (!lookup)
                break
            if (lookup.definitions?.length)
                return lookup.definitions
        }
        return []
    }
    readonly property bool lookingUp: !wholeDefinitions.length
        && (analysis?.lookupTerms ?? []).some(term => !lookups[term])

    width: 352
    height: Math.min(maximumHeight, heading.implicitHeight + body.implicitHeight
        + sidebarButton.implicitHeight + 2 * padding + 16)
    padding: 16
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    function lookup(source, start, end) {
        sourceText = source
        sourceStart = start
        sourceEnd = end
        selection++
        word = source.slice(start, end)
        analysis = null
        savedDefinition = null
        savedEntry = null
        saveError = ""
        lookups = ({})
        expanded = false
        scroll.contentItem.contentY = 0
        analysisRequest = Analysis.analyze(source, start, end)
        open()
    }

    function saveWord() {
        if (savedEntry?.id) {
            saveError = Library.removeWord(savedEntry.id)
            if (!saveError) {
                savedEntry = null
                savedDefinition = null
                startLookups()
            }
            return
        }
        const definition = wholeDefinitions[0] ?? null
        const saved = Library.saveWord("local", videoId, {
            word: analysis.word,
            context: analysis.context,
            normalizedForm: definition?.term || analysis.normalizedForm || null,
            definition: definition,
            tags: []
        })
        saveError = saved.error || ""
        if (!saveError) {
            savedEntry = saved
            savedDefinition = saved.definition ?? definition
        }
    }

    function lookupTerm(term) {
        if (term && !lookups[term] && Object.keys(pending).length < 4
                && !Object.values(pending).some(job => job.term === term && job.selection === selection))
            pending[Analysis.lookupDictionary(term)] = { term, selection }
    }

    function startLookups() {
        if (!visible || !analysis || analysis.error)
            return

        if (!wholeDefinitions.length)
            lookupTerm(analysis.lookupTerms.find(term => !lookups[term]))

        if (analysis.parts.length > 1) {
            for (const part of analysis.parts) {
                if (!part.explanation && part.term !== savedDefinition?.term)
                    lookupTerm(part.term)
            }
        }
    }

    onAboutToHide: {
        selection++
        analysisRequest = 0
    }

    Connections {
        target: Analysis

        function onFinished(request, result) {
            if (request !== root.analysisRequest)
                return
            root.analysisRequest = 0
            root.analysis = result
            if (result.word && root.videoId > 0) {
                root.savedEntry = Library.findWord("local", root.videoId, result.word, result.context)
                root.savedDefinition = root.savedEntry?.definition ?? null
            }
            root.startLookups()
        }

        function onDictionaryFinished(request, result) {
            const job = root.pending[request]
            if (!job)
                return
            delete root.pending[request]
            if (job.selection === root.selection)
                root.lookups = Object.assign({}, root.lookups, { [job.term]: result })
            root.startLookups()
        }
    }

    background: Rectangle {
        color: Theme.card
        radius: Theme.radius
        border.color: Theme.border
    }

    contentItem: ColumnLayout {
        spacing: 8

        RowLayout {
            id: heading
            Layout.fillWidth: true

            AppText {
                text: root.word
                korean: true
                font.pixelSize: 16
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            AppButton {
                id: bookmarkButton
                objectName: "saveSubtitleWord"
                iconName: root.savedEntry?.id ? "bookmark-filled" : "bookmark"
                variant: "ghost"
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                enabled: !!root.analysis?.word && root.videoId > 0
                Accessible.name: root.savedEntry?.id ? "Unsave word" : "Save word"
                onClicked: root.saveWord()

                ToolTip {
                    id: bookmarkTooltip
                    visible: bookmarkButton.hovered && bookmarkButton.enabled
                    delay: 450
                    text: bookmarkButton.Accessible.name
                    x: (bookmarkButton.width - width) / 2
                    y: -height - 6
                    padding: 8
                    contentItem: AppText {
                        text: bookmarkTooltip.text
                        font.pixelSize: 12
                    }
                    background: Rectangle {
                        color: Theme.card
                        border.color: Theme.border
                        radius: Theme.radiusSmall
                    }
                }
            }

            AppButton {
                iconName: "x"
                iconSize: 12
                variant: "ghost"
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                Accessible.name: "Close definition"
                onClicked: root.close()
            }
        }

        AppScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            contentHeight: body.implicitHeight
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            clip: true

            ColumnLayout {
                id: body
                width: scroll.availableWidth
                spacing: 8

                AppText {
                    visible: root.saveError !== ""
                    text: root.saveError
                    color: Theme.destructive
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }

                AppText {
                    visible: !root.wholeDefinitions.length
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: root.analysis?.error || (!root.analysis ? "Analyzing Korean text…"
                        : root.lookingUp ? "Looking up…"
                        : Object.values(root.lookups).some(lookup => lookup.error)
                            ? "Dictionary lookup unavailable." : "No definition found.")
                    color: Theme.mutedForeground
                }

                Repeater {
                    model: root.expanded ? root.wholeDefinitions : root.wholeDefinitions.slice(0, 1)

                    AppText {
                        required property var modelData
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: modelData.text
                    }
                }

                Button {
                    id: more
                    visible: root.wholeDefinitions.length > 1
                    padding: 0
                    text: root.expanded ? "Show fewer definitions" : "Show more definitions"
                    background: Rectangle {
                        color: "transparent"
                        border.width: more.visualFocus ? 1 : 0
                        border.color: Theme.accent
                    }
                    contentItem: AppText {
                        text: more.text
                        font.pixelSize: 12
                        font.underline: true
                        color: Theme.mutedForeground
                    }
                    onClicked: root.expanded = !root.expanded
                }

                Rectangle {
                    visible: (root.analysis?.parts?.length ?? 0) > 1
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 6
                    Layout.bottomMargin: 4
                    color: Theme.border
                }

                AppText {
                    visible: (root.analysis?.parts?.length ?? 0) > 1
                    text: "Word breakdown"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.mutedForeground
                }

                Repeater {
                    model: root.analysis?.parts?.length > 1 ? root.analysis.parts : []

                    AppText {
                        required property var modelData
                        readonly property var lookup: root.lookups[modelData.term]
                        readonly property string meaning: root.savedDefinition?.term === modelData.term
                            ? root.savedDefinition.text : lookup?.definitions?.[0]?.text ?? ""
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        font.pixelSize: 12
                        lineHeight: 1.3
                        color: Theme.mutedForeground
                        text: modelData.term + " · " + (modelData.explanation || meaning
                            || (lookup ? "No definition found." : "Looking up…"))
                    }
                }
            }
        }

        AppButton {
            id: sidebarButton
            objectName: "openDefinitionSidebar"
            text: "Open in sidebar"
            variant: "outline"
            small: true
            Layout.fillWidth: true
            onClicked: root.sidebarRequested(root.sourceText, root.sourceStart, root.sourceEnd)
        }
    }
}
