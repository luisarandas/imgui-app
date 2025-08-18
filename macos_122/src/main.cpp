#define IMGUI_DEFINE_MATH_OPERATORS
#include "imgui.h"
#include "imgui_internal.h"

#define IMAPP_IMPL

#include "imgui_impl_glfw.h"
#include "imgui_impl_opengl3.h"

#include <iostream>
#include <vector>
#include <string>
#include <filesystem>
#if defined(__APPLE__)
#include <mach-o/dyld.h>
#endif

#define GL_SILENCE_DEPRECATION
#if defined(IMGUI_IMPL_OPENGL_ES2)
#include <GLES2/gl2.h>
#endif
#include <GLFW/glfw3.h>

#if defined(_MSC_VER) && (_MSC_VER >= 1900) && !defined(IMGUI_DISABLE_WIN32_FUNCTIONS)
#pragma comment(lib, "legacy_stdio_definitions")
#pragma comment(linker, "/SUBSYSTEM:windows /ENTRY:mainCRTStartup")
#endif

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

void setup_fonts(ImGuiIO& io);
void setup_logo(GLFWwindow* window);


static std::filesystem::path getDataPath() {
    // Priority 1: Bundle Resources (macOS) - CHECK FIRST!
    // tested macos.Monterey 12.2
    #if defined(__APPLE__)
        uint32_t bufsize = 0;
        _NSGetExecutablePath(nullptr, &bufsize);
        std::string execPath(bufsize, '\0');
        if (_NSGetExecutablePath(execPath.data(), &bufsize) == 0) {
            std::filesystem::path execP(execPath.c_str());
            auto resources = execP.parent_path().parent_path() / "Resources" / "data";
            if (std::filesystem::exists(resources) && std::filesystem::is_directory(resources)) {
                return resources;  // ← BUNDLE FIRST (production)
            }
        }
    #endif
    
    // Priority 2: Development data folder (current working directory)
    std::filesystem::path cwdData = std::filesystem::current_path() / "data";
    if (std::filesystem::exists(cwdData) && std::filesystem::is_directory(cwdData)) {
        return cwdData;  // ← DEVELOPMENT FALLBACK
    }
    
    // Priority 3: Executable-relative data folder (cross-platform)
    std::filesystem::path execDir = std::filesystem::current_path();
    auto relativeData = execDir / "data";
    if (std::filesystem::exists(relativeData) && std::filesystem::is_directory(relativeData)) {
        return relativeData;
    }
    
    // Priority 4: System-wide paths (Linux/Unix)
    std::vector<std::filesystem::path> systemPaths = {
        "/usr/local/share/cmake_imgui_app_macos/data",
        "/opt/local/share/cmake_imgui_app_macos/data",
        "/usr/share/cmake_imgui_app_macos/data"
    };
    
    for (const auto& path : systemPaths) {
        if (std::filesystem::exists(path) && std::filesystem::is_directory(path)) {
            return path;
        }
    }
    
    // Last resort: return current working directory + data
    return std::filesystem::current_path() / "data";
}

void glfw_error_callback(int error, const char* description) {
    fprintf(stderr, "Glfw Error %d: %s\n", error, description);
}

GLuint LoadTextureFromFile(const char* filename) {
    int width, height, channels;
    unsigned char* data = stbi_load(filename, &width, &height, &channels, 4);
    if (!data) {
        std::cerr << "Failed to load image: " << filename << std::endl;
        return 0;
    }
    GLuint texture;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    // Ensure rows are tightly packed regardless of width
    GLint prevUnpackAlign = 0;
    glGetIntegerv(GL_UNPACK_ALIGNMENT, &prevUnpackAlign);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glPixelStorei(GL_UNPACK_ALIGNMENT, prevUnpackAlign);
    glBindTexture(GL_TEXTURE_2D, 0);
    stbi_image_free(data);
    return texture;
}

bool EndsWith(const std::string& str, const std::string& suffix) {
    return str.size() >= suffix.size() && str.compare(str.size() - suffix.size(), suffix.size(), suffix) == 0;
}

std::vector<std::string> GetImageFiles(const std::string& directory) {
    std::vector<std::string> image_files;
    std::filesystem::path dirPath(directory);
    if (!std::filesystem::exists(dirPath) || !std::filesystem::is_directory(dirPath)) {
        return image_files;
    }
    for (const auto& entry : std::filesystem::directory_iterator(dirPath)) {
        if (entry.is_regular_file()) {
            std::string path = entry.path().string();
            if (EndsWith(path, ".png") || EndsWith(path, ".jpg") || EndsWith(path, ".jpeg")) {
                image_files.push_back(path);
            }
        }
    }
    return image_files;
}

