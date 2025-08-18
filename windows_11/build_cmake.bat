:: 26-05-2024

@echo off
:: Print the current date
echo %date%

:: Clean the build and application directories if they exist
echo Cleaning build and application directories...
IF EXIST build (
    rmdir /s /q build
    echo Removed build directory.
)
IF EXIST application (
    rmdir /s /q application
    echo Removed application directory.
)

:: Create the build and application directories
echo Creating build and application directories...
mkdir build
mkdir application

:: Navigate to the build directory
echo Navigating to build directory...
cd build

:: Run CMake to configure the project and generate build files
echo Running CMake configuration...
cmake ..

:: Build the project
echo Building the project...
cmake --build .

:: Navigate back to the root directory
cd ..

:: :: Copy the data folder to the application directory
:: echo Copying data folder to application directory...
:: xcopy data application\data /E /I /Q

:: Check if the executable exists and run it
echo Checking if the executable exists and running it...
IF EXIST application\cmake_imgui_app.exe (
    echo Executable found. Launching the application...
    start application\cmake_imgui_app.exe
) ELSE (
    echo Error: Executable not found in the application directory.
    pause
    exit /b 1
)

:: Pause to keep the command prompt open
pause
