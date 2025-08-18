# 09-08-2025 macOS CMake (Monterey 12.2)
cmake_minimum_required(VERSION 3.10)

# Set the project name and version
project(cmake_imgui_app_macos VERSION 1.0 LANGUAGES CXX)

# Set the C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# Set the build type to Release if not specified
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

# Define the directories
set(CURRENT_FOLDER ${CMAKE_CURRENT_SOURCE_DIR})
set(ROOT_FOLDER ${CURRENT_FOLDER}/..)
set(SRC_FOLDER ${CURRENT_FOLDER}/src)
set(LIBS_FOLDER ${ROOT_FOLDER}/libs)
set(BUILD_FOLDER ${CURRENT_FOLDER}/build)
set(APPLICATION_FOLDER ${CURRENT_FOLDER}/application)
set(DATA_FOLDER ${ROOT_FOLDER}/data)

set(STB_FOLDER ${LIBS_FOLDER}/stb)
set(IMGUI_FOLDER ${LIBS_FOLDER}/imgui)
set(IMGUI_BACKENDS_FOLDER ${LIBS_FOLDER}/imgui_backends)

# Ensure the application folder exists
file(MAKE_DIRECTORY ${APPLICATION_FOLDER})

# Include directories
include_directories(${SRC_FOLDER} ${IMGUI_FOLDER} ${IMGUI_BACKENDS_FOLDER} ${STB_FOLDER})

# Source files
set(SOURCES
    ${SRC_FOLDER}/main.cpp
    ${IMGUI_FOLDER}/imgui.cpp
    ${IMGUI_FOLDER}/imgui_demo.cpp
    ${IMGUI_FOLDER}/imgui_draw.cpp
    ${IMGUI_FOLDER}/imgui_tables.cpp
    ${IMGUI_FOLDER}/imgui_widgets.cpp
    ${IMGUI_BACKENDS_FOLDER}/imgui_impl_glfw.cpp
    ${IMGUI_BACKENDS_FOLDER}/imgui_impl_opengl3.cpp
)

# Optional ImGui extras (disabled by default). Enable with -DENABLE_* on command line
option(ENABLE_IMNODES "Build imnodes integration" OFF)
option(ENABLE_IMSEQUENCER "Build ImSequencer integration" OFF)
option(ENABLE_IMCURVEEDIT "Build ImCurveEdit integration" OFF)

if(ENABLE_IMNODES)
  if(EXISTS ${IMGUI_FOLDER}/imnodes.cpp)
    list(APPEND SOURCES ${IMGUI_FOLDER}/imnodes.cpp)
  endif()
endif()

if(ENABLE_IMSEQUENCER)
  if(EXISTS ${IMGUI_FOLDER}/ImSequencer.cpp)
    list(APPEND SOURCES ${IMGUI_FOLDER}/ImSequencer.cpp)
  endif()
endif()

if(ENABLE_IMCURVEEDIT)
  if(EXISTS ${IMGUI_FOLDER}/ImCurveEdit.cpp)
    list(APPEND SOURCES ${IMGUI_FOLDER}/ImCurveEdit.cpp)
  endif()
endif()

# Verify source files exist
foreach(SOURCE ${SOURCES})
    if(NOT EXISTS ${SOURCE})
        message(FATAL_ERROR "Source file does not exist: ${SOURCE}")
    endif()
endforeach()

# Add executable as a macOS bundle (.app)
add_executable(${PROJECT_NAME} MACOSX_BUNDLE ${SOURCES})

# Find and link GLFW
# Allow manual overrides via -DGLFW3_INCLUDE_DIRS= -DGLFW3_LIBRARIES=
if(DEFINED GLFW3_INCLUDE_DIRS AND DEFINED GLFW3_LIBRARIES)
    message(STATUS "Using manual GLFW paths: ${GLFW3_INCLUDE_DIRS} | ${GLFW3_LIBRARIES}")
    include_directories(${GLFW3_INCLUDE_DIRS})
    target_link_libraries(${PROJECT_NAME} ${GLFW3_LIBRARIES} "-framework OpenGL" "-framework Cocoa" "-framework IOKit" "-framework CoreVideo")
