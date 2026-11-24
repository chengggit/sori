cmake_minimum_required(VERSION 3.21)
project(Sori LANGUAGES CXX)

find_package(Qt6 6.10 REQUIRED COMPONENTS Quick OpenGL Test Pdf PdfQuick)
option(SORI_REQUIRE_WEBENGINE "Require embedded YouTube and dictionary support" OFF)
if(SORI_REQUIRE_WEBENGINE)
    find_package(Qt6 6.10 REQUIRED COMPONENTS WebEngineQuick)
else()
    find_package(Qt6 6.10 QUIET OPTIONAL_COMPONENTS WebEngineQuick)
endif()
find_package(PkgConfig REQUIRED)
find_program(CARGO_EXECUTABLE cargo REQUIRED)
pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)
get_target_property(SORI_QMAKE Qt6::qmake IMPORTED_LOCATION)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

add_executable(sori
    src/main.cpp
    src/pdftext.cpp src/pdftext.h
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
set(CORE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/core")
set(CORE_TARGET "${CMAKE_CURRENT_BINARY_DIR}/cargo")
set(CORE_PROFILE "$<IF:$<CONFIG:Debug>,dev,$<IF:$<CONFIG:RelWithDebInfo>,release-with-debug,release>>")
set(CORE_PROFILE_DIR "$<IF:$<CONFIG:Debug>,debug,$<IF:$<CONFIG:RelWithDebInfo>,release-with-debug,release>>")
set(CORE_LIB "${CORE_TARGET}/${CORE_PROFILE_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}sori_core${CMAKE_STATIC_LIBRARY_SUFFIX}")
add_custom_command(OUTPUT "${CORE_LIB}"
    COMMAND "${CMAKE_COMMAND}" -E env "QMAKE=${SORI_QMAKE}"
        "${CARGO_EXECUTABLE}" build --profile "${CORE_PROFILE}" --locked
        --manifest-path "${CORE_DIR}/Cargo.toml" --target-dir "${CORE_TARGET}"
    DEPENDS "${SORI_QMAKE}" "${CORE_DIR}/src/player_model.rs" "${CORE_DIR}/src/subtitle_model.rs"
        "${CORE_DIR}/Cargo.toml" "${CORE_DIR}/Cargo.lock" "${CORE_DIR}/src/lib.rs" "${CORE_DIR}/src/subtitles.rs" "${CORE_DIR}/src/controls.rs"
        "${CORE_DIR}/src/db.rs" "${CORE_DIR}/src/schema.sql" "${CORE_DIR}/src/documents.rs"
        "${CORE_DIR}/src/process.rs" "${CORE_DIR}/src/progress.rs" "${CORE_DIR}/src/library_model.rs"
        "${CORE_DIR}/src/nlp.rs" "${CORE_DIR}/src/reader.rs" "${CORE_DIR}/src/analysis_model.rs"
        "${CORE_DIR}/src/video_library.rs" "${CORE_DIR}/src/video_transcript.rs"
        "${CORE_DIR}/src/dictionary.rs" "${CORE_DIR}/src/krdict.rs" "${CORE_DIR}/src/vocabulary.rs"
        "${CORE_DIR}/src/youtube.rs" "${CORE_DIR}/src/youtube_transcript.rs"
        "${CMAKE_CURRENT_SOURCE_DIR}/scripts/youtube_transcript.py"
    VERBATIM
)
add_custom_target(sori-core DEPENDS "${CORE_LIB}")
add_dependencies(sori sori-core)

enable_testing()
add_test(NAME rust
    COMMAND "${CMAKE_COMMAND}" -E env "QMAKE=${SORI_QMAKE}"
        "${CARGO_EXECUTABLE}" test --locked
        --manifest-path "${CORE_DIR}/Cargo.toml" --target-dir "${CORE_TARGET}"
)
target_link_libraries(sori PRIVATE "${CORE_LIB}" Qt6::Quick Qt6::OpenGL Qt6::Test Qt6::PdfQuick PkgConfig::MPV)
if(TARGET Qt6::WebEngineQuick)
    target_link_libraries(sori PRIVATE Qt6::WebEngineQuick)
    target_compile_definitions(sori PRIVATE SORI_WEB_ENGINE)
endif()
qt_add_resources(sori "watch" PREFIX "/" FILES
    qml/Main.qml
    qml/style/Theme.qml
    qml/style/DictionaryTabs.qml
    qml/style/qmldir
    qml/components/AppButton.qml
    qml/components/DictionaryLookup.qml
    qml/components/DictionaryLookupView.qml
    qml/components/DictionaryWebView.qml
    qml/components/DictionarySettings.qml
    qml/components/AppInput.qml
    qml/components/AppSidebar.qml
    qml/components/AppScrollBar.qml
    qml/components/AppScrollView.qml
    qml/components/AppText.qml
    qml/components/DocumentEditor.qml
    qml/components/EmptyState.qml
    qml/components/Icon.qml
    qml/components/MediaCard.qml
    qml/components/MediaShelf.qml
    qml/components/PageFrame.qml
    qml/components/PageHeader.qml
    qml/components/PdfPageReader.qml
    qml/components/PdfBookReader.qml
    qml/components/VocabularyEditor.qml
    qml/components/VocabularyDetails.qml
    qml/components/VocabularyForm.qml
    qml/components/WordAnalysis.qml
    qml/components/UntimedTranscript.qml
    qml/components/SubtitleTranscript.qml
    qml/components/SubtitleDefinition.qml
    qml/components/ReaderAnalysis.qml
    qml/components/ReaderDefinitions.qml
    qml/icons/arrow-left.svg
    qml/icons/arrow-up-down.svg
    qml/icons/book-open.svg
    qml/icons/bookmark.svg
    qml/icons/bookmark-filled.svg
    qml/icons/check.svg
    qml/icons/chevron-down.svg
    qml/icons/clock.svg
    qml/icons/compass.svg
    qml/icons/ellipsis-vertical.svg
    qml/icons/file-text.svg
    qml/icons/film.svg
    qml/icons/folder-open.svg
    qml/icons/history.svg
    qml/icons/house.svg
    qml/icons/library.svg
    qml/icons/link.svg
    qml/icons/maximize.svg
    qml/icons/minimize.svg
    qml/icons/pause.svg
    qml/icons/panel-left.svg
    qml/icons/pencil.svg
    qml/icons/play.svg
    qml/icons/play-filled.svg
    qml/icons/plus.svg
    qml/icons/refresh.svg
    qml/icons/search.svg
    qml/icons/settings.svg
    qml/icons/trash.svg
    qml/icons/upload.svg
    qml/icons/volume.svg
    qml/icons/volume-x.svg
    qml/icons/x.svg
    qml/pages/ExplorePage.qml
    qml/pages/HistoryPage.qml
    qml/pages/HomePage.qml
    qml/pages/LibraryPage.qml
    qml/pages/ReaderPage.qml
    qml/pages/SettingsSheet.qml
    qml/pages/VocabularyPage.qml
    qml/pages/WatchPage.qml
    qml/pages/YouTubeWatchPage.qml
    qml/pages/YouTubeEmbed.qml
    assets/Inter-Variable.ttf assets/NotoSansKR-Regular.otf
)

include(scripts/bundle-youtube.cmake)
install(TARGETS sori RUNTIME DESTINATION bin)
