cmake_minimum_required(VERSION 3.21)
project(Sori LANGUAGES CXX)

find_package(Qt6 6.10 REQUIRED COMPONENTS Quick OpenGL Test Pdf PdfQuick)
option(SORI_REQUIRE_WEBENGINE "Require embedded YouTube and dictionary support" OFF)
if(SORI_REQUIRE_WEBENGINE)
    find_package(Qt6 6.10 REQUIRED COMPONENTS WebEngineQuick)
else()
    find_package(Qt6 6.10 QUIET OPTIONAL_COMPONENTS WebEngineQuick)
endif()
find_program(CARGO_EXECUTABLE cargo REQUIRED)
if(WIN32)
    set(MPV_ROOT "" CACHE PATH "mpv development files (include/ and lib/mpv.lib)")
    find_path(MPV_INCLUDE_DIR mpv/client.h HINTS "${MPV_ROOT}/include" REQUIRED)
    find_library(MPV_LIBRARY NAMES mpv HINTS "${MPV_ROOT}/lib" REQUIRED)
    add_library(SoriMpv UNKNOWN IMPORTED)
    set_target_properties(SoriMpv PROPERTIES IMPORTED_LOCATION "${MPV_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${MPV_INCLUDE_DIR}")
    set(SORI_MPV_TARGET SoriMpv)
else()
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)
    pkg_get_variable(MPV_HEADER_ROOT mpv includedir)
    find_path(MPV_INCLUDE_DIR mpv/client.h HINTS "${MPV_HEADER_ROOT}" ${MPV_INCLUDE_DIRS} REQUIRED)
    pkg_get_variable(MPV_LIBRARY_ROOT mpv libdir)
    find_library(MPV_LIBRARY NAMES mpv HINTS "${MPV_LIBRARY_ROOT}" ${MPV_LIBRARY_DIRS} REQUIRED)
    # Link the actual library explicitly: an incomplete .pc file must not turn
    # mpv into a headers-only dependency on platforms with non-system prefixes.
    add_library(SoriMpv UNKNOWN IMPORTED)
    set_target_properties(SoriMpv PROPERTIES IMPORTED_LOCATION "${MPV_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${MPV_INCLUDE_DIR}"
        INTERFACE_LINK_LIBRARIES PkgConfig::MPV)
    set(SORI_MPV_TARGET SoriMpv)
    message(STATUS "Using libmpv: ${MPV_LIBRARY}")
endif()
get_target_property(SORI_QMAKE Qt6::qmake IMPORTED_LOCATION)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

add_executable(sori
    src/main.cpp
    src/pdftext.cpp src/pdftext.h
    src/videoitem.cpp src/videoitem.h
)
if(APPLE)
    set_target_properties(sori PROPERTIES MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_GUI_IDENTIFIER "com.sori.app"
        MACOSX_BUNDLE_BUNDLE_NAME "Sori")
