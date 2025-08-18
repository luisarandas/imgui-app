# macOS 12.2 ImGui Application

This directory contains the macOS 12.2 specific build configuration for the ImGui application.

## Structure

- `src/` - Source code files
- `CMakeLists.txt` - CMake build configuration

## Build Instructions

1. **Setup Project** (from project root):
   ```bash
   ./build_project_macos122.sh
   ```
   This automatically downloads and sets up all required libraries.

2. **Build Application** (from project root):
   ```bash
   ./build_app_macos122.sh
   ```

## Requirements

- macOS 12.2 or later
- Xcode Command Line Tools
- CMake 3.10 or later
- C++17 compatible compiler

## Libraries

The following libraries are automatically downloaded and managed:
- **Dear ImGui** - Core GUI library from [https://github.com/ocornut/imgui](https://github.com/ocornut/imgui)
- **ImGui Backends** - GLFW and OpenGL3 backends
- **stb** - Image loading library from [https://github.com/nothings/stb](https://github.com/nothings/stb)

## Notes

- Build artifacts are placed in `build/` and `application/` directories
- These directories are gitignored to keep the repository clean
- The application will be built as a macOS .app bundle
- Libraries are automatically kept up-to-date from their official repositories
