pragma Singleton
import QtQuick

QtObject {
    signal dictionarySettingsChanged
    signal finished(int request, var result)
    signal dictionaryFinished(int request, var result)
}
