# 26-05-2024 luisarandas
cmake_minimum_required(VERSION 3.10)
include(ExternalProject)

# Set the project name and version
project(cmake_imgui_app VERSION 1.0 LANGUAGES CXX)

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
set(GLFW_INCLUDE_FOLDER ${LIBS_FOLDER}/glfw/include)
set(GLFW_LIB_FOLDER ${LIBS_FOLDER}/glfw/lib)

# Ensure the application and libs/glfw folders exist
file(MAKE_DIRECTORY ${APPLICATION_FOLDER})
file(MAKE_DIRECTORY ${LIBS_FOLDER}/glfw)

# Option to build GLFW locally
option(BUILD_GLFW3 "Download and build GLFW3" ON)

# Check if GLFW is already in libs/glfw
if(EXISTS ${GLFW_INCLUDE_FOLDER}/GLFW/glfw3.h AND EXISTS ${GLFW_LIB_FOLDER}/glfw3.lib)
    set(GLFW3_INCLUDE_DIRS ${GLFW_INCLUDE_FOLDER})
    set(GLFW3_LIBRARIES ${GLFW_LIB_FOLDER}/glfw3.lib)
    message(STATUS "Using existing GLFW3 library in libs/glfw")
else()
    # Download and build GLFW locally into the libs directory
    if(BUILD_GLFW3)
        message(STATUS "GLFW3 will be downloaded and built")
        set(GLFW3_PREFIX ${LIBS_FOLDER}/glfw)
        set(GLFW3_INCLUDE_DIR ${GLFW3_PREFIX}/include)
        set(GLFW3_LIBRARY ${GLFW3_PREFIX}/lib/glfw3.lib)

        # Build settings
        set(GLFW_BUILD_DOCS OFF CACHE BOOL "")
        set(GLFW_BUILD_TESTS OFF CACHE BOOL "")
        set(GLFW_BUILD_EXAMPLES OFF CACHE BOOL "")

        # Download and build
        ExternalProject_Add(glfw3
            URL "https://github.com/glfw/glfw/archive/refs/tags/3.2.1.zip"
            PREFIX ${GLFW3_PREFIX}
            SOURCE_SUBDIR "glfw-3.2.1"
            CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=${GLFW3_PREFIX} -DGLFW_BUILD_DOCS=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_EXAMPLES=OFF
            CONFIGURE_COMMAND ${CMAKE_COMMAND} -G "${CMAKE_GENERATOR}" -S <SOURCE_DIR> -B ${GLFW3_PREFIX}/build
            BUILD_COMMAND ${CMAKE_COMMAND} --build ${GLFW3_PREFIX}/build --config Release
            INSTALL_COMMAND ""
        )

        ExternalProject_Get_Property(glfw3 source_dir)
        set(GLFW3_INCLUDE_DIRS ${source_dir}/include)
        set(GLFW3_LIBRARIES ${GLFW3_PREFIX}/build/src/Release/glfw3.lib)
    endif()
endif()

# Include directories
include_directories(${SRC_FOLDER} ${IMGUI_FOLDER} ${IMGUI_BACKENDS_FOLDER} ${GLFW3_INCLUDE_DIRS} ${STB_FOLDER})

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

# Add executable
add_executable(${PROJECT_NAME} ${SOURCES})

# Link libraries
if(TARGET glfw3)
  add_dependencies(${PROJECT_NAME} glfw3)
endif()
target_link_libraries(${PROJECT_NAME} PRIVATE ${GLFW3_LIBRARIES} opengl32 gdi32 user32)


# # Clean the application directory before building
# add_custom_command(TARGET ${PROJECT_NAME} PRE_BUILD
#     COMMAND ${CMAKE_COMMAND} -E remove_directory ${APPLICATION_FOLDER}
#     COMMAND ${CMAKE_COMMAND} -E make_directory ${APPLICATION_FOLDER}
#     COMMENT "Cleaning and creating the application directory"
# )

# Copy data files after build
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
    ${DATA_FOLDER} ${APPLICATION_FOLDER}/data
    COMMENT "Copying data files to the application directory"
)

# Move the executable to the application directory
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:${PROJECT_NAME}> ${APPLICATION_FOLDER}/$<TARGET_FILE_NAME:${PROJECT_NAME}>
    COMMENT "Moving executable to the application directory"
)

# Copy the GLFW library to the application directory (if present)
if(EXISTS ${GLFW3_LIBRARIES})
  add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy ${GLFW3_LIBRARIES} ${APPLICATION_FOLDER}
      COMMENT "Copying GLFW library to the application directory"
  )
endif()

# Create documentation.md file
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E touch ${APPLICATION_FOLDER}/documentation.md
    COMMAND ${CMAKE_COMMAND} -E remove -f ${APPLICATION_FOLDER}/documentation.md
    COMMAND ${CMAKE_COMMAND} -E echo "documentation for cmake imgui app" > ${APPLICATION_FOLDER}/documentation.md
    COMMENT "Creating documentation.md"
)

