#!/usr/bin/env bash
set -euo pipefail

# Download minimal third-party libs for macOS build into ../libs (gitignored)
# - ImGui (ocornut/imgui)
# - ImGui backends (taken from imgui repo)
# - stb (nothings/stb) — only stb_image.h needed

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
LIBS_DIR="${ROOT_DIR}/libs"
IMGUI_DIR="${LIBS_DIR}/imgui"
IMGUI_BACKENDS_DIR="${LIBS_DIR}/imgui_backends"
STB_DIR="${LIBS_DIR}/stb"

mkdir -p "${IMGUI_DIR}" "${IMGUI_BACKENDS_DIR}" "${STB_DIR}"

IMGUI_VER="v1.90.9"
IMGUI_ZIP="${LIBS_DIR}/imgui-${IMGUI_VER}.zip"
IMGUI_URL="https://github.com/ocornut/imgui/archive/refs/tags/${IMGUI_VER}.zip"

STB_URL="https://raw.githubusercontent.com/nothings/stb/master/stb_image.h"
IMCONFIG_URL="https://raw.githubusercontent.com/ocornut/imgui/master/imconfig.h"

need_imgui=false
for f in imgui.h imgui.cpp imgui_demo.cpp imgui_draw.cpp imgui_tables.cpp imgui_widgets.cpp; do
  if [ ! -f "${IMGUI_DIR}/${f}" ]; then need_imgui=true; fi
done

if [ "$need_imgui" = true ]; then
  echo "[i] Fetching Dear ImGui ${IMGUI_VER}..."
  curl -L "${IMGUI_URL}" -o "${IMGUI_ZIP}"
  unzip -q -o "${IMGUI_ZIP}" -d "${LIBS_DIR}"
  SRC_DIR="${LIBS_DIR}/imgui-${IMGUI_VER#v}"
  rsync -a "${SRC_DIR}/" "${IMGUI_DIR}/" \
    --include="imgui*.h" \
    --include="imgui*.cpp" \
    --include="imconfig.h" \
    --include="imstb_*.h" \
    --exclude="*" >/dev/null 2>&1 || true
  # Backends
  rsync -a "${SRC_DIR}/backends/" "${IMGUI_BACKENDS_DIR}/" --include="imgui_impl_glfw.*" --include="imgui_impl_opengl3.*" --include="imgui_impl_opengl3_loader.h" --exclude="*" >/dev/null 2>&1 || true
  echo "[i] Dear ImGui downloaded."
  # Cleanup extracted archive dir and zip
  rm -rf "${SRC_DIR}"
  rm -f "${IMGUI_ZIP}"
fi

if [ ! -f "${STB_DIR}/stb_image.h" ]; then
  echo "[i] Fetching stb_image.h..."
  curl -L "${STB_URL}" -o "${STB_DIR}/stb_image.h"
fi

# Ensure imconfig.h exists (some distros omit it); fetch a default if missing
if [ ! -f "${IMGUI_DIR}/imconfig.h" ]; then
  echo "[i] Fetching default imconfig.h..."
  curl -L "${IMCONFIG_URL}" -o "${IMGUI_DIR}/imconfig.h"
fi

check_system_glfw() {
  if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists glfw3; then
    # Validate that the library path exists and contains a glfw lib
    local libs
    libs="$(pkg-config --libs glfw3 2>/dev/null || true)"
    # Extract first -L path
    local libdir
    libdir="$(echo "$libs" | tr ' ' '\n' | awk '/^-L/{print substr($0,3); exit}')"
    if [ -n "$libdir" ] && [ -d "$libdir" ] && ls "$libdir"/libglfw* >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

ensure_local_glfw() {
  local GLFW_DIR="${LIBS_DIR}/glfw"
  local GLVER="3.3.8"
  local GLURL="https://github.com/glfw/glfw/archive/refs/tags/${GLVER}.zip"
  local GLSRC_ZIP="${GLFW_DIR}/src/${GLVER}.zip"
  local GLSRC_DIR="${GLFW_DIR}/src/glfw-${GLVER}"
  local GLBUILD_DIR="${GLFW_DIR}/src/build"

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
  cmake -S "${GLSRC_DIR}" -B "${GLBUILD_DIR}" -DGLFW_BUILD_DOCS=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_EXAMPLES=OFF
  echo "[i] Building GLFW..."
  cmake --build "${GLBUILD_DIR}" --config Release

  echo "[i] Staging GLFW headers and libs under libs/glfw"
  mkdir -p "${GLFW_DIR}/include" "${GLFW_DIR}/lib"
  rsync -a "${GLSRC_DIR}/include/" "${GLFW_DIR}/include/"

  local GL_LIB=""
  for f in "${GLBUILD_DIR}"/src/Release/* "${GLBUILD_DIR}"/src/*; do
    case "$f" in
      *.a|*.dylib) GL_LIB="$f" ;;
    esac
  done
  if [ -z "${GL_LIB}" ]; then
    echo "[!] Could not find built GLFW library in ${GLBUILD_DIR}"
    return 1
  fi
  cp -f "${GL_LIB}" "${GLFW_DIR}/lib/"
  echo "[i] Local GLFW ready at ${GLFW_DIR}"
}

echo "[i] Libraries present under ${LIBS_DIR}."
echo "[i] Pruned temporary archives and extracted folders."

# Final cleanup regardless of download path
SRC_DIR="${LIBS_DIR}/imgui-${IMGUI_VER#v}"
if [ -d "${SRC_DIR}" ]; then
  rm -rf "${SRC_DIR}"
fi
if [ -f "${IMGUI_ZIP}" ]; then
  rm -f "${IMGUI_ZIP}"
fi

# Ensure GLFW: prefer system via pkg-config; otherwise build locally under libs/glfw
if check_system_glfw; then
  echo "[i] System GLFW (pkg-config) detected; no local build required."
else
  echo "[i] System GLFW not found or invalid; preparing local GLFW under libs/glfw..."
  ensure_local_glfw || exit 1
fi

# Remove empty GLFW dir if it exists and is empty (in case of early exits)
if [ -d "${LIBS_DIR}/glfw" ] && [ -z "$(ls -A "${LIBS_DIR}/glfw" 2>/dev/null || echo)" ]; then rmdir "${LIBS_DIR}/glfw"; fi