else()
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(GLFW REQUIRED glfw3)
    if(GLFW_FOUND)
        include_directories(${GLFW_INCLUDE_DIRS})
        # Ensure linker can find glfw by adding its library dirs from pkg-config
        if(DEFINED GLFW_LIBRARY_DIRS)
            link_directories(${GLFW_LIBRARY_DIRS})
        endif()
        # Try to resolve an absolute glfw library path to avoid '-lglfw' lookup issues
        execute_process(COMMAND pkg-config --variable=libdir glfw3
                        OUTPUT_VARIABLE GLFW_PKG_LIBDIR
                        OUTPUT_STRIP_TRAILING_WHITESPACE)
        find_library(GLFW_ABS_LIB NAMES glfw HINTS ${GLFW_LIBRARY_DIRS} ${GLFW_PKG_LIBDIR})
        if(GLFW_ABS_LIB)
            target_link_libraries(
                ${PROJECT_NAME}
                ${GLFW_ABS_LIB}
                "-framework OpenGL" "-framework Cocoa" "-framework IOKit" "-framework CoreVideo"
            )
        else()
            target_link_libraries(
                ${PROJECT_NAME}
                ${GLFW_LIBRARIES}
                "-framework OpenGL" "-framework Cocoa" "-framework IOKit" "-framework CoreVideo"
            )
        endif()
    else()
        # Fallback: attempt to use a locally built GLFW under libs/glfw if present
        set(LOCAL_GLFW_INCLUDE "${LIBS_FOLDER}/glfw/include")
        set(LOCAL_GLFW_LIB "")
        if(EXISTS "${LIBS_FOLDER}/glfw/lib")
            file(GLOB LOCAL_GLFW_CAND "${LIBS_FOLDER}/glfw/lib/libglfw*.*")
            list(LENGTH LOCAL_GLFW_CAND LOCAL_GLFW_COUNT)
            if(LOCAL_GLFW_COUNT GREATER 0)
                list(GET LOCAL_GLFW_CAND 0 LOCAL_GLFW_LIB)
            endif()
        endif()
        if(EXISTS ${LOCAL_GLFW_INCLUDE} AND EXISTS ${LOCAL_GLFW_LIB})
            message(STATUS "Using local GLFW from libs/glfw")
            include_directories(${LOCAL_GLFW_INCLUDE})
            target_link_libraries(${PROJECT_NAME} ${LOCAL_GLFW_LIB} "-framework OpenGL" "-framework Cocoa" "-framework IOKit" "-framework CoreVideo")
        else()
            message(FATAL_ERROR "GLFW not found. Provide GLFW3_INCLUDE_DIRS/GLFW3_LIBRARIES, install via pkg-config, or run macos/download_libs.sh to build local libs.")
        endif()
    endif()
endif()

# Copy data into the .app bundle Resources
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:${PROJECT_NAME}>/../../Resources/data"
    COMMAND ${CMAKE_COMMAND} -E copy_directory
            ${DATA_FOLDER} "$<TARGET_FILE_DIR:${PROJECT_NAME}>/../../Resources/data"
    COMMENT "Copying data files into the app bundle (Resources/data)"
)

# Copy the .app bundle to the application folder
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory ${APPLICATION_FOLDER}
    COMMAND ${CMAKE_COMMAND} -E copy_directory "$<TARGET_FILE_DIR:${PROJECT_NAME}>/../.." "${APPLICATION_FOLDER}/${PROJECT_NAME}.app"
    COMMENT "Copying .app bundle to the application directory"
)

# Skip creating documentation.md to avoid shell redirection issues in custom commands

# Packaging (DMG via CPack)
set(CPACK_GENERATOR "DragNDrop")
set(CPACK_PACKAGE_NAME "cmake_imgui_app_macos")
set(CPACK_PACKAGE_FILE_NAME "cmake_imgui_app_macos-${CMAKE_SYSTEM_NAME}")
set(CPACK_DMG_VOLUME_NAME "ImGui App")
set(CPACK_DMG_BACKGROUND_IMAGE "")
set(CPACK_DMG_DS_STORE "")
include(CPack)

# Install rules for packaging (.dmg)
install(TARGETS ${PROJECT_NAME}
        BUNDLE DESTINATION .)
install(DIRECTORY ${DATA_FOLDER}/
        DESTINATION ${PROJECT_NAME}.app/Contents/Resources/data)

# Print configuration details
message(STATUS "CMake version: ${CMAKE_VERSION}")
message(STATUS "Project name: ${PROJECT_NAME}")
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "C++ compiler: ${CMAKE_CXX_COMPILER}")
message(STATUS "C++ standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "Source folder: ${SRC_FOLDER}")
message(STATUS "Libs folder: ${LIBS_FOLDER}")
message(STATUS "Build folder: ${BUILD_FOLDER}")
message(STATUS "Data folder: ${DATA_FOLDER}")
message(STATUS "Application folder: ${APPLICATION_FOLDER}")
message(STATUS "GLFW include dirs: ${GLFW_INCLUDE_DIRS}")
message(STATUS "GLFW libraries: ${GLFW_LIBRARIES}")


