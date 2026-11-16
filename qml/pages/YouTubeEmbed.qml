import QtQuick
import QtWebEngine

WebEngineView {
    id: embed

    property var video: null
    property string playbackError: ""
    readonly property string appOrigin: "https://com.sori.app"
    signal checkpoint(var entry, real seconds, real duration)

    profile: WebEngineProfile { offTheRecord: true }
    backgroundColor: "black"
    settings.playbackRequiresUserGesture: true

    onVideoChanged: {
        if (!video || !/^[A-Za-z0-9_-]{11}$/.test(video.youtubeId))
            return
        playbackError = ""
        const start = Math.max(0, Math.floor(video.seconds || 0))
        loadHtml(`<!doctype html>
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>html,body,#player{width:100%;height:100%;margin:0;background:black} iframe{display:block}</style>
<div id="player"></div>
<script>
let player, played = false, error = false;
function onYouTubeIframeAPIReady() {
    player = new YT.Player('player', {
        width: '100%', height: '100%',
        videoId: ${JSON.stringify(video.youtubeId)},
        playerVars: {origin: ${JSON.stringify(appOrigin)}, start: ${start}, cc_lang_pref: 'ko'},
        events: {
            onStateChange: event => { if (event.data === YT.PlayerState.PLAYING) played = true; },
            onError: () => { error = true; }
        }
    });
}
function playbackSnapshot() {
    if (error) return { error: true };
    if (!played) return null;
    const state = player.getPlayerState();
    if (state !== 0 && state !== 1 && state !== 2) return null;
    return { seconds: state === 0 ? 0 : player.getCurrentTime(), duration: player.getDuration() };
}
</script>
<script src="https://www.youtube.com/iframe_api" onerror="error = true"></script>`, appOrigin + "/")
    }

    onLoadingChanged: info => {
        if (info.status === WebEngineView.LoadFailedStatus)
            playbackError = "Could not load the YouTube player. Open the video in your browser."
    }

    Timer {
        interval: 1000
        repeat: true
        running: !!embed.video && !embed.playbackError
        property var lastVideo: null
        property real lastSeconds: -1

        onTriggered: {
            const entry = embed.video
            embed.runJavaScript("typeof playbackSnapshot === 'function' ? playbackSnapshot() : null", sample => {
                if (embed.video !== entry || !sample)
                    return
                if (sample.error) {
                    embed.playbackError = "YouTube could not play this video here. Try opening it in your browser."
                    return
                }
                if (!Number.isFinite(sample.seconds) || !Number.isFinite(sample.duration)
                    || (lastVideo === entry && lastSeconds === sample.seconds))
                    return
                lastVideo = entry
                lastSeconds = sample.seconds
                embed.checkpoint(entry, sample.seconds, sample.duration)
            })
        }
    }
}
