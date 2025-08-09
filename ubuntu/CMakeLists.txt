# 26-05-2024 luisarandas
cmake_minimum_required(VERSION 3.10)

# Set the project name and version
project(cmake-imgui-app VERSION 1.0 LANGUAGES CXX)

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
set(DATA_FOLDER ${ROOT_FOLDER}/data)
set(DIST_FOLDER ${CURRENT_FOLDER}/application)

set(STB_FOLDER ${LIBS_FOLDER}/stb)
set(IMGUI_FOLDER ${LIBS_FOLDER}/imgui)
set(IMGUI_BACKENDS_FOLDER ${LIBS_FOLDER}/imgui_backends)
set(GLFW_FOLDER ${LIBS_FOLDER}/glfw/include)


# Verify directories exist
if(NOT EXISTS ${SRC_FOLDER})
    message(FATAL_ERROR "Source folder does not exist: ${SRC_FOLDER}")
endif()
if(NOT EXISTS ${LIBS_FOLDER})
    message(FATAL_ERROR "Libs folder does not exist: ${LIBS_FOLDER}")
endif()
if(NOT EXISTS ${DATA_FOLDER})
    message(FATAL_ERROR "Data folder does not exist: ${DATA_FOLDER}")
endif()

# Ensure the build directory exists
file(MAKE_DIRECTORY ${BUILD_FOLDER})
file(MAKE_DIRECTORY ${DIST_FOLDER})

# Include directories
include_directories(${SRC_FOLDER} ${IMGUI_FOLDER} ${IMGUI_BACKENDS_FOLDER} ${GLFW_FOLDER} ${STB_FOLDER})


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

# Verify source files exist
foreach(SOURCE ${SOURCES})
    if(NOT EXISTS ${SOURCE})
        message(FATAL_ERROR "Source file does not exist: ${SOURCE}")
    endif()
endforeach()

# Add executable
add_executable(${PROJECT_NAME} ${SOURCES})

# Find and link GLFW using pkg-config
find_package(PkgConfig REQUIRED)
pkg_check_modules(GLFW REQUIRED glfw3)

# Include GLFW directories
if(GLFW_FOUND)
    include_directories(${GLFW_INCLUDE_DIRS})
    target_link_libraries(${PROJECT_NAME} ${GLFW_LIBRARIES} GL)
else()
    message(FATAL_ERROR "GLFW not found")
endif()

# Clean the dist directory before building
add_custom_command(TARGET ${PROJECT_NAME} PRE_BUILD
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${DIST_FOLDER}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${DIST_FOLDER}
    COMMENT "Cleaning and creating the application directory"
)

# Copy data files after build
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
    ${DATA_FOLDER} $<TARGET_FILE_DIR:${PROJECT_NAME}>/data
    COMMAND ${CMAKE_COMMAND} -E copy_directory
    ${DATA_FOLDER} ${DIST_FOLDER}/data
    COMMENT "Copying data files to the build and application directories"
)

# Move the executable to the dist folder
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E rename $<TARGET_FILE:${PROJECT_NAME}> ${DIST_FOLDER}/$<TARGET_FILE_NAME:${PROJECT_NAME}>
    COMMENT "Moving executable to the application directory"
)

# Create documentation.md file
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E touch ${DIST_FOLDER}/documentation.md
    COMMAND ${CMAKE_COMMAND} -E remove -f ${DIST_FOLDER}/documentation.md
    COMMAND ${CMAKE_COMMAND} -E echo "documentation for cmake imgui app" > ${DIST_FOLDER}/documentation.md
    COMMENT "Creating documentation.md"
)

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
message(STATUS "Dist folder: ${DIST_FOLDER}")
message(STATUS "GLFW include dirs: ${GLFW_INCLUDE_DIRS}")
message(STATUS "GLFW libraries: ${GLFW_LIBRARIES}")


# Install script
# file(WRITE ${DIST_FOLDER}/install.sh "#!/bin/bash\n\n")
# file(APPEND ${DIST_FOLDER}/install.sh "cp -r data \$HOME/\n")
# file(APPEND ${DIST_FOLDER}/install.sh "echo 'Installation of ${PROJECT_NAME} is successful. You can now run this app from anywhere on the computer. Copied the data folder with fonts and images to \$HOME/.'\n")
# file(COPY ${DIST_FOLDER}/install.sh DESTINATION ${CURRENT_FOLDER})
