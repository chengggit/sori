cmake_minimum_required(VERSION 3.21)
project(SoriQtPlayer LANGUAGES CXX)

find_package(Qt6 6.10 REQUIRED COMPONENTS Quick OpenGL Test)
find_package(PkgConfig REQUIRED)
find_program(CARGO_EXECUTABLE cargo REQUIRED)
pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

add_executable(sori-qt-player
    src/main.cpp
    src/videoitem.cpp src/videoitem.h
)
set(PLAYBACK_DIR "${CMAKE_CURRENT_SOURCE_DIR}/playback")
set(PLAYBACK_TARGET "${CMAKE_CURRENT_BINARY_DIR}/cargo")
set(PLAYBACK_LIB "${PLAYBACK_TARGET}/release/${CMAKE_STATIC_LIBRARY_PREFIX}sori_qt_playback${CMAKE_STATIC_LIBRARY_SUFFIX}")
add_custom_command(OUTPUT "${PLAYBACK_LIB}"
    COMMAND "${CARGO_EXECUTABLE}" build --release --locked
        --manifest-path "${PLAYBACK_DIR}/Cargo.toml" --target-dir "${PLAYBACK_TARGET}"
    DEPENDS "${PLAYBACK_DIR}/src/player_model.rs" "${PLAYBACK_DIR}/src/subtitle_model.rs"
        "${PLAYBACK_DIR}/Cargo.toml" "${PLAYBACK_DIR}/Cargo.lock" "${PLAYBACK_DIR}/src/lib.rs" "${PLAYBACK_DIR}/src/subtitles.rs" "${PLAYBACK_DIR}/src/controls.rs"
    VERBATIM
)
add_custom_target(sori-qt-playback DEPENDS "${PLAYBACK_LIB}")
add_dependencies(sori-qt-player sori-qt-playback)
target_link_libraries(sori-qt-player PRIVATE "${PLAYBACK_LIB}" Qt6::Quick Qt6::OpenGL Qt6::Test PkgConfig::MPV)
qt_add_resources(sori-qt-player "watch" PREFIX "/" FILES
    qml/Main.qml
    assets/Inter-Variable.ttf assets/NotoSansKR-Regular.otf
)
