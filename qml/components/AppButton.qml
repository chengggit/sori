import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../style"

Button {
    id: control

    property string variant: "default"
    property string iconName: ""
    property bool small: false

    implicitHeight: small ? 32 : 38
    implicitWidth: Math.max(small ? 64 : 80, contentRow.implicitWidth + (small ? 20 : 26))
    leftPadding: 13
    rightPadding: 13
    hoverEnabled: true

    contentItem: RowLayout {
        id: contentRow
        spacing: 7

        Icon {
            visible: control.iconName !== ""
            name: control.iconName
            size: control.small ? 14 : 16
            color: control.variant === "default" ? Theme.onAccent : Theme.foreground
        }
        AppText {
            text: control.text
            color: control.variant === "default" ? Theme.onAccent : Theme.foreground
            font.pixelSize: control.small ? 12 : 13
            font.weight: Font.Medium
        }
    }

    background: Rectangle {
        radius: Theme.radiusSmall
        color: {
            if (!control.enabled)
                return control.variant === "default" ? Theme.disabledAccent : Theme.sidebar
            if (control.variant === "default")
                return control.down ? Theme.accentPressed : control.hovered ? Theme.accentHover : Theme.accent
            if (control.variant === "secondary")
                return control.down || control.hovered ? Theme.accentSoftHover : Theme.accentSoft
            if (control.variant === "ghost")
                return control.hovered || control.down ? Theme.accentSoft : "transparent"
            return control.hovered || control.down ? Theme.hero : Theme.card
        }
        border.width: control.variant === "outline" ? 1 : 0
        border.color: Theme.border
    }
}
