# imgui-app
Self-contained desktop ImGUI application in both CMake and SCons. Tests on 1) MacOS Monterey 12.2, others to do: Ubuntu 22.04 and Windows 11.

<img src="data/screenshot20240530.png" alt="capture" width="70%" />

### Tests for Development  
`./build_project_macos122.sh`  
`./build_app_macos122.sh`   
MacOS Monterey 12.2 


##### To revise
```
(For CMake Ubuntu 22.04:)
$ rm -rf build && mkdir build && cd build
$ cmake ..
$ cmake --build .
$ ./cmake-imgui-app
(For Scons Ubuntu 22.04 and Windows 11:)
$ scons --clean
$ scons
(Exports to:)
$ ./ubuntu/application/scons-imgui-app
$ ./windows/application/scons-imgui-app.exe

```

Roadmap todo




