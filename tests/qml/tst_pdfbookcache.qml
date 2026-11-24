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
    function test_document_switch_discards_previous_words() {
        compare(reader.ensurePageData(0).text, "First book")
        textSource.text = "Second book"
        reader.pdfUrl = "file:///missing-second-book.pdf"
        compare(reader.ensurePageData(0).text, "Second book")
        compare(reader.ensurePageData(0).words[0].text, "Second book")
        reader.pdfUrl = ""
        compare(Object.keys(reader.pageCache).length, 0)
    }
}