void ShowImageSubwindow(const char* title, const std::string& directory, int width = -1, int height = -1) {
    static std::vector<std::string> image_files;
    static std::string last_directory;
    if (last_directory != directory) {
        image_files = GetImageFiles(directory);
        last_directory = directory;
    }
    static size_t current_image_index = 0;
    static GLuint texture = 0;
    static int img_width = 0, img_height = 0;

    if (texture == 0 && !image_files.empty()) {
        const std::string& image_path = image_files[current_image_index];
        int channels;
        unsigned char* data = stbi_load(image_path.c_str(), &img_width, &img_height, &channels, 4);
        if (data) {
            glGenTextures(1, &texture);
            glBindTexture(GL_TEXTURE_2D, texture);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, img_width, img_height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glBindTexture(GL_TEXTURE_2D, 0);
            stbi_image_free(data);
        } else {
            std::cerr << "Failed to load image: " << image_path << std::endl;
            return;
        }
    }

    ImVec2 size = ImVec2(width, height);
    if (width == -1 || height == -1) {
        ImVec2 parent_size = ImGui::GetContentRegionAvail();
        if (width == -1) size.x = parent_size.x;
        if (height == -1) size.y = parent_size.y;
    }

    ImGui::BeginChild(title, size, true, ImGuiWindowFlags_NoScrollbar);

    float fixed_height = 150.0f;
    float fixed_width = fixed_height * (static_cast<float>(img_width) / img_height);

    // Draw the image first
    ImGui::Image((void*)(intptr_t)texture, ImVec2(fixed_width, fixed_height));
    
    // Draw white border on top of the image
    ImVec2 image_p_min = ImGui::GetItemRectMin();
    ImVec2 image_p_max = ImGui::GetItemRectMax();
    ImDrawList* draw_list = ImGui::GetWindowDrawList();
    draw_list->AddRect(image_p_min, image_p_max, IM_COL32(255, 255, 255, 255), 0.0f, 0, 2.0f);

    ImGui::SetCursorPosY(ImGui::GetCursorPosY() + 10);
    ImGui::PushStyleColor(ImGuiCol_Button, IM_COL32(255, 192, 203, 255));
    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, IM_COL32(255, 0, 0, 255));
    ImGui::PushStyleColor(ImGuiCol_Text, IM_COL32(0, 0, 0, 255));

    if (ImGui::Button("<-")) {
        if (current_image_index > 0) {
            current_image_index--;
            glDeleteTextures(1, &texture);
            texture = 0;
        }
    }
    ImGui::SameLine();
    if (ImGui::Button("->")) {
        if (current_image_index + 1 < image_files.size()) {
            current_image_index++;
            glDeleteTextures(1, &texture);
            texture = 0;
        }
    }
    ImGui::PopStyleColor(3);

    ImGui::SetCursorPosY(ImGui::GetCursorPosY() + 10);
    ImGui::Text("%s", title);

    if (!image_files.empty()) {
        ImGui::Text("Current media: %s", image_files[current_image_index].c_str());
    }

    ImGui::EndChild();
}

