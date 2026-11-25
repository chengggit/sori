pragma Singleton

import QtQuick
import QtCore

QtObject {
    property bool webEngineAvailable: false
    readonly property var builtIn: [
        { label: "Naver", template: "https://korean.dict.naver.com/koendict/#/search?query={word}" },
        { label: "Papago", template: "https://papago.naver.com/?sl=ko&tl=en&text={word}" },
        { label: "KRDict", template: "https://krdict.korean.go.kr/m/eng/searchResult?mainSearchWord={word}" }
    ]
    readonly property var providers: builtIn.concat(custom.filter(provider =>
        !builtIn.some(entry => entry.template === provider.template)))
    readonly property var enabled: providers.filter(provider => !disabled.includes(provider.template))

    readonly property var custom: JSON.parse(preferences.custom)
    readonly property var disabled: JSON.parse(preferences.disabled)

    property Settings store: Settings {
        id: preferences
        category: "DictionaryTabs"
        property string custom: "[]"
        property string disabled: "[]"
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
