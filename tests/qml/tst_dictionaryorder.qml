import QtQuick
import QtTest
import "../../qml/components" as Components
import "../../qml/style"

TestCase {
    id: testCase
    name: "DictionaryOrder"
    when: windowShown
    visible: true
    width: 400
    height: 300
    property string savedOrder
    property string savedCustom
    property string savedDisabled
    property string movedTemplate: ""

    Component {
        id: previewListComponent
        Column {
            id: previewList
            x: 40
            y: 20
            width: 300
            spacing: 4
            property QtObject dragState: Components.DictionaryDragState {
                count: DictionaryTabs.providers.length
            }
            property alias rows: previewRows
            Repeater {
                id: previewRows
                model: DictionaryTabs.providers
                delegate: Components.DictionaryDragRow {
                    id: row
                    required property int index
                    required property var modelData
                    width: previewList.width
                    rowIndex: index
                    dragState: previewList.dragState
                    dragHandle: previewHandle
                    Components.DictionaryOrderHandle {
                        id: previewHandle
                        objectName: "previewHandle"
                        coordinateItem: previewList
                        x: parent.width - width - 6
                        y: 4
                        rowStep: row.height + previewList.spacing
                        onMoveRequested: offset => DictionaryTabs.move(row.modelData.template, offset)
                    }
                }
            }
        }
    }

    Components.DictionaryDragRow {
        id: dragRow
        x: 40
        y: 80
        width: 300
        dragHandle: handle
        Components.DictionaryOrderHandle {
            id: handle
            coordinateItem: dragRow.parent
            x: parent.width - width - 6
            y: 4
            rowStep: 32
            onMoveRequested: offset => DictionaryTabs.move(testCase.movedTemplate, offset)
        }
    }

    function init() {
        savedOrder = DictionaryTabs.store.order
        savedCustom = DictionaryTabs.store.custom
        savedDisabled = DictionaryTabs.store.disabled
        DictionaryTabs.store.order = "[]"
        DictionaryTabs.store.custom = "[]"
        DictionaryTabs.store.disabled = "[]"
    }

    function cleanup() {
        dragRow.visible = true
        DictionaryTabs.store.order = savedOrder
        DictionaryTabs.store.custom = savedCustom
        DictionaryTabs.store.disabled = savedDisabled
    }

    function labels() { return DictionaryTabs.providers.map(entry => entry.label).join(",") }

    function test_drag_and_keyboard() {
        compare(labels(), "Naver,KRDict,Papago")
        movedTemplate = DictionaryTabs.providers[0].template
        mouseDrag(handle, 12, 12, 0, 64, Qt.LeftButton)
        compare(labels(), "KRDict,Papago,Naver")
        handle.forceActiveFocus()
        keyClick(Qt.Key_Up)
        compare(labels(), "KRDict,Naver,Papago")
        compare(JSON.parse(DictionaryTabs.store.order)[1], movedTemplate)
    }

    function test_row_lifts_and_tracks_pointer() {
        movedTemplate = DictionaryTabs.providers[0].template
        const start = handle.mapToItem(testCase, 12, 12)
        const originalY = dragRow.surface.mapToItem(testCase, 0, 0).y
        mousePress(testCase, start.x, start.y)
        mouseMove(testCase, start.x, start.y + 32)
        verify(dragRow.dragging)
        verify(dragRow.placeholder.visible)
        compare(dragRow.z, 100)
        tryVerify(() => dragRow.surface.scale > 1)
        verify(dragRow.surface.mapToItem(testCase, 0, 0).y > originalY + 28)
        compare(labels(), "Naver,KRDict,Papago")
        mouseRelease(testCase, start.x, start.y + 32)
        compare(labels(), "KRDict,Naver,Papago")
        verify(!dragRow.dragging)
        verify(!dragRow.placeholder.visible)
        compare(handle.dragOffset, 0)
    }

    function test_custom_disabled_and_removed_entries() {
        DictionaryTabs.add("Custom", "https://example.test/?q={word}")
        const custom = DictionaryTabs.providers[3].template
        DictionaryTabs.move(custom, -3)
        compare(labels(), "Custom,Naver,KRDict,Papago")
        verify(!DictionaryTabs.isBuiltIn(custom))
        verify(DictionaryTabs.isBuiltIn(DictionaryTabs.providers[1].template))
        DictionaryTabs.setEnabled(custom, false)
        compare(DictionaryTabs.enabled[0].label, "Naver")
        DictionaryTabs.setEnabled(custom, true)
        compare(DictionaryTabs.enabled[0].label, "Custom")
        DictionaryTabs.remove(custom)
        compare(labels(), "Naver,KRDict,Papago")
        DictionaryTabs.move(DictionaryTabs.providers[0].template, -100)
        compare(labels(), "Naver,KRDict,Papago")
    }

    function test_neighbors_preview_drop_data() {
        return [{tag: "up", from: 2, to: 0, labels: "Papago,Naver,KRDict"},
            {tag: "down", from: 0, to: 2, labels: "KRDict,Papago,Naver"}]
    }

    function test_neighbors_preview_drop(data) {
        dragRow.visible = false
        const list = createTemporaryObject(previewListComponent, testCase)
        const dragged = list.rows.itemAt(data.from)
        const neighbor = list.rows.itemAt(data.to)
        const grip = findChild(dragged, "previewHandle")
        const start = grip.mapToItem(testCase, 12, 12)
        const distance = (data.to - data.from) * 36
        mousePress(testCase, start.x, start.y)
        mouseMove(testCase, start.x, start.y + distance)
        compare(list.dragState.to, data.to)
        tryCompare(neighbor, "previewOffset", data.from > data.to ? 36 : -36)
        compare(dragged.placeholder.mapToItem(list, 0, 0).y, data.to * 36)
        compare(labels(), "Naver,KRDict,Papago")
        mouseRelease(testCase, start.x, start.y + distance)
        compare(labels(), data.labels)
        compare(list.dragState.from, -1)
        dragRow.visible = true
    }
}
