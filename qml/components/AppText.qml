import QtQuick
import "../style"

Text {
    property bool korean: false

    color: Theme.foreground
    font.family: korean ? "Noto Sans KR" : "Inter"
    font.pixelSize: 14
    // Distance-field glyphs stay smooth under the zoom transform. The curve
    // renderer is sharper in theory but produces broken pixels at small sizes.
    renderType: Text.QtRendering
    textFormat: Text.PlainText
}
