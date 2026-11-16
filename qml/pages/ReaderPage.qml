import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sori_qt_playback
import "../style"
import "../components"

Item {
    id: root

    required property bool active
    property real documentId: 0
    property string documentTitle: "Reader"
    property string documentError: ""
    property string progressError: ""
    property real restorePosition: 0
    property bool restoring: false
    property bool progressPending: false
    readonly property real scrollRange: Math.max(0, viewport.contentHeight - viewport.height)

    function openDocument(id, title) {
        leave()
        const document = Library.readDocument(id)
        restoring = true
        documentId = id
        documentTitle = title
        documentError = document.error || ""
        progressError = ""
        restorePosition = document.position ?? 0
        passage.text = document.content ?? ""
        Qt.callLater(restoreProgress)
    }

    function leave() {
        flushProgress()
        analysis.close()
    }

    function analyzeSelection() {
        if (passage.selectedText.trim())
            analysis.lookup(passage.text, passage.selectionStart, passage.selectionEnd)
    }

    function restoreProgress() {
        if (!root.active || !root.restoring)
            return
        viewport.contentY = root.restorePosition * root.scrollRange
        root.restoring = false
    }

    function flushProgress() {
        if (!progressPending)
            return
        progressPending = false
        saveProgress.stop()
        if (root.documentId && !root.restoring)
            root.progressError = Library.saveReadingProgress(root.documentId,
                root.scrollRange ? Math.max(0, Math.min(1, viewport.contentY / root.scrollRange)) : 0)
    }

    onActiveChanged: if (active) Qt.callLater(restoreProgress)

    WordAnalysis {
        id: analysis
        parent: Overlay.overlay
        sourceId: root.documentId
        x: parent.width - width - 20
        y: 76
    }

    Timer {
        id: saveProgress
        interval: 500
        onTriggered: root.flushProgress()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 10

        AppText {
            Layout.fillWidth: true
            visible: text !== ""
            color: Theme.destructive
            text: root.documentError || root.progressError
            wrapMode: Text.Wrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.card
            border.color: Theme.border
            radius: Theme.radiusLarge

            Flickable {
                id: viewport
                anchors.fill: parent
                anchors.margins: 2
                clip: true
                contentWidth: width
                contentHeight: passage.implicitHeight + 64
                boundsBehavior: Flickable.StopAtBounds
                onContentYChanged: {
                    if (root.active && root.documentId && !root.restoring
                            && !root.documentError && !root.progressPending) {
                        root.progressPending = true
                        saveProgress.start()
                    }
                }
                ScrollBar.vertical: ScrollBar {}

                TextArea {
                    id: passage
                    objectName: "readerText"
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 32
                    width: Math.min(viewport.width - 64, 760)
                    padding: 0
                    readOnly: true
                    renderType: Theme.nativeText ? TextEdit.NativeRendering : TextEdit.QtRendering
                    selectByMouse: true
                    textFormat: TextEdit.PlainText
                    wrapMode: TextEdit.Wrap
                    color: Theme.foreground
                    font.family: "Noto Sans KR"
                    font.pixelSize: 19
                    background: null
                    Accessible.name: "Document text"

                    Keys.onReturnPressed: root.analyzeSelection()
                    TapHandler {
                        onSingleTapped: (eventPoint, button) => {
                            if (button === Qt.LeftButton) {
                                passage.cursorPosition = passage.positionAt(eventPoint.position.x, eventPoint.position.y)
                                passage.selectWord()
                                root.analyzeSelection()
                            }
                        }
                    }
                }
            }
        }
    }
}
