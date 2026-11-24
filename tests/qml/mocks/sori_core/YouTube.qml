pragma Singleton
import QtQuick

QtObject {
    property bool configured: true
    property var subscriptions: [{channelId: "test-channel"}]
    property int nextRequest: 0
    signal transcriptFinished(int request, var result)
    function fetchTranscript(id, language) { return ++nextRequest }
    signal configurationChanged()
    signal searchFinished(int request, var result)
    signal subscriptionFeedFinished(int request, var result)
    function search(query, page) { return ++nextRequest }
    function subscriptionFeed() { return ++nextRequest }
    function subscriptionFeedPage(tokens) { return ++nextRequest }
}
