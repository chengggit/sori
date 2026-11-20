import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../style"

// Read-only details panel for a saved vocabulary entry. Kept separate from
// ReaderAnalysis because this view is about the saved word, its context, and
// its source rather than live dictionary lookup.
Rectangle {
    id: root

    property var entry: null
    signal closeRequested()

    readonly property string word: {
        const normalized = (entry?.normalizedForm ?? "").trim();
        return normalized !== "" && normalized !== entry?.word
            ? normalized : (entry?.word ?? "");
    }
    readonly property string hanja: (entry?.definition?.hanja ?? "").trim()
    readonly property string partOfSpeech: {
        const value = (entry?.definition?.partOfSpeech ?? "").trim().toLowerCase();
        if (value !== "")
            return value;
        const classes = ["noun", "verb", "adjective", "adverb", "pronoun",
            "determiner", "particle", "conjunction", "interjection", "numeral"];
        for (const tag of entry?.tags ?? []) {
            const normalized = tag.trim().toLowerCase().replace(/s$/, "");
            if (classes.indexOf(normalized) >= 0)
                return normalized;
        }
        return "";
    }
    readonly property string meta: {
        const parts = [];
        if (hanja !== "")
            parts.push(hanja);
        if (partOfSpeech !== "")
            parts.push(partOfSpeech.charAt(0).toUpperCase() + partOfSpeech.slice(1));
        return parts.join(" · ");
    }
    readonly property string definition: (entry?.definition?.text ?? "").trim()
    readonly property string note: (entry?.definition?.note ?? "").trim()
    readonly property string context: (entry?.context ?? "").trim()
    readonly property string sourceTitle: (entry?.sourceTitle ?? "").trim()
    readonly property bool sourceIsText: entry?.documentId !== null
        && entry?.documentId !== undefined
    readonly property string savedDate: {
        const timestamp = Number(entry?.createdAt);
        if (!timestamp)
            return "";
        const saved = new Date(timestamp * 1000);
        const now = new Date();
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const savedDay = new Date(saved.getFullYear(), saved.getMonth(), saved.getDate());
        const days = Math.round((today - savedDay) / 86400000);
        if (days <= 0)
            return "Today";
        if (days === 1)
            return "Yesterday";
        if (days < 7)
            return days + " days ago";
        return Qt.formatDate(saved, saved.getFullYear() === now.getFullYear() ? "MMM d" : "MMM d, yyyy");
    }

    color: Theme.card

    // Absorb pointer input so the page underneath cannot be interacted with
    // through the panel. Interactive controls are declared after this item.
    MouseArea {
        anchors.fill: parent
    }

    Rectangle {
        anchors.left: parent.left
        width: 1
        height: parent.height
        color: Theme.border
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 18
            Layout.topMargin: 18
            Layout.bottomMargin: 14
            spacing: 8

            AppText {
                Layout.fillWidth: true
                text: "Word details"
                color: Theme.mutedForeground
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            AppButton {
                iconName: "x"
                iconSize: 16
                variant: "ghost"
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Accessible.name: "Close word details"
                onClicked: root.closeRequested()
            }
        }

        AppScrollView {
            id: scroll

            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: scroll.availableWidth
                spacing: 0

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.topMargin: 6
                    Layout.bottomMargin: 32
                    spacing: 0

                    AppText {
                        Layout.fillWidth: true
                        text: root.word
                        korean: true
                        font.pixelSize: 24
                        font.weight: Font.DemiBold
                        wrapMode: Text.Wrap
                    }

                    AppText {
                        visible: text !== ""
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        text: root.meta
                        color: Theme.mutedForeground
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        Layout.topMargin: 20
                        color: Theme.border
                    }

                    AppText {
                        text: "Definition"
                        Layout.topMargin: 18
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    AppText {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        visible: root.definition !== ""
                        text: root.definition
                        font.pixelSize: 14
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 22
                        wrapMode: Text.Wrap
                    }

                    AppText {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        visible: root.definition === ""
                        text: "No definition saved."
                        color: Theme.mutedForeground
                        font.pixelSize: 14
                    }

                    AppText {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        visible: root.note !== ""
                        text: root.note
                        color: Theme.mutedForeground
                        font.pixelSize: 13
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 20
                        wrapMode: Text.Wrap
                    }

                    Rectangle {
                        visible: root.context !== ""
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        Layout.topMargin: 22
                        color: Theme.border
                    }

                    AppText {
                        visible: root.context !== ""
                        text: "Context"
                        Layout.topMargin: 18
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    AppText {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        visible: root.context !== ""
                        text: root.context
                        korean: true
                        font.pixelSize: 14
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 23
                        wrapMode: Text.Wrap
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        Layout.topMargin: 22
                        color: Theme.border
                    }

                    AppText {
                        text: "Source"
                        Layout.topMargin: 18
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        spacing: 8

                        Icon {
                            name: root.sourceIsText ? "book-open" : "film"
                            size: 15
                            color: Theme.mutedForeground
                        }

                        AppText {
                            Layout.fillWidth: true
                            text: root.sourceTitle !== "" ? root.sourceTitle : "Saved word"
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }
                    }

                    AppText {
                        visible: root.savedDate !== ""
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        text: root.savedDate === "" ? "" : "Saved " + root.savedDate
                        color: Theme.mutedForeground
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
