#!/usr/bin/env bash
set -euo pipefail

# macOS 12.2 one-shot builder for the ImGui app
# - Ensures Command Line Tools (CLT)
# - Uses pkg-config GLFW if present; otherwise builds GLFW locally under ../libs/glfw (gitignored)
# - Detects architecture and sets MACOSX_DEPLOYMENT_TARGET=12.2 for baseline compatibility
# - Builds .app bundle to macos_122/application/
# - Optional: pass --package to also create a DMG (DragNDrop)
# - Enhanced with robust error handling and validation

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
MACOS_122_DIR="${ROOT_DIR}/macos_122"
LIBS_DIR="${ROOT_DIR}/libs"
BUILD_DIR="${MACOS_122_DIR}/build"
APP_DIR="${MACOS_122_DIR}/application"
ARCH="$(uname -m)"
MAKE_DMG=false
VERBOSE=false
CLEAN_BUILD=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[i]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_debug() { echo -e "${PURPLE}[DEBUG]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# Parse command line arguments
parse_arguments() {
    for arg in "$@"; do
        case "$arg" in
            --package) MAKE_DMG=true ;;
            --verbose|-v) VERBOSE=true ;;
            --clean) CLEAN_BUILD=true ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --package     Create DMG package after build"
                echo "  --verbose     Enable verbose output"
                echo "  --clean       Clean build directory before building"
                echo "  --help        Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $arg"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Error handling and cleanup
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Build failed with exit code $exit_code"
        log_warning "Check the build logs above for errors"
        log_info "You can try cleaning the build with: rm -rf ${BUILD_DIR}"
    fi
    exit $exit_code
}

trap cleanup EXIT

# Validate environment and prerequisites
validate_environment() {
    log_step "Validating build environment..."
    
    # Check if we're on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script is designed for macOS only"
        exit 1
    fi
    
    # Check macOS version
    local macos_version
    macos_version=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
    log_info "Detected macOS version: ${macos_version}"
    
    # Check if macos_122 directory exists
    if [ ! -d "${MACOS_122_DIR}" ]; then
        log_error "macos_122 directory not found: ${MACOS_122_DIR}"
        log_error "Please run ./build_project_macos122.sh first to set up the project"
        exit 1
    fi
    
    # Check if required files exist
    local required_files=(
        "${MACOS_122_DIR}/CMakeLists.txt"
        "${MACOS_122_DIR}/src/main.cpp"
    )
    
    local missing_files=()
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        log_error "Missing required files: ${missing_files[*]}"
        log_error "Please run ./build_project_macos122.sh first to set up the project"
        exit 1
    fi
    
    log_success "Environment validation passed"
}

# Ensure Command Line Tools are properly configured
ensure_clt() {
    log_step "Checking Xcode Command Line Tools..."
    
    local devdir
    devdir="$(xcode-select -p 2>/dev/null || true)"
    
    if [ -z "$devdir" ] || [ ! -d "$devdir" ]; then
        log_warning "Xcode Command Line Tools are not configured."
        if [ -d "/Library/Developer/CommandLineTools" ]; then
            log_info "Switching to CommandLineTools..."
            if sudo xcode-select --switch "/Library/Developer/CommandLineTools"; then
                log_success "Switched to CommandLineTools"
            else
                log_error "Failed to switch developer dir"
                log_info "Try manually: sudo xcode-select --switch /Library/Developer/CommandLineTools"
                exit 2
            fi
        else
            log_info "Triggering CLT installer..."
            xcode-select --install || true
            log_warning "Complete the CLT installation in the dialog, then re-run: ${ROOT_DIR}/build_app_macos122.sh"
            exit 2
        fi
    else
        log_success "Command Line Tools found at: ${devdir}"
    fi
}

