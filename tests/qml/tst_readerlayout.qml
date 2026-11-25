import QtQuick
import QtTest
import "../../qml/pages" as Pages

TestCase {
    id: testCase
    name: "NarrowReaderLayout"
    when: windowShown
    width: 950
    height: 800

    QtObject {
        id: host
        function localUrl(path) { return "" }
    }
    QtObject {
        id: pdfText
        function open(path) {}
        function page(index) { return { text: "", words: [] } }
    }
    Component {
        id: readerComponent
        Pages.ReaderPage {
            active: false
            renderHost: host
            pdfText: testCase.pdfSource
            pdfPath: "/missing.pdf"
        }
    }
    property var pdfSource: pdfText

    function test_toolbar_wraps_without_overlapping_analysis_data() {
        return [{tag: "scroll", book: false}, {tag: "book", book: true}]
    }

    function test_toolbar_wraps_without_overlapping_analysis(data) {
        const page = createTemporaryObject(readerComponent, testCase, {
            width: 750, height: 800, bookMode: data.book
        })
        verify(page !== null)
        const panel = findChild(page, "readerAnalysisSidebar")
        panel.selectedWord = "나무"
        panel.animateEntrance = false
        panel.revealProgress = 1
        const content = findChild(page, "readerContent")
        const toolbar = findChild(page, "pdfToolbar")
        const pdf = findChild(page, data.book ? "pdfBookReader" : "pdfPageReader")
        wait(0)
        verify(content.clip)
        compare(content.width, panel.x)
        verify(pdf.width <= content.width)
        verify(toolbar.width <= content.width)
        verify(toolbar.height > 40, "Toolbar should wrap in the narrow reading area")
        for (const control of toolbar.children) {
            if (control.visible && control.width > 0)
                verify(control.x + control.width <= toolbar.width + 1)
        }
        page.width = 1400
        wait(0)
        tryVerify(() => toolbar.height <= 40, 1000,
            "Toolbar should return to one row when space allows")
    }
}
