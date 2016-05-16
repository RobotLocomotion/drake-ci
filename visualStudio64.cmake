# This sets up the environment to build with the MS visual studio command line tools
# To create this file:
# open a cmd shell and run the following
#   call "C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\vcvarsall.bat" amd64
#   set > vars.cmake
#
# Edit vars.cmake and change all of the var= lines into set(ENV{var} "...") lines
# replace all \ with \\.
#
# to find out which vars are required, run set in a cmd shell without calling
# vsvarsall.bat and use diff to find out which vars are added by vcvarsall.bat

set(ENV{INCLUDE} "C:\\Program Files (x86)\\Microsoft Visual Studio 14.0\\VC\\INCLUDE;C:\\Program Files (x86)\\Microsoft Visual Studio 14.0\\VC\\ATLMFC\\INCLUDE;C:\\Program Files (x86)\\Windows Kits\\10\\include\\10.0.10240.0\\ucrt;C:\\Program Files (x86)\\Windows Kits\\NETFXSDK\\4.6.1\\include\\um;C:\\Program Files (x86)\\Windows Kits\\8.1\\include\\\\shared;C:\\Program Files (x86)\\Windows Kits\\8.1\\include\\\\um;C:\\Program Files (x86)\\Windows Kits\\8.1\\include\\\\winrt;")
set(ENV{LIB} "C:\\Program Files (x86)\\Microsoft Visual Studio 14.0\\VC\\LIB\\amd64;C:\\Program Files (x86)\\Microsoft Visual Studio 14.0\\VC\\ATLMFC\\LIB\\amd64;C:\\Program Files (x86)\\Windows Kits\\10\\lib\\10.0.10240.0\\ucrt\\x64;C:\\Program Files (x86)\\Windows Kits\\NETFXSDK\\4.6.1\\lib\\um\\x64;C:\\Program Files (x86)\\Windows Kits\\8.1\\lib\\winv6.3\\um\\x64;")
set(ENV{LIBPATH} "C:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319;C:\\Program Files (x86)\\Microsoft Visual Studio 14.0\\VC\\LIB\\amd64;C:\\Program Files (x86)\\Microsoft Visual Studio 14.0\\VC\\ATLMFC\\LIB\\amd64;C:\\Program Files (x86)\\Windows Kits\\8.1\\References\\CommonConfiguration\\Neutral;\\Microsoft.VCLibs\\14.0\\References\\CommonConfiguration\\neutral;")
set(ENV{PATH} "C:\\Program Files (x86)\\Microsoft Visual Studio 14.0\\Common7\\IDE\\CommonExtensions\\Microsoft\\TestWindow;C:\\Program Files (x86)\\MSBuild\\14.0\\bin\\amd64;C:\\Program Files (x86)\\Microsoft Visual Studio 14.0\\VC\\BIN\\amd64;C:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319;C:\\Program Files (x86)\\Microsoft Visual Studio 14.0\\VC\\VCPackages;C:\\Program Files (x86)\\Microsoft Visual Studio 14.0\\Common7\\IDE;C:\\Program Files (x86)\\Microsoft Visual Studio 14.0\\Common7\\Tools;C:\\Program Files (x86)\\HTML Help Workshop;C:\\Program Files (x86)\\Microsoft Visual Studio 14.0\\Team Tools\\Performance Tools\\x64;C:\\Program Files (x86)\\Microsoft Visual Studio 14.0\\Team Tools\\Performance Tools;C:\\Program Files (x86)\\Windows Kits\\8.1\\bin\\x64;C:\\Program Files (x86)\\Windows Kits\\8.1\\bin\\x86;C:\\Program Files (x86)\\Microsoft SDKs\\Windows\\v10.0A\\bin\\NETFX 4.6.1 Tools\\x64\\;C:\\Program Files (x86)\\Intel\\iCLS Client\\;C:\\Program Files\\Intel\\iCLS Client\\;C:\\Windows\\system32;C:\\Windows;C:\\Windows\\System32\\Wbem;C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\;C:\\Program Files\\Intel\\WiFi\\bin\\;C:\\Program Files\\Common Files\\Intel\\WirelessCommon\\;C:\\Program Files (x86)\\Intel\\Intel(R) Management Engine Components\\DAL;C:\\Program Files\\Intel\\Intel(R) Management Engine Components\\DAL;C:\\Program Files (x86)\\Intel\\Intel(R) Management Engine Components\\IPT;C:\\Program Files\\Intel\\Intel(R) Management Engine Components\\IPT;C:\\Program Files (x86)\\NVIDIA Corporation\\PhysX\\Common;C:\\Program Files\\OpenVPN\\bin;C:\\Program Files (x86)\\Windows Kits\\8.1\\Windows Performance Toolkit;$ENV{PATH}")
set(ENV{VisualStudioVersion} "14.0")
set(ENV{VS140COMNTOOLS} "C:\\Program Files (x86)\\Microsoft Visual Studio 14.0\\Common7\\Tools")
set(ENV{VSINSTALLDIR} "C:\\Program Files (x86)\\Microsoft Visual Studio 14.0")
set(ENV{WindowsLibPath} "C:\\Program Files (x86)\\Windows Kits\\8.1\\References\\CommonConfiguration\\Neutral")
set(ENV{WindowsSdkDir} "C:\\Program Files (x86)\\Windows Kits\\8.1")
set(ENV{WindowsSDKLibVersion} "winv6.3")
set(ENV{WindowsSDK_ExecutablePath_x64} "C:\\Program Files (x86)\\Microsoft SDKs\\Windows\\v10.0A\\bin\\NETFX 4.6.1 Tools\\x64")
set(ENV{WindowsSDK_ExecutablePath_x86} "C:\\Program Files (x86)\\Microsoft SDKs\\Windows\\v10.0A\\bin\\NETFX 4.6.1 Tools")
