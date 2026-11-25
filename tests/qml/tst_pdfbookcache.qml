import QtQuick
import QtTest
import "../../qml/components" as Components

TestCase {
    name: "PdfBookCache"
    when: windowShown
    QtObject {
        id: textSource
        property string text: "First book"
        function page(index) { return {text: text, words: [{text: text, start: 0, end: text.length}]} }
    }
    Components.PdfBookReader { id: reader; pdfUrl: ""; pdfText: textSource; width: 500; height: 600 }
    function test_book_page_aligns_to_raster_pixels_data() {
        return [{tag: "fit", zoom: 1}, {tag: "zoom", zoom: 1.25}]
    }

    function test_book_page_aligns_to_raster_pixels(data) {
        reader.width = 503
        reader.height = 619
        reader.zoom = data.zoom
        const area = findChild(reader, "bookPageArea")
        const image = findChild(reader, "bookPageImage")
        const scale = reader.rasterScale
        const pixels = reader.pageWidth * scale
        verify(Math.abs(pixels - Math.round(pixels)) < 0.001)
        compare(image.sourceSize.width, Math.round(pixels))
        verify(Math.abs(area.x * scale - Math.round(area.x * scale)) < 0.001)
        verify(Math.abs(area.y * scale - Math.round(area.y * scale)) < 0.001)
        reader.zoom = 1
        reader.width = 500
        reader.height = 600
    }
    function test_document_switch_discards_previous_words() {
        compare(reader.ensurePageData(0).text, "First book")
        textSource.text = "Second book"
        reader.pdfUrl = "file:///missing-second-book.pdf"
        compare(reader.ensurePageData(0).text, "Second book")
        compare(reader.ensurePageData(0).words[0].text, "Second book")
        reader.pdfUrl = ""
        compare(Object.keys(reader.pageCache).length, 0)
    }

    function test_page_turn_returns_to_top_when_zoomed() {
        const view = findChild(reader, "bookPageView")
        reader.zoom = 2
        wait(50)
        verify(view.contentHeight > view.height)

        view.contentY = 160
        reader.currentPage = 1
        tryCompare(view, "contentY", 0)

        reader.currentPage = 0
        reader.zoom = 1
        wait(50)
    }
}
