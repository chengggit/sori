import QtQuick
import QtTest
import "../../qml/components" as Components

TestCase {
    id: testCase
    name: "PageFrameGutters"
    when: windowShown

    Item {
        id: host
        width: 1916
        height: 800
    }

    Component {
        id: frameComponent
        Components.PageFrame {}
    }

    function makeFrame(parentWidth) {
        host.width = parentWidth
        const frame = createTemporaryObject(frameComponent, host)
        verify(frame)
        // Pages anchor the frame between the header and the window bottom.
        frame.anchors.top = host.top
        frame.anchors.bottom = host.bottom
        return frame
    }

    // Wide windows cap content at the dashboard width and center it.
    function test_wide_window_centers_content() {
        const frame = makeFrame(1916)
        compare(frame.width, 1528)
        compare(frame.x, (1916 - 1528) / 2)
    }

    function test_medium_window_uses_inset() {
        const frame = makeFrame(1200)
        compare(frame.width, 1200 - 2 * 32)
        compare(frame.x, 32)
    }

    function test_narrow_window_uses_inset() {
        const frame = makeFrame(600)
        compare(frame.width, 600 - 2 * 32)
        compare(frame.x, 32)
    }

    function test_default_vertical_padding() {
        const frame = makeFrame(1916)
        compare(frame.topPadding, 28)
        compare(frame.bottomPadding, 28)
    }

    function test_padding_override() {
        const frame = makeFrame(1916)
        frame.topPadding = 0
        frame.bottomPadding = 0
        compare(frame.topPadding, 0)
        compare(frame.bottomPadding, 0)
    }

    function test_header_alignment_matches_frame() {
        const frame = makeFrame(1916)
        // PageHeader mirrors the frame's gutter calculation.
        const headerGutter = Math.max(32, (1916 - 1528) / 2)
        compare(headerGutter, frame.x)
    }
}
