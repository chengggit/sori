import QtWebEngine

WebEngineView {
    profile: WebEngineProfile { offTheRecord: true }
    onNavigationRequested: request => {
        if (request.isMainFrame && !request.url.toString().startsWith("https://"))
            request.reject()
    }
}
