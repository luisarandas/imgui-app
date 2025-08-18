#!/bin/bash

# Author: luisarandas
# Date: 2024-05-26

# Function to print a separator
print_separator() {
    echo "============================================"
}

# Clean the previous build
print_separator
echo "Cleaning the previous build..."
scons --clean
if [ $? -ne 0 ]; then
    echo "Error: Failed to clean the previous build."
    exit 1
fi

# Build the project
print_separator
echo "Building the project..."
scons
if [ $? -ne 0 ]; then
    echo "Error: Failed to build the project."
    exit 1
fi

# Check if the executable exists in the application directory
print_separator
echo "Checking if the executable exists..."
if [ -f ./application/scons-imgui-app ]; then
    echo "Executable found. Running the application..."
    ./application/scons-imgui-app
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