#!/usr/bin/env bash
set -euo pipefail

# macOS 12.2 library management script
# Assumes macos_122/ folder with src/, CMakeLists.txt, and README.md already exists
# This script manages libraries for macOS 12.2 builds with robust error handling
# INCLUDES: Bulletproof library download and management system

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
MACOS_DIR="${ROOT_DIR}/macos_122"
MACOS_122_DIR="${ROOT_DIR}/macos_122"
LIBS_DIR="${ROOT_DIR}/libs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[i]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

# Error handling
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Script failed with exit code $exit_code"
        log_warning "You may need to manually clean up: rm -rf ${MACOS_122_DIR}"
    fi
    exit $exit_code
}

trap cleanup EXIT

# Validate environment
validate_environment() {
    log_info "Validating environment..."
    
    # Check if we're on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script is designed for macOS only"
        exit 1
    fi
    
    # Check macOS version
    local macos_version
    macos_version=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
    log_info "Detected macOS version: ${macos_version}"
    
    # Check required tools
    local missing_tools=()
    for tool in cp mkdir chmod rsync curl git; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Install via Homebrew: brew install ${missing_tools[*]}"
        exit 1
    fi
    
    log_success "Environment validation passed"
}

# Check if project already exists
check_existing_project() {
    log_info "Checking existing project structure..."
    
    # Verify the project structure exists
    if [ ! -d "${MACOS_122_DIR}" ]; then
        log_error "Project directory not found: ${MACOS_122_DIR}"
        log_error "Please ensure macos_122/ folder exists with src/, CMakeLists.txt, and README.md"
        exit 1
    fi
    
    # Verify essential project files exist
    local required_files=(
        "${MACOS_122_DIR}/src"
        "${MACOS_122_DIR}/src/main.cpp"
        "${MACOS_122_DIR}/CMakeLists.txt"
        "${MACOS_122_DIR}/README.md"
    )
    
    local missing_files=()
    for file in "${required_files[@]}"; do
        if [ ! -e "$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        log_error "Missing required project files: ${missing_files[*]}"
        log_error "Please ensure macos_122/ folder contains all required source files"
        exit 1
    fi
    
    log_success "Project structure verified: ${MACOS_122_DIR}"
    log_info "Source code and project files confirmed"
    log_info "Only libraries will be managed/updated"
}




# BULLETPROOF LIBRARY DOWNLOAD AND MANAGEMENT SYSTEM
# This is the exact same system from the original download_libs.sh
download_and_manage_libraries() {
    log_info "Setting up bulletproof library management system..."
    
    # Create libs directory if it doesn't exist
    mkdir -p "${LIBS_DIR}"
    
    # Function to download and setup a library
    setup_library() {
        local lib_name="$1"
        local repo_url="$2"
        local target_dir="$3"
        local branch="${4:-main}"
        local files_to_copy=("${@:5}")
        
        log_info "Setting up ${lib_name}..."
        
        if [ -d "${target_dir}" ]; then
            log_info "${lib_name} directory already exists, checking if update needed..."
            
            # Check if it's a git repository and if updates are available
            if [ -d "${target_dir}/.git" ]; then
                cd "${target_dir}"
                local current_branch
                current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
                
                if [ "$current_branch" != "$branch" ]; then
                    log_info "Switching to ${branch} branch..."
                    git checkout "$branch" || git checkout -b "$branch"
                fi
                
                log_info "Pulling latest changes..."
                git pull origin "$branch" || log_warning "Could not pull latest changes, using existing version"
                cd - > /dev/null
            else
                log_warning "${lib_name} exists but is not a git repository, skipping update"
            fi
        else
            log_info "Cloning ${lib_name} from ${repo_url}..."
            if git clone --depth 1 --branch "$branch" "$repo_url" "$target_dir"; then
                log_success "${lib_name} cloned successfully"
            else
                log_error "Failed to clone ${lib_name}"
                exit 1
            fi
        fi
        
        # Verify essential files exist
        local missing_files=()
        for file in "${files_to_copy[@]}"; do
            if [ ! -f "${target_dir}/${file}" ]; then
                missing_files+=("${file}")
            fi
        done
        
        if [ ${#missing_files[@]} -gt 0 ]; then
            log_error "Missing essential files for ${lib_name}: ${missing_files[*]}"
            log_error "Repository may be corrupted or incomplete"
            exit 1
        fi
        
        log_success "${lib_name} setup completed successfully"
    }
    
    # Setup Dear ImGui (core library)
    setup_library \
        "Dear ImGui" \
        "https://github.com/ocornut/imgui.git" \
        "${LIBS_DIR}/imgui" \
        "master" \
        "imgui.h" \
        "imgui.cpp" \
        "imgui_demo.cpp" \
        "imgui_draw.cpp" \
        "imgui_tables.cpp" \
        "imgui_widgets.cpp" \
        "imgui_internal.h" \
        "imconfig.h" \
        "imstb_rectpack.h" \
        "imstb_textedit.h" \
        "imstb_truetype.h"
    
    # Setup ImGui backends (GLFW and OpenGL3)
    setup_library \
        "ImGui Backends" \
        "https://github.com/ocornut/imgui.git" \
        "${LIBS_DIR}/imgui_backends" \
        "master" \
        "backends/imgui_impl_glfw.cpp" \
        "backends/imgui_impl_glfw.h" \
        "backends/imgui_impl_opengl3.cpp" \
        "backends/imgui_impl_opengl3.h" \
        "backends/imgui_impl_opengl3_loader.h"
    
    # Copy backend files to the correct location
    log_info "Organizing ImGui backend files..."
    if [ -d "${LIBS_DIR}/imgui_backends/backends" ]; then
        # Move backend files from backends/ subdirectory to root of imgui_backends
        find "${LIBS_DIR}/imgui_backends/backends" -name "*.cpp" -o -name "*.h" | while read -r file; do
            local filename
            filename=$(basename "$file")
            if [ ! -f "${LIBS_DIR}/imgui_backends/${filename}" ]; then
                cp "$file" "${LIBS_DIR}/imgui_backends/"
                log_info "Copied: ${filename}"
            fi
        done
    fi
    
    # Setup stb (image loading library)
    setup_library \
        "stb" \
        "https://github.com/nothings/stb.git" \
        "${LIBS_DIR}/stb" \
        "master" \
        "stb_image.h"
    
    # Verify final library structure
    log_info "Verifying final library structure..."
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
        exit 1
    fi
    
    log_success "All libraries downloaded and organized successfully!"
}

# Clean up library folders to keep only essential files
cleanup_library_folders() {
    log_info "Cleaning up library folders to keep only essential files..."
    
    # Clean up ImGui folder - keep only core files
    if [ -d "${LIBS_DIR}/imgui" ]; then
        log_info "Cleaning ImGui folder..."
        
        # Files we want to keep
        local keep_files=(
            "imgui.h"
            "imgui.cpp"
            "imgui_demo.cpp"
            "imgui_draw.cpp"
            "imgui_tables.cpp"
            "imgui_widgets.cpp"
            "imgui_internal.h"
            "imconfig.h"
            "imstb_rectpack.h"
            "imstb_textedit.h"
            "imstb_truetype.h"
        )
        
        # Remove unnecessary directories
        local remove_dirs=(
            "examples"
            "docs"
            ".github"
            "misc"
            "backends"
            "tests"
            "benchmarks"
            "tools"
            "extras"
            "bindings"
            "port"
            "porting"
        )
        
        for dir in "${remove_dirs[@]}"; do
            if [ -d "${LIBS_DIR}/imgui/${dir}" ]; then
                rm -rf "${LIBS_DIR}/imgui/${dir}"
                log_info "Removed: ${dir}/"
            fi
        done
        
        # Remove ALL files except the ones we need
        find "${LIBS_DIR}/imgui" -type f | while read -r file; do
            local filename
            filename=$(basename "$file")
            local should_keep=false
            
            for keep_file in "${keep_files[@]}"; do
                if [ "$filename" = "$keep_file" ]; then
                    should_keep=true
                    break
                fi
            done
            
            if [ "$should_keep" = false ]; then
                rm -f "$file"
                log_info "Removed: ${filename}"
            fi
        done
        
        # Verify essential files still exist
        local missing_essential=()
        for file in "${keep_files[@]}"; do
            if [ ! -f "${LIBS_DIR}/imgui/${file}" ]; then
                missing_essential+=("${file}")
            fi
        done
        
        if [ ${#missing_essential[@]} -gt 0 ]; then
            log_error "Essential ImGui files missing after cleanup: ${missing_essential[*]}"
            exit 1
        fi
        
        # Remove any hidden files that might remain
        find "${LIBS_DIR}/imgui" -type f -name ".*" -delete
        
        # Remove any other non-essential files (like .md, .txt, etc.)
        find "${LIBS_DIR}/imgui" -type f \( -name "*.md" -o -name "*.txt" -o -name "*.rst" -o -name "*.yml" -o -name "*.yaml" -o -name "*.json" -o -name "*.xml" -o -name "*.html" -o -name "*.css" -o -name "*.js" \) -delete
        
        log_success "ImGui folder cleaned - kept only essential files"
    fi
    
    # Clean up ImGui backends folder - keep only GLFW and OpenGL3
    if [ -d "${LIBS_DIR}/imgui_backends" ]; then
        log_info "Cleaning ImGui backends folder..."
        
        # Files we want to keep
        local keep_backend_files=(
            "imgui_impl_glfw.h"
            "imgui_impl_glfw.cpp"
            "imgui_impl_opengl3.h"
            "imgui_impl_opengl3.cpp"
            "imgui_impl_opengl3_loader.h"
        )
        
        # Remove unnecessary directories first
        local remove_backend_dirs=(
            "backends"
            "examples"
            "docs"
            ".github"
            "misc"
            "tests"
            "benchmarks"
            "tools"
            "extras"
            "bindings"
            "port"
            "porting"
        )
        
        for dir in "${remove_backend_dirs[@]}"; do
            if [ -d "${LIBS_DIR}/imgui_backends/${dir}" ]; then
                rm -rf "${LIBS_DIR}/imgui_backends/${dir}"
                log_info "Removed backend directory: ${dir}/"
            fi
        done
        
        # Remove unnecessary files
        local remove_backend_files=(
            "LICENSE.txt"
            ".gitignore"
            ".editorconfig"
            ".gitattributes"
        )
        
        for file in "${remove_backend_files[@]}"; do
            if [ -f "${LIBS_DIR}/imgui_backends/${file}" ]; then
                rm -f "${LIBS_DIR}/imgui_backends/${file}"
                log_info "Removed backend file: ${file}"
            fi
        done
        
        # Remove ALL files except the ones we need
        find "${LIBS_DIR}/imgui_backends" -type f | while read -r file; do
            local filename
            filename=$(basename "$file")
            local should_keep=false
            
            for keep_file in "${keep_backend_files[@]}"; do
                if [ "$filename" = "$keep_file" ]; then
                    should_keep=true
                    break
                fi
            done
            
            if [ "$should_keep" = false ]; then
                rm -f "$file"
                log_info "Removed backend: ${filename}"
            fi
        done
        
        # Verify essential backend files still exist
        local missing_backends=()
        for file in "${keep_backend_files[@]}"; do
            if [ ! -f "${LIBS_DIR}/imgui_backends/${file}" ]; then
                missing_backends+=("${file}")
            fi
        done
        
        if [ ${#missing_backends[@]} -gt 0 ]; then
            log_error "Essential backend files missing after cleanup: ${missing_backends[*]}"
            exit 1
        fi
        
        # Remove any hidden files that might remain
        find "${LIBS_DIR}/imgui_backends" -type f -name ".*" -delete
        
        # Remove any other non-essential files (like .md, .txt, etc.)
        find "${LIBS_DIR}/imgui_backends" -type f \( -name "*.md" -o -name "*.txt" -o -name "*.rst" -o -name "*.yml" -o -name "*.yaml" -o -name "*.json" -o -name "*.xml" -o -name "*.html" -o -name "*.css" -o -name "*.js" \) -delete
        
        # Remove any remaining directories (nuclear option)
        find "${LIBS_DIR}/imgui_backends" -type d -mindepth 1 -delete
        
        log_success "ImGui backends folder cleaned - kept only GLFW and OpenGL3"
    fi
    
    # Clean up stb folder - keep only stb_image.h
    if [ -d "${LIBS_DIR}/stb" ]; then
        log_info "Cleaning stb folder..."
        
        # Remove all files except stb_image.h
        find "${LIBS_DIR}/stb" -type f ! -name "stb_image.h" -delete
        
        # Remove all directories (including .git)
        find "${LIBS_DIR}/stb" -type d -mindepth 1 -delete
        
        # Remove any remaining hidden files except stb_image.h
        find "${LIBS_DIR}/stb" -type f ! -name "stb_image.h" -delete
        
        # Verify stb_image.h still exists
        if [ ! -f "${LIBS_DIR}/stb/stb_image.h" ]; then
            log_error "stb_image.h missing after cleanup"
            exit 1
        fi
        
        # Verify folder is clean (should only contain stb_image.h)
        local stb_file_count
        stb_file_count=$(find "${LIBS_DIR}/stb" -type f | wc -l)
        if [ "$stb_file_count" -ne 1 ]; then
            log_warning "stb folder contains ${stb_file_count} files (expected 1)"
        fi
        
        # Remove any hidden files that might remain
        find "${LIBS_DIR}/stb" -type f -name ".*" -delete
        
        # Remove any other non-essential files (like .md, .txt, etc.)
        find "${LIBS_DIR}/stb" -type f \( -name "*.md" -o -name "*.txt" -o -name "*.rst" -o -name "*.yml" -o -name "*.yaml" -o -name "*.json" -o -name "*.xml" -o -name "*.html" -o -name "*.css" -o -name "*.js" \) -delete
        
        log_success "stb folder cleaned - kept only stb_image.h"
    fi
    
    # Final verification - check that all folders are clean
    log_info "Performing final verification of cleaned library folders..."
    
    # Check imgui folder
    local imgui_file_count
    imgui_file_count=$(find "${LIBS_DIR}/imgui" -type f | wc -l)
    if [ "$imgui_file_count" -ne 11 ]; then
        log_warning "imgui folder contains ${imgui_file_count} files (expected 11)"
    else
        log_success "imgui folder: ${imgui_file_count} essential files"
    fi
    
    # Check imgui_backends folder
    local backends_file_count
    backends_file_count=$(find "${LIBS_DIR}/imgui_backends" -type f | wc -l)
    if [ "$backends_file_count" -ne 5 ]; then
        log_warning "imgui_backends folder contains ${backends_file_count} files (expected 5)"
    else
        log_success "imgui_backends folder: ${backends_file_count} essential files"
    fi
    
    # Check stb folder
    local stb_file_count
    stb_file_count=$(find "${LIBS_DIR}/stb" -type f | wc -l)
    if [ "$stb_file_count" -ne 1 ]; then
        log_warning "stb folder contains ${stb_file_count} files (expected 1)"
    else
        log_success "stb folder: ${stb_file_count} essential file"
    fi
    
    log_success "All library folders cleaned successfully!"
}





# Validate final project structure
validate_project_structure() {
    log_info "Validating final project structure..."
    
    local required_items=(
        "src"
        "src/main.cpp"
        "CMakeLists.txt"
        "README.md"
    )
    
    local missing_items=()
    
    for item in "${required_items[@]}"; do
        if [ ! -e "${MACOS_122_DIR}/${item}" ]; then
            missing_items+=("${item}")
        fi
    done
    
    if [ ${#missing_items[@]} -gt 0 ]; then
        log_error "Missing required project items: ${missing_items[*]}"
        exit 1
    fi
    
    log_success "Project structure validation passed"
}

# Main execution
main() {
    log_info "Managing MacOS 12.2 libraries for existing project..."
    log_info "Root directory: ${ROOT_DIR}"
    log_info "Target directory: ${MACOS_122_DIR}"
    log_info "Libraries directory: ${LIBS_DIR}"
    
    validate_environment
    check_existing_project
    download_and_manage_libraries
    cleanup_library_folders
    validate_project_structure
    
    log_success "Library management completed successfully!"
    log_success "Source code preserved in: ${MACOS_122_DIR}"
    log_success "Libraries managed in: ${LIBS_DIR}"
    echo
    log_info "Next steps:"
    echo "    1. ./build_app_macos122.sh"
    echo
    log_info "Your source code is safe and ready for GitHub version control!"
    log_info "Libraries are automatically managed and kept up-to-date!"
}

# Run main function
main "$@"
