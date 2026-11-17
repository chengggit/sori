import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sori_qt_playback
import "../style"

Popup {
    id: root

    required property real videoId
    required property real maximumHeight
    property string word: ""
    property var analysis: null
    property var savedDefinition: null
    property int analysisRequest: 0
    property int selection: 0
    property var pending: ({})
    property var lookups: ({})
    property bool expanded: false
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
    height: Math.min(maximumHeight, heading.implicitHeight + body.implicitHeight + 2 * padding + 8)
    padding: 16
    focus: true
    closePolicy: Popup.CloseOnEscape

    function lookup(source, start, end) {
        selection++
        word = source.slice(start, end)
        analysis = null
        savedDefinition = null
        lookups = ({})
        expanded = false
        scroll.contentItem.contentY = 0
        analysisRequest = Analysis.analyze(source, start, end)
        open()
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
            if (result.word && root.videoId > 0)
                root.savedDefinition = Library.findWord("local", root.videoId, result.word, result.context)?.definition
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
    }
}
