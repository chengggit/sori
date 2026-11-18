# Only build machines need Python/PyInstaller; the resulting helper includes both.
option(SORI_BUNDLE_TRANSCRIPT_HELPER "Bundle a self-contained YouTube transcript helper" OFF)
if(SORI_BUNDLE_TRANSCRIPT_HELPER)
    if(WIN32)
        set(_sori_helper_python "${CMAKE_SOURCE_DIR}/.venv-youtube/Scripts/python.exe")
    else()
        set(_sori_helper_python "${CMAKE_SOURCE_DIR}/.venv-youtube/bin/python")
    endif()
    set(SORI_HELPER_PYTHON "${_sori_helper_python}" CACHE FILEPATH "Build-time Python with transcript packaging dependencies")
    execute_process(
        COMMAND "${SORI_HELPER_PYTHON}" -c "import PyInstaller, youtube_transcript_api"
        RESULT_VARIABLE _sori_helper_check OUTPUT_QUIET ERROR_QUIET
    )
    if(NOT _sori_helper_check EQUAL 0)
        message(FATAL_ERROR "Prepare the build environment: python3 -m venv .venv-youtube, then .venv-youtube/bin/python -m pip install -r scripts/requirements-youtube-build.txt. Or set SORI_HELPER_PYTHON to that environment's Python.")
    endif()
    set(_sori_helper_dist "${CMAKE_CURRENT_BINARY_DIR}/helpers")
    set(_sori_helper_exe "${_sori_helper_dist}/sori-youtube-transcript/sori-youtube-transcript${CMAKE_EXECUTABLE_SUFFIX}")
    add_custom_command(OUTPUT "${_sori_helper_exe}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/pyinstaller" "${CMAKE_CURRENT_BINARY_DIR}/pyinstaller-cache"
        COMMAND "${CMAKE_COMMAND}" -E env "PYINSTALLER_CONFIG_DIR=${CMAKE_CURRENT_BINARY_DIR}/pyinstaller-cache"
            "${SORI_HELPER_PYTHON}" -m PyInstaller --noconfirm --clean --onedir
            --name sori-youtube-transcript
            --distpath "${_sori_helper_dist}"
            --workpath "${CMAKE_CURRENT_BINARY_DIR}/pyinstaller/work"
            --specpath "${CMAKE_CURRENT_BINARY_DIR}/pyinstaller"
            --copy-metadata youtube-transcript-api --copy-metadata requests
            "${CMAKE_SOURCE_DIR}/scripts/youtube_transcript.py"
        DEPENDS "${CMAKE_SOURCE_DIR}/scripts/youtube_transcript.py"
            "${CMAKE_SOURCE_DIR}/scripts/requirements-youtube.txt"
            "${CMAKE_SOURCE_DIR}/scripts/requirements-youtube-build.txt"
            "${CMAKE_SOURCE_DIR}/scripts/bundle-youtube.cmake"
        VERBATIM
    )
    add_custom_target(youtube-transcript-helper DEPENDS "${_sori_helper_exe}")
    add_dependencies(sori youtube-transcript-helper)
    install(DIRECTORY "${_sori_helper_dist}/sori-youtube-transcript" DESTINATION bin/helpers USE_SOURCE_PERMISSIONS)
endif()
