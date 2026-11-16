cmake_minimum_required(VERSION 3.21)
project(Sori LANGUAGES CXX)

find_package(Qt6 6.10 REQUIRED COMPONENTS Quick OpenGL Test)
find_package(PkgConfig REQUIRED)
find_program(CARGO_EXECUTABLE cargo REQUIRED)
pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)
get_target_property(SORI_QMAKE Qt6::qmake IMPORTED_LOCATION)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

add_executable(sori
    src/main.cpp
    src/videoitem.cpp src/videoitem.h
)
target_compile_definitions(sori PRIVATE SORI_KIWI_DIR="${CMAKE_CURRENT_SOURCE_DIR}/resources/kiwi")
option(SORI_QML_PREVIEW "Enable QML live preview for local development" OFF)
if(SORI_QML_PREVIEW)
    if(Qt6_VERSION VERSION_LESS 6.12)
        message(FATAL_ERROR "SORI_QML_PREVIEW requires Qt 6.12 or newer")
    endif()
    target_compile_definitions(sori PRIVATE QT_QML_DEBUG)
    get_filename_component(SORI_QT_BIN "${SORI_QMAKE}" DIRECTORY)
    find_program(SORI_QML_PREVIEW_EXECUTABLE NAMES qmlpreview qmlpreview-qt6
        HINTS "${SORI_QT_BIN}" NO_DEFAULT_PATH REQUIRED)
    add_custom_target(qml-preview
        COMMAND "${SORI_QML_PREVIEW_EXECUTABLE}"
            --resource "${CMAKE_CURRENT_BINARY_DIR}/.qt/rcc/watch.qrc"
            "$<TARGET_FILE:sori>"
        DEPENDS sori
        USES_TERMINAL
        VERBATIM
    )
endif()
set(PLAYBACK_DIR "${CMAKE_CURRENT_SOURCE_DIR}/playback")
set(PLAYBACK_TARGET "${CMAKE_CURRENT_BINARY_DIR}/cargo")
set(PLAYBACK_LIB "${PLAYBACK_TARGET}/release/${CMAKE_STATIC_LIBRARY_PREFIX}sori_qt_playback${CMAKE_STATIC_LIBRARY_SUFFIX}")
add_custom_command(OUTPUT "${PLAYBACK_LIB}"
    COMMAND "${CMAKE_COMMAND}" -E env "QMAKE=${SORI_QMAKE}"
        "${CARGO_EXECUTABLE}" build --release --locked
        --manifest-path "${PLAYBACK_DIR}/Cargo.toml" --target-dir "${PLAYBACK_TARGET}"
    DEPENDS "${SORI_QMAKE}" "${PLAYBACK_DIR}/src/player_model.rs" "${PLAYBACK_DIR}/src/subtitle_model.rs"
        "${PLAYBACK_DIR}/Cargo.toml" "${PLAYBACK_DIR}/Cargo.lock" "${PLAYBACK_DIR}/src/lib.rs" "${PLAYBACK_DIR}/src/subtitles.rs" "${PLAYBACK_DIR}/src/controls.rs"
        "${PLAYBACK_DIR}/src/db.rs" "${PLAYBACK_DIR}/src/schema.sql" "${PLAYBACK_DIR}/src/documents.rs"
        "${PLAYBACK_DIR}/src/progress.rs" "${PLAYBACK_DIR}/src/library_model.rs"
        "${PLAYBACK_DIR}/src/nlp.rs" "${PLAYBACK_DIR}/src/reader.rs" "${PLAYBACK_DIR}/src/analysis_model.rs"
        "${PLAYBACK_DIR}/src/video_library.rs"
        "${PLAYBACK_DIR}/src/dictionary.rs" "${PLAYBACK_DIR}/src/vocabulary.rs"
    VERBATIM
)
add_custom_target(sori-qt-playback DEPENDS "${PLAYBACK_LIB}")
add_dependencies(sori sori-qt-playback)
target_link_libraries(sori PRIVATE "${PLAYBACK_LIB}" Qt6::Quick Qt6::OpenGL Qt6::Test PkgConfig::MPV)
qt_add_resources(sori "watch" PREFIX "/" FILES
    qml/Main.qml
    qml/Theme.js
    qml/components/AppButton.qml
    qml/components/AppInput.qml
    qml/components/AppSidebar.qml
    qml/components/AppText.qml
    qml/components/DocumentEditor.qml
    qml/components/EmptyState.qml
    qml/components/Icon.qml
    qml/components/PageHeader.qml
    qml/components/VocabularyEditor.qml
    qml/components/WordAnalysis.qml
    qml/icons/arrow-left.svg
    qml/icons/book-open.svg
    qml/icons/bookmark.svg
    qml/icons/chevron-down.svg
    qml/icons/clock.svg
    qml/icons/compass.svg
    qml/icons/file-text.svg
    qml/icons/film.svg
    qml/icons/folder-open.svg
    qml/icons/history.svg
    qml/icons/house.svg
    qml/icons/library.svg
    qml/icons/panel-left.svg
    qml/icons/pencil.svg
    qml/icons/play.svg
    qml/icons/plus.svg
    qml/icons/search.svg
    qml/icons/settings.svg
    qml/icons/upload.svg
    qml/icons/x.svg
    qml/pages/ExplorePage.qml
    qml/pages/HistoryPage.qml
    qml/pages/HomePage.qml
    qml/pages/LibraryPage.qml
    qml/pages/ReaderPage.qml
    qml/pages/SettingsSheet.qml
    qml/pages/VocabularyPage.qml
    qml/pages/WatchPage.qml
    assets/Inter-Variable.ttf assets/NotoSansKR-Regular.otf
)
