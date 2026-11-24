import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import sori_core
import "../style"
import "../components"

Popup {
    id: root

    property string category: "general"
    readonly property int categoryIndex: ({
        general: 0, dictionaries: 1, channels: 2, connections: 3
    })[root.category] ?? 0
    readonly property bool compact: parent && parent.width < 600
    readonly property var categories: [
        { id: "general", label: "General", icon: "settings" },
        { id: "dictionaries", label: "Dictionaries", icon: "book-open" },
        { id: "channels", label: "Channels", icon: "play" },
        { id: "connections", label: "Connections", icon: "link" }
    ]

    property bool krdictExpanded: false
    readonly property bool showKrdictFields: Analysis.defaultDictionary === "krdict"
        || Analysis.krdictConfigured || root.krdictExpanded

    property string dictionaryError: ""
    property string youtubeError: ""
    property string youtubeMessage: ""
    property string krdictError: ""
    property string krdictMessage: ""
    property string channelError: ""
    property string channelMessage: ""

    function resetScroll() {
        for (const page of [generalPage, dictionariesPage, channelsPage, connectionsPage]) {
            if (page.flickableItem)
                page.flickableItem.contentY = 0
        }
    }

    onOpened: {
        root.category = "general"
        root.krdictExpanded = false
        root.resetScroll()
        youtubeKey.clear()
        youtubeError = YouTube.settingsError
        youtubeMessage = ""
        krdictKey.text = Analysis.krdictKey
        krdictError = Analysis.dictionarySettingsError
        krdictMessage = ""
        channelInput.clear()
        channelError = ""
        channelMessage = ""
    }
    onClosed: { youtubeKey.clear(); krdictKey.clear(); channelInput.clear() }
    onCategoryChanged: root.resetScroll()

    function saveKrdictKey() {
        krdictMessage = ""
        if (!krdictKey.text.trim()) {
            krdictError = Analysis.removeKrdictKey()
            if (!krdictError) {
                krdictKey.clear()
                krdictMessage = "KRDict key removed."
            }
            return
        }
        krdictError = Analysis.saveKrdictKey(krdictKey.text)
        if (!krdictError) {
            krdictKey.text = Analysis.krdictKey
            krdictMessage = "KRDict API key saved."
        }
    }

    function addChannel() {
        const text = channelInput.text.trim()
        if (!text)
            return
        const result = YouTube.resolveChannel(text)
        channelError = result.error ?? ""
        channelMessage = ""
        if (channelError)
            return
        channelError = YouTube.addSubscription(
            result.channelId, result.title, result.uploadsPlaylistId)
        if (!channelError) {
            channelInput.clear()
            channelMessage = result.title + " added."
        }
    }

    function removeChannel(id) {
        channelError = YouTube.removeSubscription(id)
        channelMessage = channelError ? "" : "Channel removed."
    }

    function saveYoutubeKey() {
        youtubeError = YouTube.saveApiKey(youtubeKey.text)
        youtubeMessage = ""
        if (!youtubeError) {
            youtubeKey.clear()
            youtubeMessage = "API key saved."
        }
    }

    width: Math.min(720, parent ? parent.width - 40 : 720)
    height: Math.min(560, parent ? parent.height - 32 : 560)
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    function addDictionary() {
        const label = labelField.text.trim()
        const template = urlField.text.trim()
        if (!label || !template)
            return
        if (!Analysis.dictionaryLookupUrl(template, "test")) {
            dictionaryError = "Enter an HTTPS address without a username or password."
        } else if (DictionaryTabs.providers.some(provider => provider.template === template)) {
            dictionaryError = "That dictionary is already listed."
        } else {
            DictionaryTabs.add(label, template)
            dictionaryError = ""
            labelField.clear()
            urlField.clear()
        }
    }

    component SettingsCheck: CheckBox {
        id: check

        Layout.fillWidth: true
        Layout.preferredHeight: 24
        spacing: 8
        padding: 0
        hoverEnabled: true

        contentItem: AppText {
            leftPadding: check.indicator.width + check.spacing
            text: check.text
            font.pixelSize: 14
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        indicator: Rectangle {
            x: check.leftPadding
            y: (check.height - height) / 2
            implicitWidth: 16
            implicitHeight: 16
            radius: 4
            color: check.checked ? Theme.accent : Theme.card
            border.width: check.checked ? 0 : 1
            border.color: check.hovered ? Theme.mutedForeground : Theme.border

            Shape {
                anchors.fill: parent
                visible: check.checked
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 2
                    strokeColor: Theme.dark ? "#000000" : "#ffffff"
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: "M 4 8 L 7 11 L 12 5" }
                }
            }
        }
    }

    component CategoryButton: AppButton {
        id: button

        required property var entry
        objectName: "settingsCategory" + entry.id
        text: entry.label
        iconName: entry.icon
        variant: root.category === entry.id ? "soft" : "ghost"
        small: true
        leftPadding: 10
        rightPadding: 8
        Layout.fillWidth: !root.compact
        Accessible.name: entry.label
        onClicked: root.category = entry.id

        contentItem: RowLayout {
            spacing: 8

            Icon {
                name: entry.icon
                size: 14
                color: button.contentColor
            }

            AppText {
                Layout.fillWidth: true
                text: entry.label
                color: button.contentColor
                font.pixelSize: 13
                font.weight: button.variant === "soft" ? Font.DemiBold : Font.Normal
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
    }

    background: Rectangle {
        radius: Theme.radiusLarge
        color: Theme.card
        border.width: 0
    }

    contentItem: ColumnLayout {
        spacing: 0

        RowLayout {
            id: header
            Layout.fillWidth: true
            Layout.margins: 20
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                AppText {
                    Layout.fillWidth: true
                    text: "Settings"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }

            }

            AppButton {
                text: ""
                iconName: "x"
                variant: "ghost"
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                Accessible.name: "Close settings"
                onClicked: root.close()
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            ColumnLayout {
                id: sidebar
                visible: !root.compact
                Layout.preferredWidth: 170
                Layout.fillHeight: true
                Layout.margins: 16
                spacing: 4

                CategoryButton { entry: root.categories[0] }
                CategoryButton { entry: root.categories[1] }
                CategoryButton { entry: root.categories[2] }
                CategoryButton { entry: root.categories[3] }

                Item { Layout.fillHeight: true }
            }

            Rectangle {
                visible: !root.compact
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: Theme.border
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                RowLayout {
                    visible: root.compact
                    Layout.fillWidth: true
                    Layout.margins: 12
                    Layout.bottomMargin: 4
                    spacing: 4

                    CategoryButton { entry: root.categories[0] }
                    CategoryButton { entry: root.categories[1] }
                    CategoryButton { entry: root.categories[2] }
                    CategoryButton { entry: root.categories[3] }
                }

                StackLayout {
                    id: pages
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.categoryIndex

                    // -- General -------------------------------------------
                    AppScrollView {
                        id: generalPage
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: availableWidth
                        contentHeight: generalForm.implicitHeight + 40
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        ColumnLayout {
                            id: generalForm
                            x: 20
                            y: 20
                            width: generalPage.availableWidth - 40
                            spacing: 20

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                AppText {
                                    text: "Appearance"
                                    font.weight: Font.DemiBold
                                }

                                ComboBox {
                                    id: appearance
                                    Layout.fillWidth: true
                                    implicitHeight: Theme.inputHeight
                                    leftPadding: 12
                                    rightPadding: 36
                                    topPadding: 0
                                    bottomPadding: 0
                                    Accessible.name: "Appearance"
                                    model: [
                                        { value: "system", label: "System" },
                                        { value: "light", label: "Light" },
                                        { value: "dark", label: "Dark" }
                                    ]
                                    textRole: "label"
                                    valueRole: "value"
                                    currentIndex: Math.max(0, model.findIndex(entry => entry.value === Theme.appearance))
                                    onActivated: index => Theme.appearance = model[index].value

                                    contentItem: AppText {
                                        text: appearance.displayText
                                        font.pixelSize: 13
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    indicator: Icon {
                                        x: appearance.width - width - 12
                                        y: (appearance.height - height) / 2
                                        name: "chevron-down"
                                        size: 14
                                        color: Theme.mutedForeground
                                    }

                                    background: Rectangle {
                                        radius: Theme.radius
                                        color: Theme.card
                                        border.width: appearance.activeFocus ? 2 : 1
                                        border.color: appearance.activeFocus ? Theme.accent : Theme.border
                                    }

                                    delegate: ItemDelegate {
                                        required property int index
                                        width: appearance.width - appearance.popup.leftPadding - appearance.popup.rightPadding
                                        implicitHeight: Theme.compactControlHeight
                                        padding: 8
                                        highlighted: appearance.highlightedIndex === index
                                        hoverEnabled: true

                                        contentItem: AppText {
                                            text: appearance.textAt(index)
                                            font.pixelSize: 13
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        background: Rectangle {
                                            radius: Theme.radiusSmall
                                            color: parent.highlighted || parent.hovered ? Theme.neutralHover : "transparent"
                                        }
                                    }

                                    popup: Popup {
                                        y: appearance.height + 4
                                        width: appearance.width
                                        padding: 4

                                        background: Rectangle {
                                            color: Theme.card
                                            radius: Theme.radius
                                            border.width: 1
                                            border.color: Theme.border
                                        }

                                        contentItem: ListView {
                                            implicitHeight: contentHeight
                                            model: appearance.delegateModel
                                            currentIndex: appearance.highlightedIndex
                                            clip: true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // -- Dictionaries --------------------------------------
                    AppScrollView {
                        id: dictionariesPage
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: availableWidth
                        contentHeight: dictionariesForm.implicitHeight + 40
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        ColumnLayout {
                            id: dictionariesForm
                            x: 20
                            y: 20
                            width: dictionariesPage.availableWidth - 40
                            spacing: 20

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                AppText {
                                    text: "Analysis dictionary"
                                    font.weight: Font.DemiBold
                                }

                                ComboBox {
                                    id: analysisDictionary
                                    objectName: "analysisDictionarySelector"
                                    Layout.fillWidth: true
                                    implicitHeight: Theme.inputHeight
                                    model: [{value: "wiktionary", label: "Wiktionary"}, {value: "krdict", label: "KRDict"}]
                                    textRole: "label"
                                    currentIndex: Analysis.defaultDictionary === "krdict" ? 1 : 0
                                    Accessible.name: "Default Analysis dictionary"
                                    leftPadding: 12
                                    rightPadding: 32
                                    onActivated: index => {
                                        root.krdictError = Analysis.setDefaultDictionary(model[index].value)
                                        root.krdictMessage = ""
                                        currentIndex = Qt.binding(() => Analysis.defaultDictionary === "krdict" ? 1 : 0)
                                    }
                                    contentItem: AppText {
                                        text: analysisDictionary.displayText
                                        font.pixelSize: 13
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    indicator: Icon {
                                        name: "chevron-down"
                                        size: 14
                                        x: analysisDictionary.width - width - 12
                                        y: (analysisDictionary.height - height) / 2
                                        color: Theme.mutedForeground
                                    }
                                    background: Rectangle {
                                        color: Theme.card
                                        radius: Theme.radius
                                        border.color: analysisDictionary.activeFocus ? Theme.accent : Theme.border
                                    }
                                    delegate: ItemDelegate {
                                        required property int index
                                        width: analysisDictionary.width - 8
                                        height: Theme.compactControlHeight
                                        highlighted: analysisDictionary.highlightedIndex === index
                                        contentItem: AppText { text: analysisDictionary.textAt(index); font.pixelSize: 13 }
                                        background: Rectangle {
                                            radius: Theme.radiusSmall
                                            color: parent.highlighted || parent.hovered ? Theme.neutralHover : "transparent"
                                        }
                                    }
                                    popup: Popup {
                                        y: analysisDictionary.height + 4
                                        width: analysisDictionary.width
                                        padding: 4
                                        background: Rectangle { color: Theme.card; border.color: Theme.border; radius: Theme.radius }
                                        contentItem: ListView {
                                            implicitHeight: contentHeight
                                            model: analysisDictionary.delegateModel
                                            currentIndex: analysisDictionary.highlightedIndex
                                            clip: true
                                        }
                                    }
                                }

                                AppText {
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    font.pixelSize: 12
                                    color: Theme.mutedForeground
                                    text: "Used for Analysis definitions and quick word lookups. Wiktionary needs no key."
                                }

                                AppButton {
                                    visible: !root.showKrdictFields
                                    text: "Set up KRDict key"
                                    variant: "outline"
                                    small: true
                                    onClicked: root.krdictExpanded = true
                                }

                                AppText {
                                    text: "KRDict API key"
                                    font.weight: Font.Medium
                                    visible: root.showKrdictFields
                                }
                                AppInput {
                                    id: krdictKey
                                    objectName: "krdictApiKeyInput"
                                    Layout.fillWidth: true
                                    visible: root.showKrdictFields
                                    echoMode: TextInput.Password
                                    placeholderText: Analysis.krdictConfigured ? "••••••••••••••••" : "Paste your 32-character KRDict key"
                                    Accessible.name: "KRDict API key"
                                    inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                                    onEditingFinished: root.saveKrdictKey()
                                }
                                AppText {
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    text: root.krdictError
                                    visible: root.showKrdictFields && text !== ""
                                    font.pixelSize: 12
                                    color: root.krdictError ? Theme.destructive : Theme.mutedForeground
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                AppText {
                                    text: "Embedded lookup tabs"
                                    font.weight: Font.DemiBold
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Repeater {
                                        model: DictionaryTabs.providers

                                        delegate: RowLayout {
                                            required property var modelData
                                            required property int index
                                            Layout.fillWidth: true
                                            spacing: Theme.controlGap

                                            SettingsCheck {
                                                text: parent.modelData.label
                                                checked: DictionaryTabs.enabled.some(provider => provider.template === parent.modelData.template)
                                                onToggled: DictionaryTabs.setEnabled(parent.modelData.template, checked)
                                            }

                                            AppButton {
                                                visible: parent.index >= 2
                                                iconName: "x"
                                                variant: "ghost"
                                                Layout.preferredWidth: 24
                                                Layout.preferredHeight: 24
                                                Accessible.name: "Remove " + parent.modelData.label
                                                onClicked: DictionaryTabs.remove(parent.modelData.template)
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 4
                                    spacing: Theme.controlGap

                                    AppInput {
                                        id: labelField
                                        Layout.preferredWidth: 120
                                        placeholderText: "Name"
                                        Accessible.name: placeholderText
                                    }

                                    AppInput {
                                        id: urlField
                                        Layout.fillWidth: true
                                        placeholderText: "HTTPS URL with {word}"
                                        Accessible.name: placeholderText
                                        onAccepted: root.addDictionary()
                                    }

                                    AppButton {
                                        text: ""
                                        iconName: "plus"
                                        variant: "outline"
                                        Layout.preferredWidth: Theme.inputHeight
                                        Layout.preferredHeight: Theme.inputHeight
                                        Accessible.name: "Add dictionary"
                                        enabled: !!labelField.text.trim() && !!urlField.text.trim()
                                        onClicked: root.addDictionary()
                                    }
                                }

                                AppText {
                                    visible: !!root.dictionaryError
                                    text: root.dictionaryError
                                    color: Theme.destructive
                                    font.pixelSize: 12
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }

                                AppText {
                                    text: "Use {word} for the selected word. HTTPS URLs are supported."
                                    color: Theme.mutedForeground
                                    font.pixelSize: 12
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    // -- Channels ------------------------------------------
                    AppScrollView {
                        id: channelsPage
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: availableWidth
                        contentHeight: channelsForm.implicitHeight + 40
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        ColumnLayout {
                            id: channelsForm
                            x: 20
                            y: 20
                            width: channelsPage.availableWidth - 40
                            spacing: 8

                            AppText {
                                text: "Subscribed channels"
                                font.weight: Font.DemiBold
                            }
                            AppText {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                font.pixelSize: 12
                                color: Theme.mutedForeground
                                text: "Home shows the newest uploads from these channels."
                            }

                            AppInput {
                                id: channelInput
                                objectName: "channelInput"
                                Layout.fillWidth: true
                                placeholderText: "Channel link, @handle, or name"
                                Accessible.name: "YouTube channel"
                                onAccepted: root.addChannel()
                            }
                            AppButton {
                                objectName: "addChannel"
                                text: "Add channel"
                                variant: "outline"
                                small: true
                                enabled: !!channelInput.text.trim()
                                onClicked: root.addChannel()
                            }

                            AppText {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                font.pixelSize: 12
                                text: root.channelError || root.channelMessage
                                visible: text !== ""
                                color: root.channelError ? Theme.destructive : Theme.mutedForeground
                            }

                            Repeater {
                                model: YouTube.subscriptions ?? []

                                RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: Theme.controlGap

                                    AppText {
                                        Layout.fillWidth: true
                                        text: modelData.title
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                    }
                                    AppButton {
                                        iconName: "x"
                                        variant: "ghost"
                                        small: true
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 24
                                        Accessible.name: "Remove " + modelData.title
                                        onClicked: root.removeChannel(modelData.channelId)
                                    }
                                }
                            }
                        }
                    }

                    // -- Connections ---------------------------------------
                    AppScrollView {
                        id: connectionsPage
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: availableWidth
                        contentHeight: connectionsForm.implicitHeight + 40
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        ColumnLayout {
                            id: connectionsForm
                            x: 20
                            y: 20
                            width: connectionsPage.availableWidth - 40
                            spacing: 8

                            AppText {
                                text: "YouTube API key"
                                font.weight: Font.DemiBold
                            }
                            AppText {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                font.pixelSize: 12
                                color: Theme.mutedForeground
                                text: YouTube.savedKey ? "A key is saved on this device. Enter a new key to replace it."
                                    : YouTube.configured ? "Using a key from your launch environment or .env.local."
                                    : "Add your YouTube Data API key to enable Home and Explore discovery."
                            }
                            AppInput {
                                id: youtubeKey
                                objectName: "youtubeApiKeyInput"
                                Layout.fillWidth: true
                                echoMode: TextInput.Password
                                placeholderText: YouTube.savedKey ? "Enter a replacement API key" : "Paste your API key"
                                Accessible.name: "YouTube API key"
                                inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                                onAccepted: if (text.trim()) root.saveYoutubeKey()
                            }
                            RowLayout {
                                AppButton {
                                    objectName: "removeYoutubeApiKey"
                                    text: "Remove saved key"
                                    small: true
                                    variant: "outline"
                                    visible: YouTube.savedKey
                                    onClicked: {
                                        root.youtubeError = YouTube.removeApiKey()
                                        root.youtubeMessage = ""
                                        if (!root.youtubeError) {
                                            youtubeKey.clear()
                                            root.youtubeMessage = YouTube.configured
                                                ? "Saved key removed. Using the environment key."
                                                : "Saved key removed."
                                        }
                                    }
                                }
                            }
                            AppText {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                font.pixelSize: 12
                                text: root.youtubeError || root.youtubeMessage
                                visible: text !== ""
                                color: root.youtubeError ? Theme.destructive : Theme.mutedForeground
                            }
                            AppText {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                font.pixelSize: 12
                                color: Theme.mutedForeground
                                text: "Saved on this device. An API key isn't needed for transcript fetching or opening YouTube links."
                            }
                        }
                    }
                }
            }
        }
    }
}
