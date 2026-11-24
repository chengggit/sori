import QtQuick

Item {
    property var video
    signal checkpoint(var entry, real seconds, real duration)
    function seek(seconds) {
        checkpoint(video, seconds, 20);
    }
}
