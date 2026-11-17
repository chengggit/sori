import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sori_qt_playback
import "../style"

Rectangle {
    id: root

    required property real documentId
    readonly property bool opened: selectedWord !== ""
    property bool editing: false
    readonly property var dictionaryProvider: DictionaryTabs.enabled[tabs.currentIndex - 1]
    readonly property bool showingAnalysis: !dictionaryProvider
    property string selectedWord: ""
    property var result: null
    property int request: 0
    property int selection: 0
    property int candidateIndex: 0
    property var queuedTerms: []
    property var inFlight: ({})
    property var lookups: ({})
    property var chosenDefinition: null
    property var savedWord: null
    readonly property string wholeTerm: result?.lookupTerms?.[candidateIndex] ?? ""
    readonly property var wholeLookup: lookups["#" + wholeTerm]
    readonly property var sources: {
        const entries = {}
        for (const lookup of Object.values(lookups)) {
            for (const definition of lookup.definitions ?? []) {
                if (definition.sourceUrl.startsWith("https://en.wiktionary.org/wiki/"))
                    entries[definition.sourceUrl] = definition.term
            }
        }
        const saved = savedWord?.definition
        if (saved?.sourceUrl.startsWith("https://en.wiktionary.org/wiki/"))
            entries[saved.sourceUrl] = saved.term
        return Object.keys(entries).map(url => ({ url, term: entries[url] }))
    }
    signal dismissRequested()

    color: Theme.card

    function lookup(text, start, end) {
        reset()
        selectedWord = text.slice(start, end)
        request = Analysis.analyze(text, start, end)
        body.contentItem.contentY = 0
    }

    function close() {
        reset()
        selectedWord = ""
        tabs.currentIndex = 0
    }

    function reset() {
        request = 0
        selection++
        result = null
        savedWord = null
        chosenDefinition = null
        lookups = ({})
        queuedTerms = []
        candidateIndex = 0
        sourceToggle.checked = false
        editing = false
    }

    function queueTerm(term) {
        if (!term || lookups["#" + term] || queuedTerms.includes(term)
                || Object.values(inFlight).some(job => job.term === term && job.selection === selection))
            return
        queuedTerms.push(term)
    }

    function startLookups() {
        // Keep the queue bounded when the reader selects several words or clicks rapidly.
        while (queuedTerms.length && Object.keys(inFlight).length < 4) {
            const term = queuedTerms.shift()
            inFlight[Analysis.lookupDictionary(term)] = { term, selection: selection }
        }
    }

    function advanceWholeLookup() {
        while (wholeTerm && lookups["#" + wholeTerm]?.definitions?.length === 0)
            candidateIndex++
        queueTerm(wholeTerm)
    }

    function retryWholeLookup() {
        const updated = Object.assign({}, lookups)
        delete updated["#" + wholeTerm]
        lookups = updated
        queueTerm(wholeTerm)
        startLookups()
    }

    function refreshSavedWord() {
        if (result?.word)
            savedWord = Library.findWord("document", documentId, result.word, result.context)
    }

    function openSaveEditor() {
        if (savedWord?.id) {
            editor.openEntry(savedWord)
        } else {
            const definition = chosenDefinition ?? wholeLookup?.definitions?.[0]
            editor.openDraft(documentId, result, definition)
        }
        editing = true
        editorScroll.contentItem.contentY = 0
        editor.focusWord()
    }

    function closeSaveEditor() {
        editing = false
        saveButton.forceActiveFocus(Qt.TabFocusReason)
    }

    Connections {
        target: Analysis

        function onFinished(request, result) {
            if (request !== root.request)
                return
            root.request = 0
            root.result = result
            if (result.error)
                return
            root.refreshSavedWord()
            root.queueTerm(root.wholeTerm)
            if (result.parts.length > 1) {
                for (const part of result.parts) {
                    if (!part.explanation)
                        root.queueTerm(part.term)
                }
            }
            root.startLookups()
        }

        function onDictionaryFinished(request, result) {
            const job = root.inFlight[request]
            if (!job)
                return
            delete root.inFlight[request]
            if (job.selection === root.selection) {
                const updated = Object.assign({}, root.lookups)
                updated["#" + job.term] = result
                root.lookups = updated
                root.advanceWholeLookup()
            }
            root.startLookups()
        }
    }

    Rectangle {
        width: 1
        height: parent.height
        color: Theme.border
        z: 1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            color: Theme.sidebar

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.border
            }

            TabBar {
                id: tabs
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: closeAnalysisButton.left
                anchors.bottom: parent.bottom
                height: 38
                padding: 0
                spacing: 4
                background: null
                readonly property int tabCount: DictionaryTabs.enabled.length + 1
                readonly property real tabWidth: Math.max(92, (root.width - 16 - Theme.iconButtonSize
                    - spacing * (tabCount - 1)) / tabCount)

                Repeater {
                    model: [{ label: "Analysis" }].concat(DictionaryTabs.enabled)

                    delegate: TabButton {
                        id: tab
                        required property var modelData
                        text: modelData.label
                        width: tabs.tabWidth
                        implicitHeight: tabs.height
                        padding: 6
                        hoverEnabled: true

                        background: Rectangle {
                            topLeftRadius: Theme.radius
                            topRightRadius: Theme.radius
                            color: tab.checked ? Theme.card : tab.hovered ? Theme.neutralHover : "transparent"
                            border.color: tab.visualFocus ? Theme.accent : Theme.border
                            border.width: tab.checked || tab.visualFocus ? 1 : 0

                            Rectangle {
                                visible: tab.checked
                                anchors.bottom: parent.bottom
                                x: 1
                                width: parent.width - 2
                                height: 1
                                color: Theme.card
                            }
                        }

                        contentItem: AppText {
                            text: tab.text
                            color: tab.checked ? Theme.foreground : Theme.mutedForeground
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            AppButton {
                id: closeAnalysisButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 4
                iconName: "x"
                iconSize: 16
                variant: "ghost"
                small: true
                Accessible.name: "Close word analysis"
                onClicked: root.dismissRequested()
            }
        }

        Row {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: 12
            spacing: 6
            AppText {
                text: root.selectedWord
                korean: true
                font.pixelSize: 20
                font.weight: Font.DemiBold
                width: Math.max(0, Math.min(implicitWidth, root.width - 46 - saveButton.implicitWidth))
                anchors.verticalCenter: parent.verticalCenter
                wrapMode: Text.Wrap
            }

            AppButton {
                id: saveButton
                enabled: !!root.result?.word && root.documentId > 0
                iconName: root.savedWord?.id ? "bookmark-filled" : "bookmark"
                iconSize: 20
                anchors.verticalCenter: parent.verticalCenter
                variant: "ghost"
                small: true
                Accessible.name: root.savedWord?.id ? "View saved word" : "Save word"
                onClicked: root.openSaveEditor()
            }
        }

        Repeater {
            model: root.opened ? DictionaryTabs.enabled : []

            delegate: DictionaryLookupView {
                id: dictionaryPage

                required property var modelData
                readonly property bool current: root.dictionaryProvider?.template === modelData.template
                property string lookupWord: ""

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: current
                keepLoaded: true
                lookupUrl: lookupWord
                    ? Analysis.dictionaryLookupUrl(modelData.template, encodeURIComponent(lookupWord)) : ""

                function updateLookup() {
                    if (current)
                        lookupWord = root.selectedWord.trim()
                }

                Component.onCompleted: updateLookup()
                onCurrentChanged: updateLookup()

                Connections {
                    target: root
                    function onSelectedWordChanged() { dictionaryPage.updateLookup() }
                }
            }
        }

        AppScrollView {
            id: body
            visible: root.showingAnalysis
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            Accessible.name: "Word analysis"

            ColumnLayout {
                width: body.availableWidth
                spacing: 0

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.margins: 20
                    spacing: 12

                    AppText {
                        visible: root.request !== 0 || !!root.result?.error
                        text: root.result?.error || "Analyzing…"
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: root.result?.error ? Theme.destructive : Theme.mutedForeground
                    }

                    ColumnLayout {
                        visible: !!root.result?.word
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        spacing: 8

                        AppText {
                            visible: !!root.savedWord?.definition?.text
                            text: "Saved meaning"
                            color: Theme.mutedForeground
                            font.pixelSize: 12
                        }

                        ReaderDefinitions {
                            visible: definitions.length > 0
                            Layout.fillWidth: true
                            definitions: root.savedWord?.definition?.text ? [root.savedWord.definition] : []
                            selected: root.chosenDefinition
                            onChosen: definition => root.chosenDefinition = definition
                        }

                        AppText {
                            text: "Dictionary lookup"
                            color: Theme.mutedForeground
                            font.pixelSize: 12
                        }

                        AppText {
                            visible: !root.wholeLookup?.definitions?.length
                            text: root.wholeLookup?.error || (root.wholeTerm
                                  ? "Looking up meaning…" : "No Korean definitions found.")
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            color: Theme.mutedForeground
                        }

                        AppButton {
                            visible: !!root.wholeLookup?.error
                            text: "Retry lookup"
                            variant: "outline"
                            small: true
                            onClicked: root.retryWholeLookup()
                        }

                        ReaderDefinitions {
                            visible: definitions.length > 0
                            Layout.fillWidth: true
                            definitions: root.wholeLookup?.definitions ?? []
                            textSize: 16
                            selected: root.chosenDefinition
                            onChosen: definition => root.chosenDefinition = definition
                        }

                        AppText {
                            visible: !!root.wholeLookup?.definitions?.length && root.wholeTerm !== root.selectedWord
                            text: qsTr("Dictionary form · %1").arg(root.wholeTerm)
                            color: Theme.mutedForeground
                            font.pixelSize: 12
                        }
                    }

                    Rectangle {
                        visible: !!root.result?.word
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Theme.border
                    }

                    AppText {
                        visible: !!root.result?.parts && root.result.parts.length > 1
                        text: "Word breakdown"
                        font.weight: Font.Medium
                        Layout.topMargin: 8
                    }

                    Repeater {
                        model: (root.result?.parts?.length ?? 0) > 1 ? root.result.parts : []

                        delegate: ColumnLayout {
                            id: part
                            required property var modelData
                            required property int index
                            readonly property var lookup: root.lookups["#" + modelData.term]
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                visible: part.index > 0
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                Layout.bottomMargin: 8
                                color: Theme.border
                            }

                            RowLayout {
                                AppText { text: part.modelData.term; korean: true }
                                AppText {
                                    text: part.modelData.label
                                    font.pixelSize: 12
                                    color: Theme.mutedForeground
                                }
                            }

                            AppText {
                                visible: !!part.modelData.explanation || !part.lookup?.definitions?.length
                                text: part.modelData.explanation || part.lookup?.error
                                      || (part.lookup ? "No definition found." : "Looking up meaning…")
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                            }

                            ReaderDefinitions {
                                visible: definitions.length > 0
                                definitions: part.lookup?.definitions ?? []
                                Layout.fillWidth: true
                                selected: root.chosenDefinition
                                onChosen: definition => root.chosenDefinition = definition
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: root.showingAnalysis && !root.editing && root.sources.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        Button {
            id: sourceToggle
            visible: root.showingAnalysis && !root.editing && root.sources.length > 0
            checkable: true
            flat: true
            text: checked ? "▾ Sources" : "▸ Sources"
            Accessible.name: "Sources"
            Layout.fillWidth: true
            leftPadding: 20
            topPadding: 10
            bottomPadding: 8
            background: Rectangle {
                color: "transparent"
                border.width: sourceToggle.visualFocus ? 1 : 0
                border.color: Theme.accent
            }
            contentItem: AppText {
                text: sourceToggle.text
                color: Theme.mutedForeground
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
            }
        }

        AppScrollView {
            id: sourceDetails
            visible: sourceToggle.visible && sourceToggle.checked
            clip: true
            leftPadding: 20
            rightPadding: 20
            bottomPadding: 12
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(root.height * 0.24, sourceLinks.implicitHeight + bottomPadding)
            contentWidth: availableWidth

            ColumnLayout {
                id: sourceLinks
                width: sourceDetails.availableWidth
                spacing: 4

                AppText {
                    text: "Definitions by Wiktionary contributors. Formatting removed."
                    color: Theme.mutedForeground
                    Layout.fillWidth: true
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }

                SourceLink {
                    text: "CC BY-SA 4.0"
                    destination: "https://creativecommons.org/licenses/by-sa/4.0/"
                }

                Repeater {
                    model: root.sources
                    delegate: SourceLink {
                        required property var modelData
                        text: modelData.term
                        destination: modelData.url
                    }
                }
            }
        }
        Rectangle {
            visible: root.editing
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(root.height * 0.8, editorColumn.implicitHeight + 40)
            color: Theme.card
            radius: Theme.radius
            border.color: Theme.border

            AppScrollView {
                id: editorScroll
                anchors.fill: parent
                anchors.margins: 20
                contentWidth: availableWidth
                clip: true

                ColumnLayout {
                    id: editorColumn
                    width: editorScroll.availableWidth
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        AppText {
                            Layout.fillWidth: true
                            text: root.savedWord?.id ? "Saved word" : "Save word"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }
                        AppButton {
                            iconName: "x"
                            variant: "ghost"
                            small: true
                            Accessible.name: "Close save panel"
                            onClicked: root.closeSaveEditor()
                        }
                    }

                    VocabularyForm {
                        id: editor
                        Layout.fillWidth: true
                        panelMode: true
                        onChanged: root.refreshSavedWord()
                        onCloseRequested: root.closeSaveEditor()
                    }
                }
            }
        }
    }

    component SourceLink: Button {
        id: link
        required property url destination
        Accessible.role: Accessible.Link
        padding: 0

        background: Rectangle {
            color: "transparent"
            border.width: link.visualFocus ? 1 : 0
            border.color: Theme.accent
        }

        contentItem: AppText {
            text: link.text
            color: Theme.mutedForeground
            font.pixelSize: 12
            font.underline: true
        }

        onClicked: Qt.openUrlExternally(destination)
    }
}
