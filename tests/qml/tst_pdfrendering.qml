import QtQuick
import QtTest
import "../../qml/components" as Components

TestCase {
    id: suite
    name: "PdfRendering"
    when: windowShown
    width: 1000
    height: 1000

    QtObject {
        id: textSource
        function open(path) {}
        function page(index) { return {text: "", words: []} }
    }

    Component {
        id: fixtureComponent
        Item {
            id: fixture
            property string source: ""
            property alias book: book
            property alias scroll: scroll
            Components.PdfBookReader {
                id: book
                width: 900
                height: 840
                zoom: 1.1
                pdfUrl: fixture.source
                pdfText: textSource
            }
            Components.PdfPageReader {
                id: scroll
                width: book.pageWidth + 48
                height: 1000
                pdfUrl: fixture.source
                pdfPath: ""
                pdfText: textSource
            }
        }
    }

    function test_loaded_page_uses_real_aspect_and_matches_scroll_rendering() {
        const fixture = createTemporaryObject(fixtureComponent, suite)
        compare(fixture.book.aspect, 1.4)
        fixture.source = Qt.resolvedUrl("../fixtures/pdf-rendering.pdf")
        tryCompare(fixture.book, "pageCount", 1)
        tryVerify(() => Math.abs(fixture.book.aspect - 792 / 612) < 0.0001)
        const bookImage = findChild(fixture.book, "bookPageImage")
        tryCompare(bookImage, "status", Image.Ready)
        tryVerify(() => findChild(fixture.scroll, "scrollPageImage") !== null)
        const scrollImage = findChild(fixture.scroll, "scrollPageImage")
        tryCompare(scrollImage, "status", Image.Ready)
        compare(bookImage.sourceSize.width, scrollImage.sourceSize.width)
        verify(Math.abs(bookImage.paintedWidth - scrollImage.paintedWidth) < 0.1)
        verify(Math.abs(bookImage.paintedHeight - scrollImage.paintedHeight) < 0.1)
        // The image should fill the book page, with only raster rounding error.
        verify(Math.abs(bookImage.paintedWidth - fixture.book.pageWidth) < 1)
    }
}
