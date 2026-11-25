import QtQuick
import QtQuick.Controls
import QtQuick.Pdf
import QtQuick.Shapes
import "../style"

// One page at a time: the PDF is never flicked or scrolled. Clicking the left
// half turns back, clicking the right half turns forward, and words with an
// embedded text layer stay clickable for analysis.
Item {
    id: root
    clip: true

    required property string pdfUrl
    required property var pdfText
    property real zoom: 1
    property real restorePosition: 0
    property int currentPage: 0
    readonly property int pageCount: pdfDocument.pageCount
    readonly property real position: pageCount > 1 ? currentPage / (pageCount - 1) : 0
    property var pageCache: ({})

    readonly property real aspect: {
        // pagePointSize() itself has no change notification. Re-evaluate once
        // the document is ready instead of retaining the loading placeholder.
        if (pdfDocument.status !== PdfDocument.Ready || pdfDocument.pageCount === 0)
            return 1.4
        const size = pdfDocument.pagePointSize(Math.max(0, currentPage))
        return size.width > 0 ? size.height / size.width : 1.4
    }
    readonly property real fitWidth: Math.max(0, Math.min(
        root.width - 2 * Theme.readerPadding,
        (root.height - 2 * Theme.readerPadding) / Math.max(0.2, root.aspect)))
    readonly property real rasterScale: Theme.pageScale * (Screen.devicePixelRatio || 1)
    // Match the displayed width to the PDF raster, avoiding fractional resampling.
    readonly property real pageWidth: Math.round(root.fitWidth * zoom * rasterScale) / rasterScale
    readonly property real pageHeight: root.pageWidth * root.aspect

    signal wordRequested(string text, int start, int end)

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
        const scale = pageArea.width / size.width
        const px = x / scale
        const py = y / scale
        for (const word of data.words) {
            if (px >= word.x && px <= word.x + word.width
                    && py >= word.y && py <= word.y + word.height)
                return { data: data, word: word }
        }
        return null
    }

    function goToPage(index) {
        const page = Math.max(0, Math.min(pdfDocument.pageCount - 1, index))
        if (page !== currentPage)
            currentPage = page
    }

    function nextPage() { root.goToPage(root.currentPage + 1) }
    function previousPage() { root.goToPage(root.currentPage - 1) }

    function resetScroll() {
        view.contentX = Math.round((view.contentWidth - view.width) / 2 * rasterScale) / rasterScale
        view.contentY = Math.round((view.contentHeight - view.height) / 2 * rasterScale) / rasterScale
    }

    // A wheel notch moves a fixed fraction of the page rather than Qt's slow,
    // decelerated flick. Trackpad pixel deltas already supply smooth motion.
    function wheelScroll(vertical, delta, precise) {
        const animation = vertical ? wheelY : wheelX
        const maximum = vertical
            ? view.contentHeight - view.height
            : view.contentWidth - view.width
        if (maximum <= 0)
            return
        const step = precise ? delta * 2 : delta / 120 * 300 * zoom
        const property = vertical ? "contentY" : "contentX"
        const target = animation.running ? animation.to : view[property]
        animation.stop()
        const destination = Math.max(0, Math.min(maximum, target - step))
        if (precise) {
            view[property] = destination
        } else {
            animation.from = view[property]
            animation.to = destination
            animation.restart()
        }
    }

    // Coordinates are page-local. A word tap opens analysis; any other tap on
    // the left half turns back and one on the right half turns forward.
    function tapAt(x, y) {
        const hit = root.wordAt(root.currentPage, x, y)
        if (hit) {
            root.wordRequested(hit.data.text, hit.word.start, hit.word.end)
            return
        }
        if (root.pageCount > 1) {
            if (x < pageArea.width / 2)
                root.previousPage()
            else
                root.nextPage()
        }
    }

    function restoreProgress() {
        if (pdfDocument.status !== PdfDocument.Ready || pdfDocument.pageCount === 0)
            return
        currentPage = Math.round(
            Math.max(0, Math.min(1, restorePosition)) * (pdfDocument.pageCount - 1))
    }

    onPdfUrlChanged: {
        pageCache = ({})
        currentPage = 0
        wheelX.stop()
        wheelY.stop()
        Qt.callLater(root.resetScroll)
    }

    Component.onCompleted: root.restoreProgress()
    onRestorePositionChanged: root.restoreProgress()
    onZoomChanged: Qt.callLater(root.resetScroll)
    onCurrentPageChanged: Qt.callLater(root.resetScroll)

    PdfDocument {
        id: pdfDocument
        source: root.pdfUrl
        onStatusChanged: function(status) {
            if (status === PdfDocument.Ready)
                root.restoreProgress()
        }
    }

    // At 100% the page fits and the view is inert, so clicks turn pages. Above
    // that, the same view pans the enlarged page by drag, wheel, or scrollbar.
    Flickable {
        id: view
        anchors.fill: parent
        clip: true
        interactive: root.zoom > 1
        contentWidth: Math.max(width, root.pageWidth + 2 * Theme.readerPadding)
        contentHeight: Math.max(height, root.pageHeight + 2 * Theme.readerPadding)
        boundsBehavior: Flickable.StopAtBounds
        onDraggingChanged: if (dragging) { wheelX.stop(); wheelY.stop() }
        ScrollBar.vertical: AppScrollBar {
            onPressedChanged: if (pressed) { wheelX.stop(); wheelY.stop() }
        }
        ScrollBar.horizontal: AppScrollBar {
            onPressedChanged: if (pressed) { wheelX.stop(); wheelY.stop() }
        }

        NumberAnimation {
            id: wheelX
            target: view
            property: "contentX"
            duration: 180
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: wheelY
            target: view
            property: "contentY"
            duration: 180
            easing.type: Easing.OutCubic
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            target: null
            blocking: true
            enabled: root.zoom > 1
            onWheel: event => {
                const precise = event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0
                let handled = false
                if (event.angleDelta.y !== 0 || (precise && event.pixelDelta.y !== 0)) {
                    root.wheelScroll(true,
                        precise ? event.pixelDelta.y : event.angleDelta.y, precise)
                    handled = true
                }
                if (event.angleDelta.x !== 0 || (precise && event.pixelDelta.x !== 0)) {
                    root.wheelScroll(false,
                        precise ? event.pixelDelta.x : event.angleDelta.x, precise)
                    handled = true
                }
                event.accepted = handled
            }
        }

        Item {
            id: pageArea
            objectName: "bookPageArea"
            x: Math.round((view.contentWidth - root.pageWidth) / 2 * root.rasterScale) / root.rasterScale
            y: Math.round((view.contentHeight - root.pageHeight) / 2 * root.rasterScale) / root.rasterScale
            width: root.pageWidth
            height: root.pageHeight
            property var hoverWord: null
            readonly property real pageScale: root.pageWidth
                / Math.max(1, pdfDocument.pagePointSize(root.currentPage).width)

            Rectangle {
                anchors.fill: parent
                color: "white"
            }

            PdfPageImage {
                id: pageImage
                objectName: "bookPageImage"
                anchors.fill: parent
                document: pdfDocument
                currentFrame: root.currentPage
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                sourceSize.width: Math.max(1,
                    Math.round(root.pageWidth * root.rasterScale))
                sourceSize.height: 0
                onStatusChanged: function(status) {
                    if (status === Image.Ready)
                        root.ensurePageData(root.currentPage)
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
                width: pageArea.hoverWord ? pageArea.hoverWord.width * pageArea.pageScale : 0
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
                    const hit = root.wordAt(root.currentPage, point.position.x, point.position.y)
                    pageArea.hoverWord = hit ? hit.word : null
                }
                onHoveredChanged: if (!hovered)
                    pageArea.hoverWord = null
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onSingleTapped: (eventPoint, button) => {
                    root.tapAt(eventPoint.position.x, eventPoint.position.y)
                }
            }
        }
    }

    // Taps in the margin outside the page still turn it; taps on the page
    // are handled by the page's own handler (the deeper handler takes the grab).
    TapHandler {
        acceptedButtons: Qt.LeftButton
        enabled: root.pageCount > 1
        onSingleTapped: (eventPoint, button) => {
            const local = pageArea.mapFromItem(root, eventPoint.position)
            if (local.x >= 0 && local.x <= pageArea.width
                    && local.y >= 0 && local.y <= pageArea.height)
                return
            root.tapAt(local.x, local.y)
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