# Test compiler functionality
test_compiler() {
    log_step "Testing C++ compiler..."
    
    if ! command -v clang >/dev/null 2>&1; then
        log_error "clang not found; ensure CLT is installed and active"
        log_error "Developer dir: $(xcode-select -p 2>/dev/null || echo "(none)")"
        exit 2
    fi
    
    # Test basic compilation
    local test_file="/tmp/cc_test_$$.cpp"
    local test_exe="/tmp/cc_test_$$"
    
    cat > "$test_file" << 'EOF'
#include <iostream>
int main() {
    std::cout << "C++17 compilation test successful" << std::endl;
    return 0;
}
EOF
    
    if clang++ -x c++ -std=c++17 "$test_file" -o "$test_exe" >/dev/null 2>&1; then
        if "$test_exe" >/dev/null 2>&1; then
            log_success "C++17 compiler test passed"
        else
            log_error "C++17 runtime test failed"
            exit 2
        fi
    else
        log_error "C++17 compilation test failed"
        log_error "Developer dir: $(xcode-select -p 2>/dev/null || echo "(none)")"
        log_info "Try: sudo xcode-select --switch /Library/Developer/CommandLineTools"
        log_info "Or run: xcode-select --install"
        exit 2
    fi
    
    # Cleanup test files
    rm -f "$test_file" "$test_exe"
}

# Check and install required tools
check_required_tools() {
    log_step "Checking required build tools..."
    
    local missing_tools=()
    local tools=(
        "cmake:CMake build system"
        "curl:File download utility"
        "unzip:Archive extraction utility"
        "rsync:File synchronization utility"
    )
    
    for tool_info in "${tools[@]}"; do
        local tool="${tool_info%%:*}"
        local description="${tool_info##*:}"
        
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool ($description)")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Install via Homebrew: brew install ${missing_tools[*]//\ \(*\)/}"
        log_info "Or download from: https://cmake.org/download/"
        exit 2
    fi
    
    log_success "All required tools are available"
}

# Setup build environment
setup_build_environment() {
    log_step "Setting up build environment..."
    
    export MACOSX_DEPLOYMENT_TARGET="12.2"
    
    log_info "Target macOS deployment: ${MACOSX_DEPLOYMENT_TARGET}"
    log_info "CPU architecture: ${ARCH}"
    
    # Clean and recreate build directories to avoid CMake cache conflicts
    log_info "Cleaning build directories to ensure fresh CMake configuration..."
    rm -rf "${BUILD_DIR:?}" "${APP_DIR:?}"
    mkdir -p "${BUILD_DIR}" "${APP_DIR}"
    
    # Set pkg-config path for Homebrew installations
    export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}:/opt/homebrew/lib/pkgconfig:/usr/local/lib/pkgconfig"
    
    if [ "$VERBOSE" = true ]; then
        log_debug "PKG_CONFIG_PATH: ${PKG_CONFIG_PATH}"
    fi
    
    log_success "Build environment configured"
}

