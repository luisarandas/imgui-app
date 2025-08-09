#!/bin/bash

# Author: luisarandas
# Date: 2024-05-26

# Function to print a separator
print_separator() {
    echo "============================================"
}

# Remove the previous build directory
echo "Cleaning up the build directory..."
rm -rf build
if [ $? -ne 0 ]; then
    echo "Error: Failed to remove the build directory."
    exit 1
fi

# Create a new build directory
echo "Creating a new build directory..."
mkdir build
if [ $? -ne 0 ]; then
    echo "Error: Failed to create the build directory."
    exit 1
fi

# Navigate into the build directory
cd build
if [ $? -ne 0 ]; then
    echo "Error: Failed to navigate into the build directory."
    exit 1
fi

# Generate the build system
print_separator
echo "Generating the build system with CMake..."
cmake ..
if [ $? -ne 0 ]; then
    echo "Error: Failed to generate the build system with CMake."
    exit 1
fi

# Build the project
print_separator
echo "Building the project..."
cmake --build .
if [ $? -ne 0 ]; then
    echo "Error: Failed to build the project."
    exit 1
fi

# Check if the executable exists in the application directory
print_separator
echo "Checking if the executable exists..."
if [ -f ../application/cmake-imgui-app ]; then
    echo "Executable found. Running the application..."
    ../application/cmake-imgui-app
    if [ $? -ne 0 ]; then
        echo "Error: Failed to run the application."
        exit 1
    fi
else
    echo "Error: Executable not found in the application directory."
    exit 1
fi

# Print a success message
print_separator
echo "Build and execution completed successfully."
