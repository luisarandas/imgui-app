#!/usr/bin/env bash
set -euo pipefail

# macOS one-shot builder for the ImGui app
# - Ensures Command Line Tools (CLT)
# - Uses pkg-config GLFW if present; otherwise builds GLFW locally under ../libs/glfw (gitignored)
# - Detects architecture and sets MACOSX_DEPLOYMENT_TARGET=12.2 for baseline compatibility
# - Builds .app bundle to macos/application/
# - Optional: pass --package to also create a DMG (DragNDrop)

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
MACOS_DIR="${ROOT_DIR}/macos"
LIBS_DIR="${ROOT_DIR}/libs"
BUILD_DIR="${MACOS_DIR}/build"
APP_DIR="${MACOS_DIR}/application"
ARCH="$(uname -m)"
MAKE_DMG=false

for arg in "$@"; do
  case "$arg" in
    --package) MAKE_DMG=true ;;
  esac
done

export MACOSX_DEPLOYMENT_TARGET="12.2"

echo "[i] Target macOS deployment: ${MACOSX_DEPLOYMENT_TARGET}"
echo "[i] CPU architecture: ${ARCH}"

mkdir -p "${BUILD_DIR}" "${APP_DIR}"

MACOS_VER="$(sw_vers -productVersion 2>/dev/null || echo "unknown")"
echo "[i] Detected macOS version: ${MACOS_VER}"

ensure_clt() {
  local devdir
  devdir="$(xcode-select -p 2>/dev/null || true)"
  if [ -z "$devdir" ] || [ ! -d "$devdir" ]; then
    echo "[!] Xcode Command Line Tools are not configured."
    if [ -d "/Library/Developer/CommandLineTools" ]; then
      echo "[i] Switching to CommandLineTools..."
      sudo xcode-select --switch "/Library/Developer/CommandLineTools" || {
        echo "[!] Failed to switch developer dir. Try: sudo xcode-select --switch /Library/Developer/CommandLineTools" ; exit 2 ; }
    else
      echo "[i] Triggering CLT installer..."
      xcode-select --install || true
      echo "[!] Complete the CLT installation in the dialog, then re-run: ${MACOS_DIR}/build_app.sh"
      exit 2
    fi
  fi
}

ensure_clt

if ! command -v clang >/dev/null 2>&1; then
  echo "[!] clang not found; ensure CLT is installed and active. Developer dir: $(xcode-select -p 2>/dev/null || echo "(none)")"
  exit 2
fi
echo 'int main(){return 0;}' | clang -x c++ - -std=c++17 -o /tmp/cc_test.$$ >/dev/null 2>&1 || {
  echo "[!] clang test compile failed. Developer dir: $(xcode-select -p 2>/dev/null || echo "(none)")"
  echo "    Try: sudo xcode-select --switch /Library/Developer/CommandLineTools"
  echo "    Or run: xcode-select --install"
  exit 2
}
rm -f /tmp/cc_test.$$

if ! command -v cmake >/dev/null 2>&1; then
  echo "[!] cmake is required but was not found. Install via Homebrew (brew install cmake) or from https://cmake.org/download/"
  exit 2
fi

for tool in curl unzip; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "[!] $tool is required but not found. Install via Homebrew: brew install $tool"
    exit 2
  fi
done

export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}:/opt/homebrew/lib/pkgconfig:/usr/local/lib/pkgconfig"

use_pkg=false
if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists glfw3; then
  use_pkg=true
fi

if [ "$use_pkg" = true ]; then
  echo "[i] Using system GLFW via pkg-config"
  # Ensure core libs exist; download if missing (imgui/backends/stb)
  (cd "${MACOS_DIR}" && bash ./download_libs.sh)
  (cd "${BUILD_DIR}" && cmake .. -DCMAKE_OSX_ARCHITECTURES="${ARCH}" && cmake --build . --config Release)
else
  echo "[i] pkg-config glfw3 not found; building local GLFW"
  GLFW_DIR="${LIBS_DIR}/glfw"
  mkdir -p "${GLFW_DIR}"
  # Ensure core libs exist; download if missing (imgui/backends/stb)
  (cd "${MACOS_DIR}" && bash ./download_libs.sh)
  GLVER="3.3.8"
  GLURL="https://github.com/glfw/glfw/archive/refs/tags/${GLVER}.zip"
  GLSRC_ZIP="${GLFW_DIR}/src/${GLVER}.zip"
  GLSRC_DIR="${GLFW_DIR}/src/glfw-${GLVER}"
  GLBUILD_DIR="${GLFW_DIR}/src/build"

  mkdir -p "${GLFW_DIR}/src"
  if [ ! -f "${GLSRC_ZIP}" ]; then
    echo "[i] Downloading GLFW ${GLVER}..."
    curl -L "${GLURL}" -o "${GLSRC_ZIP}"
  fi
  if [ ! -d "${GLSRC_DIR}" ]; then
    echo "[i] Extracting GLFW ${GLVER}..."
    unzip -q "${GLSRC_ZIP}" -d "${GLFW_DIR}/src"
  fi
  echo "[i] Configuring GLFW..."
  mkdir -p "${GLBUILD_DIR}"
  cmake -S "${GLSRC_DIR}" -B "${GLBUILD_DIR}" -DGLFW_BUILD_DOCS=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_EXAMPLES=OFF -DCMAKE_OSX_ARCHITECTURES="${ARCH}"
  echo "[i] Building GLFW..."
  cmake --build "${GLBUILD_DIR}" --config Release

  echo "[i] Staging GLFW headers and libs under libs/glfw"
  mkdir -p "${GLFW_DIR}/include" "${GLFW_DIR}/lib"
  rsync -a "${GLSRC_DIR}/include/" "${GLFW_DIR}/include/"

  GL_LIB=""
  for f in "${GLBUILD_DIR}"/src/Release/* "${GLBUILD_DIR}"/src/*; do
    case "$f" in
      *.a|*.dylib) GL_LIB="$f" ;;
    esac
  done
  if [ -z "${GL_LIB}" ]; then
    echo "[!] Could not find built GLFW library in ${GLBUILD_DIR}"
    exit 1
  fi
  cp -f "${GL_LIB}" "${GLFW_DIR}/lib/"

  echo "[i] Building ImGui app with local GLFW"
  (cd "${BUILD_DIR}" && cmake .. -DGLFW3_INCLUDE_DIRS="${GLFW_DIR}/include" -DGLFW3_LIBRARIES="${GLFW_DIR}/lib/$(basename "${GL_LIB}")" -DCMAKE_OSX_ARCHITECTURES="${ARCH}" && cmake --build . --config Release)
fi

APP_BUNDLE="${APP_DIR}/cmake_imgui_app_macos.app"
if [ -d "${APP_BUNDLE}" ]; then
  echo "[i] Built app bundle at: ${APP_BUNDLE}"
else
  echo "[!] Build finished but app bundle not found. Check build logs."
  exit 2
fi

if [ "$MAKE_DMG" = true ]; then
  echo "[i] Creating DMG via CPack..."
  (cd "${BUILD_DIR}" && cpack -G DragNDrop)
  echo "[i] DMG files:"
  ls -1 "${BUILD_DIR}"/*.dmg || true
fi

echo "[i] Done. You can open the app with: open '${APP_BUNDLE}'"


