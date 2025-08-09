// ---------------------------------------------
// ---------------------------------------------
/*
    ImGUI library simple app
    27-02-2023 luisarandas
*/

#include "imgui.h"
#define IMGUI_DEFINE_MATH_OPERATORS
#include "imgui_internal.h"

#define IMAPP_IMPL

#include "imgui_impl_glfw.h"
#include "imgui_impl_opengl3.h"

#include <iostream>
#include <vector>
#include <string>
#include <filesystem>

#define GL_SILENCE_DEPRECATION
#if defined(IMGUI_IMPL_OPENGL_ES2)
#include <GLES2/gl2.h>
#endif
#include <GLFW/glfw3.h> // will drag system OpenGL headers

// imgui team [Win32] example includes a copy of glfw3.lib pre-compiled with VS2010 to maximize ease of testing and compatibility with old VS compilers.
// To link with VS2010-era libraries, VS2015+ requires linking with legacy_stdio_definitions.lib, which we do using this pragma.
// Your own project should not be affected, as you are likely to link with a newer binary of GLFW that is adequate for your version of Visual Studio.
#if defined(_MSC_VER) && (_MSC_VER >= 1900) && !defined(IMGUI_DISABLE_WIN32_FUNCTIONS)
#pragma comment(lib, "legacy_stdio_definitions")
#pragma comment(linker, "/SUBSYSTEM:windows /ENTRY:mainCRTStartup") // I believe this will run and stop console from popping up
#endif

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"


// ---------------------------------------------
// ---------------------------------------------

void setup_fonts(ImGuiIO& io);
void setup_logo(GLFWwindow* window);


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
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glBindTexture(GL_TEXTURE_2D, 0);

    stbi_image_free(data);
    return texture;
}



// Utility function to check if a string ends with a specific suffix
bool EndsWith(const std::string& str, const std::string& suffix) {
    return str.size() >= suffix.size() &&
           str.compare(str.size() - suffix.size(), suffix.size(), suffix) == 0;
}

// Function to scan the directory and get a list of image files
std::vector<std::string> GetImageFiles(const std::string& directory) {
    std::vector<std::string> image_files;
    for (const auto& entry : std::filesystem::directory_iterator(directory)) {
        if (entry.is_regular_file()) {
            std::string path = entry.path().string();
            if (EndsWith(path, ".png") || EndsWith(path, ".jpg") || EndsWith(path, ".jpeg")) {
                image_files.push_back(path);
            }
        }
    }
    return image_files;
}




void ShowImageSubwindow(const char* title, const char* directory, int width = -1, int height = -1) {
    static std::vector<std::string> image_files = GetImageFiles(directory);
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

    // Determine the size of the subwindow
    ImVec2 size = ImVec2(width, height);
    if (width == -1 || height == -1) {
        ImVec2 parent_size = ImGui::GetContentRegionAvail();
        if (width == -1) size.x = parent_size.x;
        if (height == -1) size.y = parent_size.y;
    }

    ImGui::BeginChild(title, size, true, ImGuiWindowFlags_NoScrollbar);

    // Define the fixed height for the image and calculate width to maintain aspect ratio
    float fixed_height = 150.0f;
    float fixed_width = fixed_height * (static_cast<float>(img_width) / img_height);

    // Set a black background for the image area
    ImVec2 p_min = ImGui::GetCursorScreenPos();
    ImVec2 p_max = ImVec2(p_min.x + fixed_width, p_min.y + fixed_height);
    ImDrawList* draw_list = ImGui::GetWindowDrawList();
    draw_list->AddRectFilled(p_min, p_max, IM_COL32(0, 0, 0, 255));

    // Draw the image with a white border
    ImGui::Image((void*)(intptr_t)texture, ImVec2(fixed_width, fixed_height));
    ImVec2 image_p_min = ImGui::GetItemRectMin();
    ImVec2 image_p_max = ImGui::GetItemRectMax();
    draw_list->AddRect(image_p_min, image_p_max, IM_COL32(255, 255, 255, 255), 0.0f, 0, 2.0f);

    // Navigation buttons
    ImGui::SetCursorPosY(ImGui::GetCursorPosY() + 10); // Place buttons below the image with a small padding
    ImGui::PushStyleColor(ImGuiCol_Button, IM_COL32(255, 192, 203, 255)); // Pink background
    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, IM_COL32(255, 0, 0, 255)); // Red hover
    ImGui::PushStyleColor(ImGuiCol_Text, IM_COL32(0, 0, 0, 255)); // Black text

    if (ImGui::Button("<-")) {
        // Handle previous action
        if (current_image_index > 0) {
            current_image_index--;
            glDeleteTextures(1, &texture);
            texture = 0; // Reset texture to force reloading
        }
    }
    ImGui::SameLine();
    if (ImGui::Button("->")) {
        // Handle next action
        if (current_image_index < image_files.size() - 1) {
            current_image_index++;
            glDeleteTextures(1, &texture);
            texture = 0; // Reset texture to force reloading
        }
    }
    ImGui::PopStyleColor(3);

    // Title
    ImGui::SetCursorPosY(ImGui::GetCursorPosY() + 10); // Adjust position for title
    ImGui::Text("%s", title);

    // Current media path
    if (!image_files.empty()) {
        ImGui::Text("Current media: %s", image_files[current_image_index].c_str());
    }

    ImGui::EndChild();
}







