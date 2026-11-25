import QtQuick
import QtQuick.Controls
import QtQuick.Pdf
import QtQuick.Shapes
import "../style"

Item {
    id: root
    clip: true

    required property string pdfPath
    required property string pdfUrl
    required property var pdfText
    property real zoom: 1
    property real restorePosition: 0
    property real position: 0
    property int currentPage: 0
    readonly property int pageCount: pdfDocument.pageCount
    property bool restoring: false
    property var pageCache: ({})

    readonly property int pageGap: 20
    readonly property real pageWidth: Math.max(0, Math.min(width - 2 * Theme.readerPadding, 920))
        * zoom

    signal wordRequested(string text, int start, int end)

    function pageAspect(index) {
        const size = pdfDocument.pagePointSize(index)
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
        const size = pdfDocument.pagePointSize(index)
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
        if (restoring || pdfDocument.pageCount === 0)
            return
        const page = Math.max(0, Math.min(pdfDocument.pageCount - 1,
            view.indexAt(0, view.contentY + 1)))
        currentPage = page
        position = pdfDocument.pageCount > 1 ? page / (pdfDocument.pageCount - 1) : 0
    }

    function restoreProgress() {
        if (pdfDocument.status !== PdfDocument.Ready || pdfDocument.pageCount === 0 || restoring)
            return
        restoring = true
        const page = Math.round(Math.max(0, Math.min(1, restorePosition))
            * (pdfDocument.pageCount - 1))
        view.positionViewAtIndex(page, ListView.Beginning)
        Qt.callLater(() => {
            root.restoring = false
            root.updatePosition()
        })
    }

    function scrollByPage(direction) {
        const minimum = view.originY
        const maximum = Math.max(minimum, minimum + view.contentHeight - view.height)
        const target = wheelScroll.running ? wheelScroll.to : view.contentY
        wheelScroll.stop()
        view.cancelFlick()
        const destination = Math.max(minimum, Math.min(maximum,
            target + direction * view.height * 0.9))
        wheelScroll.from = view.contentY
        wheelScroll.to = destination
        wheelScroll.restart()
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
        id: pdfDocument
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
        visible: pdfDocument.status === PdfDocument.Ready
        clip: true
        contentWidth: Math.max(view.width, root.pageWidth + 2 * Theme.readerPadding)
        model: pdfDocument.pageCount
        spacing: root.pageGap
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: height
        onContentYChanged: root.updatePosition()
        onWidthChanged: root.updatePosition()
        onHeightChanged: root.updatePosition()
        onDraggingChanged: if (dragging) wheelScroll.stop()

        NumberAnimation {
            id: wheelScroll
            target: view
            property: "contentY"
            duration: 180
            easing.type: Easing.OutCubic
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            target: null
            blocking: true
            onWheel: event => {
                if (event.angleDelta.y === 0 && event.pixelDelta.y === 0) {
                    event.accepted = false
                    return
                }
                event.accepted = true
                const precise = event.pixelDelta.y !== 0
                // A wheel notch is 120 angle units. Scroll by distance,
                // rather than a flick velocity that Qt caps and decelerates.
                const distance = precise ? event.pixelDelta.y * 2 : event.angleDelta.y / 120 * 300
                const previousTarget = wheelScroll.running ? wheelScroll.to : view.contentY
                wheelScroll.stop()
                view.cancelFlick()
                const minimum = view.originY
                const maximum = Math.max(minimum, minimum + view.contentHeight - view.height)
                const destination = Math.max(minimum, Math.min(maximum,
                    (precise ? view.contentY : previousTarget) - distance))
                if (precise) {
                    view.contentY = destination
                } else {
                    wheelScroll.from = view.contentY
                    wheelScroll.to = destination
                    wheelScroll.restart()
                }
            }
        }
        ScrollBar.vertical: AppScrollBar {
            onPressedChanged: if (pressed) wheelScroll.stop()
        }

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
                    / Math.max(1, pdfDocument.pagePointSize(pageItem.index).width)

                Rectangle {
                    anchors.fill: parent
                    color: "white"
                }

                PdfPageImage {
                    id: pageImage
                    objectName: "scrollPageImage"
                    width: pageArea.width
                    height: pageArea.height
                    document: pdfDocument
                    currentFrame: pageItem.index
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: Math.max(1,
                        Math.round(pageArea.width * Theme.pageScale * (Screen.devicePixelRatio || 1)))
                    sourceSize.height: 0
                    onStatusChanged: function(status) {
                        if (status === Image.Ready)
                            root.ensurePageData(pageItem.index)
                    }
                }

                AppText {
                    anchors.centerIn: parent
                    visible: pageImage.status === Image.Loading || pageImage.status === Image.Null
                    text: "Rendering page…"
                    color: Theme.mutedForeground
                }

                AppText {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 24, 320)
                    visible: pageImage.status === Image.Error
                    text: "Could not render this page."
                    color: Theme.destructive
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Shape {
                    id: wordUnderline
                    visible: pageArea.hoverWord !== null
                    x: pageArea.hoverWord ? pageArea.hoverWord.x * pageArea.pageScale : 0
                    y: pageArea.hoverWord
                        ? (pageArea.hoverWord.y + pageArea.hoverWord.height) * pageArea.pageScale + 4
                        : 0
                    width: pageArea.hoverWord
                        ? pageArea.hoverWord.width * pageArea.pageScale
                        : 0
                    height: 2

                    ShapePath {
                        strokeColor: Theme.foreground
                        strokeWidth: 2
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [1, 1]
                        capStyle: ShapePath.FlatCap
                        fillColor: "transparent"
                        startY: 1
                        PathLine { x: wordUnderline.width; y: 1 }
                    }
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
        visible: pdfDocument.status === PdfDocument.Loading
        text: "Loading PDF…"
        color: Theme.mutedForeground
    }

    AppText {
        anchors.centerIn: parent
        width: Math.min(parent.width - 2 * Theme.readerPadding, 420)
        visible: pdfDocument.status === PdfDocument.Error
        text: pdfDocument.error || "Could not open this PDF."
        color: Theme.destructive
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
    }
}
