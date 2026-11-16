import QtQuick
import "../style"

Text {
    property bool korean: false

    color: Theme.foreground
    font.family: korean ? "Noto Sans KR" : "Inter"
    font.pixelSize: 14
    renderType: Text.NativeRendering
    textFormat: Text.PlainText
}
