pragma Singleton

import QtQuick
import QtCore

QtObject {
    property bool webEngineAvailable: false
    readonly property var builtIn: [
        { label: "Naver", template: "https://korean.dict.naver.com/koendict/#/search?query={word}" },
        { label: "KRDict", template: "https://krdict.korean.go.kr/m/eng/searchResult?mainSearchWord={word}" },
        { label: "Papago", template: "https://papago.naver.com/?sl=ko&tl=en&text={word}" }
    ]
    readonly property var providers: {
        const entries = builtIn.concat(custom.filter(provider => !isBuiltIn(provider.template)))
        const order = JSON.parse(preferences.order)
        return order.map(template => entries.find(entry => entry.template === template))
            .filter(entry => entry !== undefined)
            .concat(entries.filter(entry => !order.includes(entry.template)))
    }
    readonly property var enabled: providers.filter(provider => !disabled.includes(provider.template))

    readonly property var custom: JSON.parse(preferences.custom)
    readonly property var disabled: JSON.parse(preferences.disabled)

    property Settings store: Settings {
        id: preferences
        category: "DictionaryTabs"
        property string custom: "[]"
        property string disabled: "[]"
        property string order: "[]"
    }

    function isBuiltIn(template) {
        return builtIn.some(entry => entry.template === template)
    }

    function move(template, offset) {
        const entries = providers.map(provider => provider.template)
        const from = entries.indexOf(template)
        if (from < 0) return
        const to = Math.max(0, Math.min(entries.length - 1, from + offset))
        if (from === to) return
        entries.splice(from, 1)
        entries.splice(to, 0, template)
        preferences.order = JSON.stringify(entries)
    }

    function setEnabled(template, enabled) {
        const remaining = disabled.filter(entry => entry !== template)
        preferences.disabled = JSON.stringify(enabled ? remaining : remaining.concat([template]))
    }

    function add(label, template) {
        preferences.custom = JSON.stringify(custom.concat([{ label: label, template: template }]))
    }

    function remove(template) {
        preferences.custom = JSON.stringify(custom.filter(provider => provider.template !== template))
        setEnabled(template, true)
    }
}
