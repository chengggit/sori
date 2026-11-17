import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../style"

Button {
    id: control

    property string variant: "default"
    property string iconName: ""
    property int iconSize: small ? 14 : Theme.iconSize
    property bool small: false
    property bool compact: false
    readonly property bool iconOnly: text === "" && iconName !== ""
    readonly property color contentColor: variant === "default" ? Theme.onAccent
        : variant === "primary" ? Theme.primaryForeground : Theme.foreground

    implicitHeight: iconOnly ? Theme.iconButtonSize
        : small || compact ? Theme.compactControlHeight : Theme.inputHeight
    implicitWidth: iconOnly ? Theme.iconButtonSize
        : Math.max(small ? 64 : 80, contentRow.implicitWidth + leftPadding + rightPadding)
    padding: 0
    leftPadding: iconOnly ? 0 : small ? 10 : 13
    rightPadding: leftPadding
    hoverEnabled: true

    contentItem: Item {
        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: Theme.controlGap

            Icon {
                visible: control.iconName !== ""
                name: control.iconName
                size: control.iconSize
                color: control.contentColor
            }
            AppText {
                visible: text !== ""
                text: control.text
                color: control.contentColor
                font.pixelSize: control.small ? 12 : 13
                font.weight: Font.Medium
            }
        }
    }

    background: Rectangle {
        radius: control.variant === "primary" ? Theme.radius : Theme.radiusSmall
        color: {
            if (!control.enabled)
                return control.variant === "default" ? Theme.disabledAccent : Theme.sidebar
            if (control.variant === "default")
                return control.down ? Theme.accentPressed : control.hovered ? Theme.accentHover : Theme.accent
            if (control.variant === "primary")
                return Qt.alpha(Theme.primary, control.down || control.hovered ? 0.8 : 1)
            if (control.variant === "secondary")
                return control.down || control.hovered ? Theme.accentSoftHover : Theme.accentSoft
            if (control.variant === "ghost")
                return control.hovered || control.down ? Theme.neutralHover
                    : Qt.alpha(Theme.neutralHover, 0)
            return control.hovered || control.down ? Theme.neutralHover : Theme.card
        }
        border.width: control.variant === "outline" ? 1 : 0
        border.color: Theme.border

        Behavior on color {
            ColorAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }
}