// ---------------------------------------------
// ---------------------------------------------

int main(int, char**) {
    
    // setup window

    glfwSetErrorCallback(glfw_error_callback);
    if (!glfwInit())
        return 1;

    // decide GL+GLSL versions
#if defined(IMGUI_IMPL_OPENGL_ES2)
    // GL ES 2.0 + GLSL 100
    const char* glsl_version = "#version 100";
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
    glfwWindowHint(GLFW_CLIENT_API, GLFW_OPENGL_ES_API);
#elif defined(__APPLE__)
    // GL 3.2 + GLSL 150
    const char* glsl_version = "#version 150";
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);  // 3.2+ only
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);            // Required on Mac
#else
    // GL 3.0 + GLSL 130
    const char* glsl_version = "#version 130";
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
    // glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);  // 3.2+ only
    // glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);            // 3.0+ only
#endif

    // create 720p window with graphics context
    GLFWwindow* window = glfwCreateWindow(1280, 720, "scons-imgui-app", NULL, NULL);

    if (!window) {
        std::cerr << "Failed to create GLFW window" << std::endl;
        glfwTerminate();
        return -1;
    }

    glfwMakeContextCurrent(window);
    glfwSwapInterval(1); // enable vsync

    // setup Dear ImGui context
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGui::StyleColorsDark();
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    //io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;     // Enable Keyboard Controls
    //io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;      // Enable Gamepad Controls
    io.IniFilename = NULL; // disable imgui.ini

    // Setup Dear ImGui style
    ImGui::StyleColorsDark();
    //ImGui::StyleColorsLight();

    // Setup Platform/Renderer backends
    ImGui_ImplGlfw_InitForOpenGL(window, true);
    ImGui_ImplOpenGL3_Init(glsl_version);

    

    setup_fonts(io);
    setup_logo(window);

    // Main variables in main()

    bool show_demo_window = false;
    bool show_another_window = false;
    ImVec4 clear_color = ImVec4(1.0f, 1.0f, 1.0f, 1.0f);


    // Main loop

    while (!glfwWindowShouldClose(window))
    {
        // poll and handle events (inputs, window resize, etc.)
        // You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to use your inputs.
        // - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application, or clear/overwrite your copy of the mouse data.
        // - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application, or clear/overwrite your copy of the keyboard data.
        // Generally you may always pass all inputs to dear imgui, and hide them from your application based on those two flags.
        glfwPollEvents();

        // Start the Dear ImGui frame

        ImGui_ImplOpenGL3_NewFrame();
        ImGui_ImplGlfw_NewFrame();
        ImGui::NewFrame();


        // Menu bar

        if (ImGui::BeginMainMenuBar()) {
            if (ImGui::BeginMenu("File")) {
                ImGui::MenuItem("#1", NULL);
                ImGui::MenuItem("#2", NULL);
                ImGui::MenuItem("#3", NULL);
                ImGui::EndMenu();
            }
            if (ImGui::BeginMenu("Edit")) {
                ImGui::MenuItem("#1", NULL);
                ImGui::MenuItem("#2", NULL);
                ImGui::MenuItem("#3", NULL);
                ImGui::EndMenu();
            }
            if (ImGui::BeginMenu("Exit")) {
                ImGui::MenuItem("#1", NULL);
                ImGui::MenuItem("#2", NULL);
                ImGui::MenuItem("#3", NULL);
                ImGui::EndMenu();
            }
            ImGui::EndMainMenuBar();
        }

        // Create the main window

        ImGui::SetNextWindowPos(ImVec2(0, ImGui::GetFrameHeight()));
        ImGui::SetNextWindowSize(ImVec2(ImGui::GetIO().DisplaySize.x, ImGui::GetIO().DisplaySize.y - ImGui::GetFrameHeight()));
        ImGui::Begin("Main Window", nullptr, ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoMove);

        // Customize style for panel windows
        ImGui::PushStyleColor(ImGuiCol_ChildBg, ImVec4(0.4f, 0.4f, 0.4f, 0.8f));   // Light grey background
        ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.6f, 1.0f, 0.0f, 1.0f));       // White text

        // Create sub-windows inside the main window
        ImGui::BeginChild("panel_window1", ImVec2(ImGui::GetContentRegionAvail().x / 3, ImGui::GetContentRegionAvail().y), true);
        ImGui::Text("Panel 1");

        ShowImageSubwindow("(Image Folder Navigator)", "data/", -1, 250); // Dynamic sizing

        ImGui::EndChild();
        ImGui::SameLine();
        ImGui::BeginChild("panel_window2", ImVec2(ImGui::GetContentRegionAvail().x / 2, ImGui::GetContentRegionAvail().y), true);
        ImGui::Text("Panel 2");
        ImGui::EndChild();
        ImGui::SameLine();
        ImGui::BeginChild("panel_window3", ImVec2(0, ImGui::GetContentRegionAvail().y), true); // Remaining space
        ImGui::Text("Panel 3");
        ImGui::EndChild();

        // Restore style
        ImGui::PopStyleColor(2);
        ImGui::End();

        if (show_another_window)
        {
            ImGui::Begin("Another Window", &show_another_window); // pass a pointer to our bool variable (the window will have a closing button that will clear the bool when clicked)
            ImGui::Text("Hello from another window!");
            if (ImGui::Button("Close Me"))
                show_another_window = false;
            ImGui::End();
        }

        // Rendering

        ImGui::Render();
        int display_w, display_h;
        glfwGetFramebufferSize(window, &display_w, &display_h);
        glViewport(0, 0, display_w, display_h);
        glClearColor(clear_color.x * clear_color.w, clear_color.y * clear_color.w, clear_color.z * clear_color.w, clear_color.w);
        glClear(GL_COLOR_BUFFER_BIT);
        ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());

        glfwSwapBuffers(window);
    }

    // Cleanup

    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplGlfw_Shutdown();
    ImGui::DestroyContext();

    glfwDestroyWindow(window);
    glfwTerminate();

    return 0;
}

// ---------------------------------------------
// ---------------------------------------------


void setup_fonts(ImGuiIO& io) {
    std::filesystem::path font_path = std::filesystem::current_path() / "data" / "DejaVuSans.ttf";
    if (std::filesystem::exists(font_path)) {
        io.Fonts->AddFontFromFileTTF(font_path.string().c_str(), 14.0f);
    } else {
        std::cerr << "Font file not found: " << font_path << std::endl;
    }
}

void setup_logo(GLFWwindow* window) {
    std::filesystem::path logo_path = std::filesystem::current_path() / "data" / "logo_viewport.png";
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

