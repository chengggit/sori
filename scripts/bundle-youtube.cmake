# Only build machines need Python/PyInstaller; the resulting helper includes both.
set(_sori_bundle_default ON)
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(_sori_bundle_default OFF)
endif()
option(SORI_BUNDLE_TRANSCRIPT_HELPER "Bundle a self-contained YouTube transcript helper" ${_sori_bundle_default})
if(SORI_BUNDLE_TRANSCRIPT_HELPER)
    set(SORI_HELPER_PYTHON "" CACHE FILEPATH "Existing Python with caption/PyInstaller dependencies; empty creates a private environment")
    set(_sori_python_dependency)
    if(SORI_HELPER_PYTHON)
        set(_sori_helper_python "${SORI_HELPER_PYTHON}")
        set(_sori_python_dependency "${_sori_helper_python}")
    else()
        find_package(Python3 QUIET COMPONENTS Interpreter)
        if(NOT Python3_Interpreter_FOUND)
            message(FATAL_ERROR "Caption bundling needs Python 3 with pip/venv. Install it, supply SORI_HELPER_PYTHON, or configure SORI_BUNDLE_TRANSCRIPT_HELPER=OFF.")
        endif()
        set(_sori_env "${CMAKE_BINARY_DIR}/deps/python")
        if(WIN32)
            set(_sori_helper_python "${_sori_env}/Scripts/python.exe")
        else()
            set(_sori_helper_python "${_sori_env}/bin/python")
        endif()
        add_custom_target(caption-python
            BYPRODUCTS "${_sori_env}/sori-ready.txt" "${_sori_helper_python}"
            COMMAND "${CMAKE_COMMAND}" "-DBASE_PYTHON=${Python3_EXECUTABLE}"
                "-DENV_DIR=${_sori_env}" "-DALLOW_DOWNLOADS=${SORI_ALLOW_DOWNLOADS}"
                "-DREQUIREMENTS=${CMAKE_SOURCE_DIR}/scripts/requirements-youtube-build.txt"
                "-DRUNTIME_REQUIREMENTS=${CMAKE_SOURCE_DIR}/scripts/requirements-youtube.txt"
                -P "${CMAKE_SOURCE_DIR}/scripts/prepare-python.cmake"
            VERBATIM)
        set(_sori_python_dependency caption-python "${_sori_env}/sori-ready.txt")
    endif()
    set(_sori_helper_dist "${CMAKE_CURRENT_BINARY_DIR}/helpers")
    set(_sori_helper_exe "${_sori_helper_dist}/sori-youtube-transcript/sori-youtube-transcript${CMAKE_EXECUTABLE_SUFFIX}")
    add_custom_command(OUTPUT "${_sori_helper_exe}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/pyinstaller" "${CMAKE_CURRENT_BINARY_DIR}/pyinstaller-cache"
        COMMAND "${CMAKE_COMMAND}" -E env "PYINSTALLER_CONFIG_DIR=${CMAKE_CURRENT_BINARY_DIR}/pyinstaller-cache"
            "${_sori_helper_python}" -m PyInstaller --noconfirm --clean --onedir
            --name sori-youtube-transcript
            --distpath "${_sori_helper_dist}"
            --workpath "${CMAKE_CURRENT_BINARY_DIR}/pyinstaller/work"
            --specpath "${CMAKE_CURRENT_BINARY_DIR}/pyinstaller"
            --copy-metadata youtube-transcript-api --copy-metadata requests
            "${CMAKE_SOURCE_DIR}/scripts/youtube_transcript.py"
        DEPENDS ${_sori_python_dependency} "${CMAKE_SOURCE_DIR}/scripts/youtube_transcript.py"
            "${CMAKE_SOURCE_DIR}/scripts/requirements-youtube.txt"
            "${CMAKE_SOURCE_DIR}/scripts/requirements-youtube-build.txt"
            "${CMAKE_SOURCE_DIR}/scripts/bundle-youtube.cmake"
        VERBATIM
    )
    add_custom_target(youtube-transcript-helper DEPENDS "${_sori_helper_exe}")
    add_dependencies(sori youtube-transcript-helper)
    install(DIRECTORY "${_sori_helper_dist}/sori-youtube-transcript" DESTINATION bin/helpers USE_SOURCE_PERMISSIONS)
endif()
