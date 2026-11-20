import QtQuick
import QtQuick.Controls
import QtQuick.Pdf
import "../style"

Item {
    id: root
    clip: true

    required property string pdfPath
    required property string pdfUrl
    required property var pdfText
    property real restorePosition: 0
    property real position: 0
    property int currentPage: 0
    readonly property int pageCount: document.pageCount
    property bool restoring: false
    property var pageCache: ({})

    readonly property int pageGap: 20
    readonly property real pageWidth: Math.max(0, Math.min(width - 2 * Theme.readerPadding, 920))

    signal wordRequested(string text, int start, int end)

    function pageAspect(index) {
        const size = document.pagePointSize(index)
        return size.width > 0 ? size.height / size.width : 1.4
    }

    function ensurePageData(index) {
        if (root.pageCache[index])
            return root.pageCache[index]
        const page = root.pdfText.page(index)
        const data = {
            text: page.text ?? "",
            words: page.words ?? []
        }
        root.pageCache[index] = data
        return data
    }

    function wordAt(index, x, y) {
        const data = ensurePageData(index)
        const size = document.pagePointSize(index)
        if (size.width <= 0)
            return null
        const scale = root.pageWidth / size.width
        const px = x / scale
        const py = y / scale
        for (const word of data.words) {
            if (px >= word.x && px <= word.x + word.width
                    && py >= word.y && py <= word.y + word.height)
                return { data: data, word: word }
        }
        return null
    }

    function updatePosition() {
        if (restoring || document.pageCount === 0)
            return
        const page = Math.max(0, Math.min(document.pageCount - 1,
            view.indexAt(0, view.contentY + 1)))
        currentPage = page
        position = document.pageCount > 1 ? page / (document.pageCount - 1) : 0
    }

    function restoreProgress() {
        if (document.status !== PdfDocument.Ready || document.pageCount === 0 || restoring)
            return
        restoring = true
        const page = Math.round(Math.max(0, Math.min(1, restorePosition))
            * (document.pageCount - 1))
        view.positionViewAtIndex(page, ListView.Beginning)
        Qt.callLater(() => {
            root.restoring = false
            root.updatePosition()
        })
    }

    Component.onCompleted: {
        if (pdfPath)
            pdfText.open(pdfPath)
    }

    onPdfPathChanged: {
        pageCache = ({})
        position = 0
        currentPage = 0
        restoring = false
        if (pdfPath)
            pdfText.open(pdfPath)
    }

    onRestorePositionChanged: restoreProgress()

    PdfDocument {
        id: document
        source: root.pdfUrl
        onStatusChanged: function(status) {
            if (status === PdfDocument.Ready)
                root.restoreProgress()
        }
    }

    ListView {
        id: view
        objectName: "pdfView"
        anchors.fill: parent
        visible: document.status === PdfDocument.Ready
        clip: true
        model: document.pageCount
        spacing: root.pageGap
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: height
        ScrollBar.vertical: AppScrollBar {}
        onContentYChanged: root.updatePosition()
        onWidthChanged: root.updatePosition()
        onHeightChanged: root.updatePosition()

        delegate: Item {
            id: pageItem
            required property int index
            width: view.width
            height: pageArea.height

            readonly property real aspect: root.pageAspect(index)

            Item {
                id: pageArea
                x: Math.round((pageItem.width - root.pageWidth) / 2)
                width: root.pageWidth
                height: root.pageWidth * pageItem.aspect
                property var hoverWord: null
                readonly property real pageScale: root.pageWidth
                    / Math.max(1, document.pagePointSize(pageItem.index).width)

                PdfPageImage {
                    anchors.fill: parent
                    document: document
                    currentFrame: pageItem.index
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: Math.max(1,
                        Math.round(root.pageWidth * Screen.devicePixelRatio))
                    sourceSize.height: 0
                    onStatusChanged: function(status) {
                        if (status === Image.Ready)
                            root.ensurePageData(pageItem.index)
                    }
                }

                Rectangle {
                    visible: pageArea.hoverWord !== null
                    x: pageArea.hoverWord ? pageArea.hoverWord.x * pageArea.pageScale : 0
                    y: pageArea.hoverWord
                        ? (pageArea.hoverWord.y + pageArea.hoverWord.height) * pageArea.pageScale
                        : 0
                    width: pageArea.hoverWord
                        ? pageArea.hoverWord.width * pageArea.pageScale
                        : 0
                    height: 2
                    color: Theme.foreground
                    opacity: 0.45
                }

                HoverHandler {
                    id: hover
                    onPointChanged: {
                        const hit = root.wordAt(pageItem.index, point.position.x, point.position.y)
                        pageArea.hoverWord = hit ? hit.word : null
                    }
                    onHoveredChanged: if (!hovered)
                        pageArea.hoverWord = null
                }

                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onSingleTapped: (eventPoint, button) => {
                        const hit = root.wordAt(pageItem.index,
                            eventPoint.position.x, eventPoint.position.y)
                        if (hit)
                            root.wordRequested(hit.data.text, hit.word.start, hit.word.end)
                    }
                }
            }
        }
    }

    AppText {
        anchors.centerIn: parent
        visible: document.status === PdfDocument.Loading
        text: "Loading PDF…"
        color: Theme.mutedForeground
    }

    AppText {
        anchors.centerIn: parent
        width: Math.min(parent.width - 2 * Theme.readerPadding, 420)
        visible: document.status === PdfDocument.Error
        text: document.error || "Could not open this PDF."
        color: Theme.destructive
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
    }
}