# Verify and setup libraries
setup_libraries() {
    log_step "Verifying required libraries..."
    
    if [ ! -d "${MACOS_122_DIR}" ]; then
        log_error "macos_122 directory not found"
        exit 1
    fi
    
    # Check if essential libraries exist
    local required_libs=(
        "${LIBS_DIR}/imgui/imgui.h"
        "${LIBS_DIR}/imgui/imgui.cpp"
        "${LIBS_DIR}/imgui_backends/imgui_impl_glfw.h"
        "${LIBS_DIR}/imgui_backends/imgui_impl_glfw.cpp"
        "${LIBS_DIR}/imgui_backends/imgui_impl_opengl3.h"
        "${LIBS_DIR}/imgui_backends/imgui_impl_opengl3.cpp"
        "${LIBS_DIR}/stb/stb_image.h"
    )
    
    local missing_libs=()
    for lib_file in "${required_libs[@]}"; do
        if [ ! -f "$lib_file" ]; then
            missing_libs+=("$lib_file")
        fi
    done
    
    if [ ${#missing_libs[@]} -gt 0 ]; then
        log_error "Missing required library files: ${missing_libs[*]}"
        log_error "Please run ./build_project_macos122.sh first to set up the libraries"
        exit 1
    fi
    
    log_success "All required libraries are available"
}

# Check GLFW availability with enhanced detection
check_glfw() {
    # Log to stderr to avoid contaminating stdout return value
    log_step "Checking GLFW availability..." >&2
    
    local use_pkg=false
    local glfw_version=""
    local glfw_libs=""
    
    # Enhanced pkg-config detection
    if command -v pkg-config >/dev/null 2>&1; then
        if pkg-config --exists glfw3; then
            glfw_version=$(pkg-config --modversion glfw3 2>/dev/null || echo "unknown")
            glfw_libs=$(pkg-config --libs glfw3 2>/dev/null || echo "")
            
            log_info "System GLFW found via pkg-config" >&2
            log_info "GLFW version: ${glfw_version}" >&2
            
            # Verify the library is actually usable and properly linked
            if [ -n "$glfw_libs" ]; then
                # Test if we can actually link against it
                local test_file="/tmp/glfw_test_$$.cpp"
                local test_exe="/tmp/glfw_test_$$"
                
                cat > "$test_file" << 'EOF'
#include <GLFW/glfw3.h>
int main() {
    if (!glfwInit()) return 1;
    glfwTerminate();
    return 0;
}
EOF
                
                if pkg-config --cflags --libs glfw3 | xargs clang++ -o "$test_exe" "$test_file" 2>/dev/null; then
                    if "$test_exe" 2>/dev/null; then
                        use_pkg=true
                        log_success "System GLFW is properly configured and usable" >&2
                    else
                        log_warning "System GLFW test failed, falling back to local build" >&2
                        use_pkg=false
                    fi
                else
                    log_warning "System GLFW compilation test failed, falling back to local build" >&2
                    use_pkg=false
                fi
                
                # Cleanup test files
                rm -f "$test_file" "$test_exe"
            else
                log_warning "System GLFW found but library path is empty, falling back to local build" >&2
                use_pkg=false
            fi
        else
            log_info "System GLFW not found via pkg-config, will build locally" >&2
        fi
    else
        log_info "pkg-config not available, will build GLFW locally" >&2
    fi
    
    # Additional system GLFW detection for macOS (but don't use them)
    if [ "$use_pkg" = false ]; then
        local system_glfw_paths=(
            "/opt/homebrew/lib/libglfw.dylib"
            "/usr/local/lib/libglfw.dylib"
            "/System/Library/Frameworks/GLFW.framework"
        )
        
        for glfw_path in "${system_glfw_paths[@]}"; do
            if [ -e "$glfw_path" ]; then
                log_info "Found system GLFW at: ${glfw_path}" >&2
                log_info "However, pkg-config configuration is required for proper integration" >&2
                break
            fi
        done
    fi
    
    # Return clean value to stdout (no redirection needed)
    echo "$use_pkg"
}

# Build GLFW locally with enhanced robustness
build_local_glfw() {
    # Log to stderr to avoid contaminating stdout return value
    log_step "Building GLFW locally..." >&2
    
    local GLFW_DIR="${LIBS_DIR}/glfw"
    mkdir -p "${GLFW_DIR}"
    
    local GLVER="3.3.8"
    local GLURL="https://github.com/glfw/glfw/archive/refs/tags/${GLVER}.zip"
    local GLSRC_ZIP="${GLFW_DIR}/src/${GLVER}.zip"
    local GLSRC_DIR="${GLFW_DIR}/src/glfw-${GLVER}"
    local GLBUILD_DIR="${GLFW_DIR}/src/build"
    
    # Create source directory structure
    mkdir -p "${GLFW_DIR}/src"
    
    # Download GLFW if not present with retry logic
    if [ ! -f "${GLSRC_ZIP}" ]; then
        log_info "Downloading GLFW ${GLVER}..." >&2
        local download_attempts=3
        local download_success=false
        
        for attempt in $(seq 1 $download_attempts); do
            if curl -L "${GLURL}" -o "${GLSRC_ZIP}" --connect-timeout 30 --max-time 300; then
                download_success=true
                break
            else
                log_warning "Download attempt ${attempt} failed, retrying..." >&2
                if [ $attempt -lt $download_attempts ]; then
                    sleep 2
                fi
            fi
        done
        
        if [ "$download_success" = false ]; then
            log_error "Failed to download GLFW after ${download_attempts} attempts" >&2
            exit 1
        fi
    fi
    
    # Verify downloaded file integrity
    local expected_size=0
    if [ -f "${GLSRC_ZIP}" ]; then
        expected_size=$(stat -f%z "${GLSRC_ZIP}" 2>/dev/null || stat -c%s "${GLSRC_ZIP}" 2>/dev/null || echo "0")
        if [ "$expected_size" -lt 1000000 ]; then  # Less than 1MB indicates corrupted download
            log_error "Downloaded GLFW file appears corrupted (size: ${expected_size} bytes)" >&2
            rm -f "${GLSRC_ZIP}"
            exit 1
        fi
    fi
    
    # Extract GLFW if not present
    if [ ! -d "${GLSRC_DIR}" ]; then
        log_info "Extracting GLFW ${GLVER}..." >&2
        if ! unzip -q "${GLSRC_ZIP}" -d "${GLFW_DIR}/src"; then
            log_error "Failed to extract GLFW" >&2
            exit 1
        fi
    fi
    
    # Verify extracted source
    if [ ! -f "${GLSRC_DIR}/CMakeLists.txt" ] || [ ! -f "${GLSRC_DIR}/include/GLFW/glfw3.h" ]; then
        log_error "GLFW source extraction appears incomplete" >&2
        exit 1
    fi
    
    # Configure GLFW build with enhanced options
    log_info "Configuring GLFW build..." >&2
    mkdir -p "${GLBUILD_DIR}"
    
    local cmake_opts=(
        "-S" "${GLSRC_DIR}"
        "-B" "${GLBUILD_DIR}"
        "-DGLFW_BUILD_DOCS=OFF"
        "-DGLFW_BUILD_TESTS=OFF"
        "-DGLFW_BUILD_EXAMPLES=OFF"
        "-DCMAKE_OSX_ARCHITECTURES=${ARCH}"
        "-DCMAKE_BUILD_TYPE=Release"
        "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
    )
    
    if [ "$VERBOSE" = true ]; then
        cmake_opts+=("--verbose")
    fi
    
    if ! cmake "${cmake_opts[@]}"; then
        log_error "GLFW configuration failed" >&2
        exit 1
    fi
    
    # Build GLFW with parallel compilation
    log_info "Building GLFW..." >&2
    local build_opts=("--build" "${GLBUILD_DIR}" "--config" "Release")
    if [ "$VERBOSE" = true ]; then
        build_opts+=("--verbose")
    fi
    
    # Use parallel builds if available
    local cpu_count
    cpu_count=$(sysctl -n hw.ncpu 2>/dev/null || echo "1")
    if [ "$cpu_count" -gt 1 ]; then
        build_opts+=("-j${cpu_count}")
        log_info "Using parallel build with ${cpu_count} cores" >&2
    fi
    
    if ! cmake "${build_opts[@]}"; then
        log_error "GLFW build failed" >&2
        exit 1
    fi
    
    # Stage GLFW headers and libraries with verification
    log_info "Staging GLFW headers and libraries..." >&2
    mkdir -p "${GLFW_DIR}/include" "${GLFW_DIR}/lib"
    
    if ! rsync -a "${GLSRC_DIR}/include/" "${GLFW_DIR}/include/"; then
        log_error "Failed to copy GLFW headers" >&2
        exit 1
    fi
    
    # Find and copy the built library with enhanced detection
    local GL_LIB=""
    local lib_patterns=(
        "${GLBUILD_DIR}/src/Release/libglfw*"
        "${GLBUILD_DIR}/src/libglfw*"
        "${GLBUILD_DIR}/libglfw*"
    )
    
    for pattern in "${lib_patterns[@]}"; do
        for f in $pattern; do
            if [ -f "$f" ] && [[ "$f" =~ \.(a|dylib)$ ]]; then
                GL_LIB="$f"
                break 2
            fi
        done
    done
    
    if [ -z "${GL_LIB}" ] || [ ! -f "${GL_LIB}" ]; then
        log_error "Could not find built GLFW library in ${GLBUILD_DIR}" >&2
        log_info "Searching for library files..." >&2
        find "${GLBUILD_DIR}" -name "libglfw*" -type f 2>/dev/null || true
        exit 1
    fi
    
    # Verify library file
    local lib_size
    lib_size=$(stat -f%z "${GL_LIB}" 2>/dev/null || stat -c%s "${GL_LIB}" 2>/dev/null || echo "0")
    if [ "$lib_size" -lt 100000 ]; then  # Less than 100KB indicates corrupted library
        log_error "GLFW library appears corrupted (size: ${lib_size} bytes)" >&2
        exit 1
    fi
    
    if ! cp -f "${GL_LIB}" "${GLFW_DIR}/lib/"; then
        log_error "Failed to copy GLFW library" >&2
        exit 1
    fi
    
    log_success "GLFW built and staged successfully" >&2
    log_info "Library size: ${lib_size} bytes" >&2
    
    # Return the paths in the expected format (to stdout, no redirection)
    local return_paths="${GLFW_DIR}/include:${GLFW_DIR}/lib/$(basename "${GL_LIB}")"
    log_info "Returning GLFW paths: ${return_paths}" >&2
    echo "${return_paths}"
}

# Build the ImGui application
build_application() {
    log_step "Building ImGui application..."
    
    local use_pkg="$1"
    local glfw_paths="$2"
    
    # Debug: Show what we received
    log_info "build_application received: use_pkg=${use_pkg}, glfw_paths=${glfw_paths}"
    
    # Build directory already cleaned in setup_build_environment
    log_info "Using clean build directory for CMake configuration..."
    
    # Configure CMake build with enhanced options
    log_info "Configuring CMake build..."
    local cmake_opts=(
        "-S" "${MACOS_122_DIR}"
        "-B" "${BUILD_DIR}"
        "-DCMAKE_OSX_ARCHITECTURES=${ARCH}"
        "-DCMAKE_BUILD_TYPE=Release"
        "-DCMAKE_VERBOSE_MAKEFILE=${VERBOSE}"
    )
    
    if [ "$use_pkg" = "true" ]; then
        log_info "Using system GLFW via pkg-config"
        # Additional system GLFW configuration
        local glfw_cflags
        glfw_cflags=$(pkg-config --cflags glfw3 2>/dev/null || echo "")
        if [ -n "$glfw_cflags" ]; then
            cmake_opts+=("-DCMAKE_CXX_FLAGS=${glfw_cflags}")
        fi
    else
        log_info "Using local GLFW build"
        local glfw_include="${glfw_paths%%:*}"
        local glfw_lib="${glfw_paths##*:}"
        
        # Verify GLFW paths exist
        if [ ! -d "$glfw_include" ] || [ ! -f "$glfw_lib" ]; then
            log_error "Invalid GLFW paths: include=${glfw_include}, lib=${glfw_paths}"
            log_error "This suggests a logic error in GLFW detection"
            exit 1
        fi
        
        cmake_opts+=(
            "-DGLFW3_INCLUDE_DIRS=${glfw_include}"
            "-DGLFW3_LIBRARIES=${glfw_lib}"
        )
        
        log_info "GLFW include: ${glfw_include}"
        log_info "GLFW library: ${glfw_lib}"
    fi
    
    if [ "$VERBOSE" = true ]; then
        cmake_opts+=("--verbose")
    fi
    
    # Show CMake configuration
    log_info "CMake configuration:"
    for opt in "${cmake_opts[@]}"; do
        log_debug "  ${opt}"
    done
    
    if ! cmake "${cmake_opts[@]}"; then
        log_error "CMake configuration failed"
        log_info "Check CMake error logs above"
        exit 1
    fi
    
    # Build the application with enhanced options
    log_info "Building application..."
    local build_opts=("--build" "${BUILD_DIR}" "--config" "Release")
    
    # Use parallel builds if available
    local cpu_count
    cpu_count=$(sysctl -n hw.ncpu 2>/dev/null || echo "1")
    if [ "$cpu_count" -gt 1 ]; then
        build_opts+=("-j${cpu_count}")
        log_info "Using parallel build with ${cpu_count} cores"
    fi
    
    if [ "$VERBOSE" = true ]; then
        build_opts+=("--verbose")
    fi
    
    # Show build options
    log_info "Build options:"
    for opt in "${build_opts[@]}"; do
        log_debug "  ${opt}"
    done
    
    if ! cmake "${build_opts[@]}"; then
        log_error "Application build failed"
        log_info "Check build error logs above"
        log_info "You can try cleaning the build with: --clean"
        exit 1
    fi
    
    log_success "Application build completed"
}

# Verify build output
verify_build() {
    log_step "Verifying build output..."
    
    local APP_BUNDLE="${APP_DIR}/cmake_imgui_app_macos.app"
    
    if [ -d "${APP_BUNDLE}" ]; then
        log_success "App bundle created successfully at: ${APP_BUNDLE}"
        
        # Check bundle contents
        local bundle_size
        bundle_size=$(du -sh "${APP_BUNDLE}" | cut -f1)
        log_info "App bundle size: ${bundle_size}"
        
        # Check if executable exists
        local executable="${APP_BUNDLE}/Contents/MacOS/cmake_imgui_app_macos"
        if [ -x "$executable" ]; then
            log_success "Executable found and is executable"
        else
            log_error "Executable not found or not executable: $executable"
            exit 1
        fi
        
        return 0
    else
        log_error "App bundle not found at: ${APP_BUNDLE}"
        log_error "Check build logs for errors"
        exit 1
    fi
}

# Create DMG package
create_dmg() {
    if [ "$MAKE_DMG" = true ]; then
        log_step "Creating DMG package..."
        
        if ! command -v cpack >/dev/null 2>&1; then
            log_warning "CPack not found, skipping DMG creation"
            return 0
        fi
        
        if (cd "${BUILD_DIR}" && cpack -G DragNDrop); then
            log_success "DMG package created successfully"
            log_info "DMG files:"
            ls -1 "${BUILD_DIR}"/*.dmg 2>/dev/null || log_warning "No DMG files found"
        else
            log_warning "DMG creation failed, but build was successful"
        fi
    fi
}

# Main build process
main() {
    log_info "Starting macOS 12.2 ImGui application build..."
    log_info "Root directory: ${ROOT_DIR}"
    log_info "Build directory: ${BUILD_DIR}"
    log_info "Application directory: ${APP_DIR}"
    
    # Parse arguments
    parse_arguments "$@"
    
    # Validate environment
    validate_environment
    
    # Ensure Command Line Tools
    ensure_clt
    
    # Test compiler
    test_compiler
    
    # Check required tools
    check_required_tools
    
    # Setup build environment
    setup_build_environment
    
    # Setup libraries
    setup_libraries
    
    # Check GLFW availability
    local use_pkg
    use_pkg=$(check_glfw)
    
    log_info "GLFW detection result in main: use_pkg=${use_pkg}"
    
    local glfw_paths=""
    if [ "$use_pkg" = "false" ]; then
        log_info "Building GLFW locally..."
        glfw_paths=$(build_local_glfw)
        
        # Verify GLFW paths were set correctly
        if [ -z "$glfw_paths" ]; then
            log_error "GLFW build failed to return valid paths"
            exit 1
        fi
        
        log_info "GLFW build completed with paths: ${glfw_paths}"
    else
        log_info "Using system GLFW via pkg-config"
        # Verify system GLFW is actually working
        if ! pkg-config --exists glfw3; then
            log_warning "System GLFW detection failed, falling back to local build"
            use_pkg="false"
            glfw_paths=$(build_local_glfw)
            
            if [ -z "$glfw_paths" ]; then
                log_error "GLFW build failed to return valid paths"
                exit 1
            fi
            
            log_info "GLFW build completed with paths: ${glfw_paths}"
        fi
    fi
    
    log_info "Before build_application: use_pkg=${use_pkg}, glfw_paths=${glfw_paths}"
    
    # Build application
    build_application "$use_pkg" "$glfw_paths"
    
    # Verify build
    verify_build
    
    # Create DMG if requested
    create_dmg
    
    # Final success message
    log_success "Build completed successfully!"
    echo
    log_info "You can open the app with: open '${APP_DIR}/cmake_imgui_app_macos.app'"
    log_info "Or run it directly: '${APP_DIR}/cmake_imgui_app_macos.app/Contents/MacOS/cmake_imgui_app_macos'"
    
    if [ "$MAKE_DMG" = true ]; then
        log_info "DMG package available in: ${BUILD_DIR}"
    fi
}

# Run main function
main "$@"