endif()
if(WIN32)
    enable_language(RC)
    set_target_properties(sori PROPERTIES WIN32_EXECUTABLE TRUE)
    target_sources(sori PRIVATE packaging/windows/sori.rc)
    target_include_directories(sori PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/packaging/windows")
endif()
option(SORI_ALLOW_DOWNLOADS "Allow project resource downloads during builds (Cargo has its own offline mode)" ON)
option(SORI_PREPARE_KIWI "Prepare pinned Kiwi resources automatically" ON)
set(SORI_KIWI_DIR "${CMAKE_BINARY_DIR}/deps/kiwi" CACHE PATH "Prepared Kiwi library and models")
if(CMAKE_CROSSCOMPILING AND SORI_PREPARE_KIWI)
    message(FATAL_ERROR "Cross builds must supply target Kiwi resources with SORI_PREPARE_KIWI=OFF and SORI_KIWI_DIR.")
endif()
if(WIN32)
    set(_kiwi_library kiwi.dll)
elseif(APPLE)
    set(_kiwi_library libkiwi.dylib)
else()
    set(_kiwi_library libkiwi.so)
endif()
add_custom_target(kiwi-resources
    COMMAND "${CMAKE_COMMAND}" "-DSORI_KIWI_DIR=${SORI_KIWI_DIR}"
        "-DSORI_PREPARE_KIWI=${SORI_PREPARE_KIWI}" "-DSORI_ALLOW_DOWNLOADS=${SORI_ALLOW_DOWNLOADS}"
        "-DKIWI_LIBRARY=${_kiwi_library}" -P "${CMAKE_SOURCE_DIR}/scripts/prepare-kiwi.cmake"
    VERBATIM)
add_dependencies(sori kiwi-resources)
target_compile_definitions(sori PRIVATE SORI_KIWI_DIR="${SORI_KIWI_DIR}")
install(DIRECTORY "${SORI_KIWI_DIR}/" DESTINATION bin/kiwi
    PATTERN "setup.lock" EXCLUDE PATTERN ".setup" EXCLUDE)
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
file(GLOB_RECURSE CORE_SOURCES CONFIGURE_DEPENDS "${CORE_DIR}/src/*.rs" "${CORE_DIR}/src/*.sql"
    "${CORE_DIR}/vendor/kiwi-rs/src/*.rs")
add_custom_command(OUTPUT "${CORE_LIB}"
    COMMAND "${CMAKE_COMMAND}" -E env "QMAKE=${SORI_QMAKE}"
        "${CARGO_EXECUTABLE}" build --profile "${CORE_PROFILE}" --locked
        --manifest-path "${CORE_DIR}/Cargo.toml" --target-dir "${CORE_TARGET}"
    DEPENDS "${SORI_QMAKE}" ${CORE_SOURCES} "${CORE_DIR}/Cargo.toml" "${CORE_DIR}/Cargo.lock"
        "${CORE_DIR}/vendor/kiwi-rs/Cargo.toml"
        "${CMAKE_CURRENT_SOURCE_DIR}/scripts/youtube_transcript.py"
    USES_TERMINAL
    VERBATIM
)
add_custom_target(sori-core DEPENDS "${CORE_LIB}")
add_dependencies(sori sori-core)

include(scripts/bundle-youtube.cmake)

enable_testing()
add_test(NAME rust
    COMMAND "${CMAKE_COMMAND}" -E env "QMAKE=${SORI_QMAKE}"
        "${CARGO_EXECUTABLE}" test --profile "${CORE_PROFILE}" --locked
        --manifest-path "${CORE_DIR}/Cargo.toml" --target-dir "${CORE_TARGET}"
)
option(SORI_TEST_NATIVE_KIWI "Enable tests requiring prepared native Kiwi fixtures" OFF)
if(SORI_TEST_NATIVE_KIWI)
    add_test(NAME kiwi
        COMMAND "${CMAKE_COMMAND}" -E env "QMAKE=${SORI_QMAKE}"
            "${CARGO_EXECUTABLE}" test --profile "${CORE_PROFILE}" --locked
            --manifest-path "${CORE_DIR}/Cargo.toml" --target-dir "${CORE_TARGET}"
            nlp::tests -- --include-ignored --nocapture)
    set_tests_properties(kiwi PROPERTIES TIMEOUT 120)
endif()

add_executable(sori-bridge-test tests/native/bridge_smoke.cpp)
add_dependencies(sori-bridge-test sori-core)
target_link_libraries(sori-bridge-test PRIVATE "${CORE_LIB}" Qt6::Test Qt6::Quick ${SORI_MPV_TARGET})
add_test(NAME bridge COMMAND "${CMAKE_COMMAND}" -E env QT_QPA_PLATFORM=offscreen
    QT_QPA_PLATFORMTHEME= QT_QPA_PLATFORMTHEME_QT6= "$<TARGET_FILE:sori-bridge-test>")
set_tests_properties(bridge PROPERTIES TIMEOUT 20)

# Run UI regressions through the same entry point as core tests.
get_filename_component(SORI_TEST_QT_BIN "${SORI_QMAKE}" DIRECTORY)
find_program(SORI_QML_TEST_RUNNER qmltestrunner HINTS "${SORI_TEST_QT_BIN}" NO_DEFAULT_PATH REQUIRED)
add_test(NAME qml COMMAND "${CMAKE_COMMAND}" -E env
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic
    QT_QPA_PLATFORMTHEME= QT_QPA_PLATFORMTHEME_QT6=
    "${SORI_QML_TEST_RUNNER}" -import "${CMAKE_SOURCE_DIR}/tests/qml/mocks"
    -input "${CMAKE_SOURCE_DIR}/tests/qml")
set_tests_properties(qml PROPERTIES TIMEOUT 90)

# Use the managed helper environment for tests, or an existing development environment.
if(SORI_BUNDLE_TRANSCRIPT_HELPER)
    set(_sori_test_python "${_sori_helper_python}")
elseif(WIN32)
    set(_sori_test_python "${CMAKE_SOURCE_DIR}/.venv-youtube/Scripts/python.exe")
else()
    set(_sori_test_python "${CMAKE_SOURCE_DIR}/.venv-youtube/bin/python")
endif()
set(SORI_TEST_PYTHON "${_sori_test_python}" CACHE FILEPATH "Python with youtube-transcript-api for helper tests")
if(EXISTS "${SORI_TEST_PYTHON}" OR TARGET caption-python)
    add_test(NAME python COMMAND "${SORI_TEST_PYTHON}" -m unittest discover
        -s "${CMAKE_SOURCE_DIR}/tests/python")
else()
    message(STATUS "Python helper tests unavailable: prepare .venv-youtube or set SORI_TEST_PYTHON")
endif()

target_link_libraries(sori PRIVATE "${CORE_LIB}" Qt6::Quick Qt6::OpenGL Qt6::Test Qt6::PdfQuick ${SORI_MPV_TARGET})
if(WIN32)
    # Rust's staticlib uses Windows named-pipe APIs from ntdll. Cargo supplies
    # this when linking Rust binaries; CMake must supply it for our executables.
    target_link_libraries(sori PRIVATE ntdll)
    target_link_libraries(sori-bridge-test PRIVATE ntdll)
endif()
if(TARGET Qt6::WebEngineQuick)
    target_link_libraries(sori PRIVATE Qt6::WebEngineQuick)
    target_compile_definitions(sori PRIVATE SORI_WEB_ENGINE)
endif()
qt_add_resources(sori "watch" PREFIX "/" FILES
    qml/Main.qml
    qml/style/Theme.qml
    qml/style/DictionaryTabs.qml
    qml/components/DictionaryOrderHandle.qml
    qml/components/DictionaryDragRow.qml
    qml/components/DictionaryDragState.qml
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
    qml/components/TranscriptHeader.qml
    qml/components/SubtitleTranscript.qml
    qml/components/SubtitleDefinition.qml
    qml/components/ReaderAnalysis.qml
    qml/components/ReaderDefinitions.qml
    qml/icons/arrow-left.svg
    qml/icons/arrow-up-down.svg
    qml/icons/grip-vertical.svg
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

install(TARGETS sori RUNTIME DESTINATION bin BUNDLE DESTINATION .)

# Explicit packaging never runs as part of a normal build.
add_custom_target(package
    COMMAND "${CMAKE_COMMAND}" "-DSOURCE_DIR=${CMAKE_SOURCE_DIR}"
        "-DBUILD_DIR=${CMAKE_BINARY_DIR}" "-DCONFIG=$<CONFIG>"
        "-DBUNDLE_HELPER=${SORI_BUNDLE_TRANSCRIPT_HELPER}"
        "-DQMAKE=${SORI_QMAKE}" "-DMPV_ROOT=${MPV_ROOT}"
        -P "${CMAKE_SOURCE_DIR}/scripts/package.cmake"
    DEPENDS sori
    USES_TERMINAL
    VERBATIM)
