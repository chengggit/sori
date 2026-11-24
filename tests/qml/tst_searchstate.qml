import QtQuick
import QtTest
import sori_core
import "../../qml/pages" as Pages

TestCase {
    id: testCase
    name: "SearchRequestState"
    when: windowShown
    width: 1200; height: 700
    QtObject { id: cache; property string firstPages: "[]" }
    Component { id: pageComponent; Pages.ExplorePage { searchCache: cache } }
    function test_failed_response_is_visible_and_can_retry() {
        cache.firstPages = "[]"
        const page = createTemporaryObject(pageComponent, testCase, {width: width, height: height})
        verify(page)
        page.browse("A", "")
        YouTube.searchFinished(page.request, {ok:false, data:null, error:"Network unavailable"})
        compare(page.error, "Network unavailable")
        compare(page.request, 0)
        page.browse("A", "")
        YouTube.searchFinished(page.request, {ok:true, error:"", data:{videos:[{id:"A", title:"A", channel:"Test"}], nextPage:""}})
        compare(page.error, "")
        compare(page.videos[0].id, "A")
    }
    function test_cached_query_discards_inflight_response() {
        cache.firstPages = JSON.stringify([{query: "query:B", expiresAt: Date.now() + 60000,
            videos: [{id: "B", title: "B", channel: "Test"}], nextPage: ""}])
        const page = createTemporaryObject(pageComponent, testCase, {width: width, height: height})
        verify(page)
        page.browse("A", "")
        const stale = page.request
        verify(stale > 0)
        page.browse("B", "")
        compare(page.request, 0)
        YouTube.searchFinished(stale, {ok:true,error:"",data: {videos: [{id: "A"}], nextPage: ""}})
        compare(page.videos[0].id, "B")
        compare(JSON.parse(cache.firstPages)[0].videos[0].id, "B")
    }
    function test_cached_feed_uses_its_own_query_and_ignores_old_page() {
        const key = "subscriptions:test-channel"
        cache.firstPages = JSON.stringify([{query: key, expiresAt: Date.now() + 60000,
            videos: [{id: "B", title: "B", channel: "Test"}], nextPageTokens: {channel: "next"}}])
        const page = createTemporaryObject(pageComponent, testCase, {width: width, height: height})
        verify(page)
        page.request = 99
        page.loadingMore = true
        page.refreshDiscovery(false)
        compare(page.request, 0)
        compare(page.loadingMore, false)
        compare(page.currentQuery, key)
        YouTube.subscriptionFeedFinished(99, {ok:true,error:"",data: {videos: [{id: "A"}], nextPageTokens: {}}})
        compare(page.videos[0].id, "B")
    }
}
