import QtQuick
import QtTest
import sori_core
import "../../qml/style"
import "../../qml/pages" as Pages

TestCase {
    id: testCase
    name: "DiscoveryPagination"
    when: windowShown
    visible: true
    width: 1200
    height: 700

    QtObject {
        id: cache
        property string firstPages: "[]"
    }
    Component {
        id: pageComponent
        Pages.ExplorePage {
            discovery: true
            searchCache: cache
            // A representative Continue Watching header.
            leadingContent: Rectangle { implicitHeight: 248 }
        }
    }

    function videos(first, count) {
        const entries = []
        for (let i = first; i < first + count; i++)
            entries.push({id: "video-" + i, title: "Video " + i, channel: "Test channel"})
        return entries
    }

    function test_loading_slides_down_at_top_and_back_up() {
        cache.firstPages = "[]"
        const page = createTemporaryObject(pageComponent, testCase, {width: width, height: height})
        verify(page !== null)
        tryVerify(() => page.request !== 0)
        const spinner = findChild(page, "discoveryLoadingSpinner")
        const row = findChild(page, "discoveryLoadingRow")
        const grid = findChild(page, "discoveryResults")
        verify(spinner !== null && row !== null)
        tryCompare(row, "height", 56)
        verify(spinner.visible && spinner.running)
        compare(page.statusText, "")
        compare(spinner.x, (grid.width - spinner.width) / 2)
        verify(spinner.mapToItem(grid, 0, 0).y + spinner.height <= grid.headerItem.height)
        compare(findChild(spinner, "discoverySpinnerArc").strokeColor, Theme.accent)
        YouTube.subscriptionFeedFinished(page.request, {ok:true, error:"", data:{videos: videos(0, 4), nextPageTokens:{}}})
        tryCompare(row, "height", 0)
        verify(!spinner.visible)

        page.refreshDiscovery(true)
        wait(80)
        verify(row.height > 0 && row.height < 56, "Refresh should slide down")
        tryCompare(row, "height", 56)
        YouTube.subscriptionFeedFinished(page.request, {ok:false, data:null, error:"Test failure"})
        wait(80)
        verify(row.height > 0 && row.height < 56, "Completion should slide back up")
        tryCompare(row, "height", 0)
    }

    function test_more_videos_preserve_existing_grid() {
        cache.firstPages = "[]"
        const page = createTemporaryObject(pageComponent, testCase, {width: width, height: height})
        verify(page !== null)
        tryVerify(() => page.request !== 0)
        YouTube.subscriptionFeedFinished(page.request, {ok:true,error:"",data: {
            videos: videos(0, 40), nextPageTokens: {channel: "page-2"}
        }})
        const grid = findChild(page, "discoveryResults")
        verify(grid !== null)
        tryCompare(grid, "count", 40)
        tryCompare(findChild(page, "discoveryLoadingRow"), "height", 0)
        grid.forceLayout()
        grid.positionViewAtEnd()
        grid.forceLayout()
        wait(50)
        const originalY = grid.contentY
        const originalHeight = grid.contentHeight
        const originalOrder = []
        for (let i = 0; i < grid.count; i++)
            originalOrder.push(grid.model.get(i).video.id)
        const anchor = grid.itemAtIndex(36)
        verify(anchor !== null)

        page.loadMoreNearEnd()
        verify(page.loadingMore)
        verify(page.request !== 0)
        wait(50)
        // Include overlap with the preceding page and a duplicate in this page.
        YouTube.subscriptionFeedFinished(page.request, {ok:true,error:"",data: {
            videos: videos(35, 15).concat(videos(45, 1)), nextPageTokens: {channel: "page-3"}
        }})
        tryCompare(grid, "count", 50)
        grid.forceLayout()
        wait(50)
        for (let i = 0; i < originalOrder.length; i++)
            compare(grid.model.get(i).video.id, originalOrder[i], "Existing video order must stay fixed")
        compare(grid.itemAtIndex(36), anchor, "Appending must retain visible delegates")
        verify(Math.abs(grid.contentY - originalY) < 1, "Appending must preserve the viewport")
        verify(grid.contentHeight > originalHeight)
        compare(page.videos.length, 50)
        compare(page.nextPageTokens.channel, "page-3")
        verify(!page.loadingMore)
        compare(page.request, 0)
    }
}
