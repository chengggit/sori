import QtQuick
import QtTest
import "../../qml/components" as Components

TestCase {
    id: testCase
    name: "ButtonStates"
    when: windowShown
    visible: true; width: 400; height: 200
    Components.AppButton { id: button; x: 100; y: 50; text: "Resume"; variant: "soft" }
    function test_soft_button_feedback() {
        mouseMove(testCase, 0, 0)
        wait(180)
        const idle = button.background.color.toString()
        mouseMove(button, button.width / 2, button.height / 2)
        tryCompare(button, "hovered", true)
        wait(180)
        const hovered = button.background.color.toString()
        verify(hovered !== idle)
        mousePress(button, button.width / 2, button.height / 2)
        wait(180)
        verify(button.background.color.toString() !== hovered)
        mouseRelease(button, button.width / 2, button.height / 2)
    }
}