int main(int, char**) {
    glfwSetErrorCallback(glfw_error_callback);
    if (!glfwInit())
        return 1;

#if defined(IMGUI_IMPL_OPENGL_ES2)
    const char* glsl_version = "#version 100";
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
    glfwWindowHint(GLFW_CLIENT_API, GLFW_OPENGL_ES_API);
#elif defined(__APPLE__)
    const char* glsl_version = "#version 150";
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
#else
    const char* glsl_version = "#version 130";
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
#endif

    GLFWwindow* window = glfwCreateWindow(1280, 720, "cmake_imgui_app_macos", NULL, NULL);
    if (!window) {
        std::cerr << "Failed to create GLFW window" << std::endl;
        glfwTerminate();
        return -1;
    }

    glfwMakeContextCurrent(window);
    glfwSwapInterval(1);

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGui::StyleColorsDark();
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    io.IniFilename = NULL;

    ImGui::StyleColorsDark();

    ImGui_ImplGlfw_InitForOpenGL(window, true);
    ImGui_ImplOpenGL3_Init(glsl_version);

    setup_fonts(io);
    setup_logo(window);

    bool show_demo_window = false;
    bool show_another_window = false;
    ImVec4 clear_color = ImVec4(1.0f, 1.0f, 1.0f, 1.0f);

    while (!glfwWindowShouldClose(window))
    {
        glfwPollEvents();

        ImGui_ImplOpenGL3_NewFrame();
        ImGui_ImplGlfw_NewFrame();
        ImGui::NewFrame();

        if (ImGui::BeginMainMenuBar()) {
            if (ImGui::BeginMenu("File")) { ImGui::EndMenu(); }
            if (ImGui::BeginMenu("Edit")) { ImGui::EndMenu(); }
            if (ImGui::BeginMenu("Exit")) { ImGui::EndMenu(); }
            ImGui::EndMainMenuBar();
        }

        ImGui::SetNextWindowPos(ImVec2(0, ImGui::GetFrameHeight()));
        ImGui::SetNextWindowSize(ImVec2(ImGui::GetIO().DisplaySize.x, ImGui::GetIO().DisplaySize.y - ImGui::GetFrameHeight()));
        ImGui::Begin("Main Window", nullptr, ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoMove);

        ImGui::PushStyleColor(ImGuiCol_ChildBg, ImVec4(0.4f, 0.4f, 0.4f, 0.8f));
        ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.6f, 1.0f, 0.0f, 1.0f));

        ImGui::BeginChild("panel_window1", ImVec2(ImGui::GetContentRegionAvail().x / 3, ImGui::GetContentRegionAvail().y), true);
        ImGui::Text("Panel 1");
        auto dataPath = getDataPath();
        ShowImageSubwindow("(Image Folder Navigator)", dataPath.string(), -1, 250);
        ImGui::EndChild();

        ImGui::SameLine();
        ImGui::BeginChild("panel_window2", ImVec2(ImGui::GetContentRegionAvail().x / 2, ImGui::GetContentRegionAvail().y), true);
        ImGui::Text("Panel 2");
        ImGui::EndChild();

        ImGui::SameLine();
        ImGui::BeginChild("panel_window3", ImVec2(0, ImGui::GetContentRegionAvail().y), true);
        ImGui::Text("Panel 3");
        ImGui::EndChild();

        ImGui::PopStyleColor(2);
        ImGui::End();

        if (show_another_window)
        {
            ImGui::Begin("Another Window", &show_another_window);
            ImGui::Text("Hello from another window!");
            if (ImGui::Button("Close Me"))
                show_another_window = false;
            ImGui::End();
        }

        ImGui::Render();
        int display_w, display_h;
        glfwGetFramebufferSize(window, &display_w, &display_h);
        glViewport(0, 0, display_w, display_h);
        glClearColor(clear_color.x * clear_color.w, clear_color.y * clear_color.w, clear_color.z * clear_color.w, clear_color.w);
        glClear(GL_COLOR_BUFFER_BIT);
        ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());

        glfwSwapBuffers(window);
    }

    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplGlfw_Shutdown();
    ImGui::DestroyContext();

    glfwDestroyWindow(window);
    glfwTerminate();

    return 0;
}

void setup_fonts(ImGuiIO& io) {
    std::filesystem::path font_path = getDataPath() / "DejaVuSans.ttf";
    if (std::filesystem::exists(font_path)) {
        io.Fonts->AddFontFromFileTTF(font_path.string().c_str(), 14.0f);
    } else {
        std::cerr << "Font file not found: " << font_path << std::endl;
    }
}

void setup_logo(GLFWwindow* window) {
    std::filesystem::path logo_path = getDataPath() / "logo_viewport.png";
    if (std::filesystem::exists(logo_path)) {
        int logo_width, logo_height, channels;
        unsigned char* logo_pixels = stbi_load(logo_path.string().c_str(), &logo_width, &logo_height, &channels, 4);
        if (logo_pixels) {
            GLFWimage images[1];
            images[0].width = logo_width;
            images[0].height = logo_height;
            images[0].pixels = logo_pixels;
            glfwSetWindowIcon(window, 1, images);
            stbi_image_free(logo_pixels);
        } else {
            std::cerr << "Failed to load logo image: " << logo_path << std::endl;
        }
    } else {
        std::cerr << "Logo file not found: " << logo_path << std::endl;
    }
}


