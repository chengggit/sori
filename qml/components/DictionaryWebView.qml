import QtQml
import QtWebEngine
import "../style"

WebEngineView {
    id: root
    property string loadError: ""

    userScripts.collection: [{
        name: "Dictionary scrollbars",
        injectionPoint: WebEngineScript.DocumentReady,
        worldId: WebEngineScript.ApplicationWorld,
        runsOnSubFrames: true,
        sourceCode: `
            const style = new CSSStyleSheet();
            style.replaceSync(\`
                * { scrollbar-width: auto !important; scrollbar-color: auto !important; }
                ::-webkit-scrollbar { width: ${Theme.scrollBarThickness}px !important; height: ${Theme.scrollBarThickness}px !important; }
                ::-webkit-scrollbar-track, ::-webkit-scrollbar-corner {
                    background: transparent !important;
                }
                ::-webkit-scrollbar-thumb {
                    background: transparent !important;
                    border-radius: ${Theme.scrollBarThickness / 2}px;
                }
                [data-sori-scrollbar-moving]::-webkit-scrollbar-thumb {
                    background: color-mix(in srgb, ${Theme.scrollBarColor} ${Theme.scrollBarOpacity * 100}%, transparent) !important;
                }
                ::-webkit-scrollbar-thumb:hover, ::-webkit-scrollbar-thumb:active {
                    background: color-mix(in srgb, ${Theme.scrollBarColor} ${Theme.scrollBarActiveOpacity * 100}%, transparent) !important;
                }
                ::-webkit-scrollbar-button { display: none !important; }
            \`);
            document.adoptedStyleSheets = [...document.adoptedStyleSheets, style];

            const hideTimers = new WeakMap();
            document.addEventListener("scroll", event => {
                const area = event.target === document ? document.scrollingElement : event.target;
                if (!(area instanceof Element)) return;
                area.setAttribute("data-sori-scrollbar-moving", "");
                clearTimeout(hideTimers.get(area));
                hideTimers.set(area, setTimeout(() => {
                    area.removeAttribute("data-sori-scrollbar-moving");
                    hideTimers.delete(area);
                }, ${Theme.scrollBarHideDelay}));
            }, { capture: true, passive: true });
        `
    }]

    onLoadingChanged: request => {
        if (request.status === WebEngineView.LoadStartedStatus)
            root.loadError = ""
        else if (request.status === WebEngineView.LoadFailedStatus)
            root.loadError = "Could not load this dictionary."
    }

    WebEngineProfilePrototype { id: dictionaryProfile }
    Component.onCompleted: profile = dictionaryProfile.instance()

    onJavaScriptConsoleMessage: (level, message, line, source) => {
        if (level === WebEngineView.ErrorMessageLevel) {
            console.error(source + ":" + line, message)
        } else if (level === WebEngineView.WarningMessageLevel) {
            const page = root.url.toString()
            const naverProvider = page.startsWith("https://papago.naver.com/")
                || page.startsWith("https://korean.dict.naver.com/")
            const preloadNotice = message.startsWith("The resource https://papago.naver.com/")
                && message.includes("was preloaded using link preload but not used")
            if (!naverProvider || (message !== "setPolicyInfo [object Object]" && !preloadNotice))
                console.warn(source + ":" + line, message)
        }
    }

    onNavigationRequested: request => {
        if (request.isMainFrame && !request.url.toString().startsWith("https://"))
            request.reject()
    }
}
