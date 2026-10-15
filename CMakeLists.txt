cmake_minimum_required(VERSION 3.21)
project(BrotherhoodCanvas VERSION 2.2.1 LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OBJCXX_STANDARD 20)
set(CMAKE_AUTOMOC ON)

option(BCQ_DEV "Development build: BCQ_SKIP_LOCK bypasses the access key (never enabled for releases)" OFF)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Network Concurrent Multimedia Svg ShaderTools)
qt_standard_project_setup(REQUIRES 6.8)

set(APP_SOURCES
    src/main.cpp
    src/app/appcontroller.cpp
    src/core/jsonfile.cpp
    src/core/paths.cpp
    src/core/prefs.cpp
    src/core/lock.cpp
    src/platform/mac.mm
    src/platform/memtrim.cpp
    src/canvas/boarddata.cpp
    src/canvas/vault.cpp
    src/canvas/edgemodel.cpp
    src/canvas/boardmodel.cpp
    src/canvas/cullproxy.cpp
    src/canvas/boardsmodel.cpp
    src/canvas/exporter.cpp
    src/canvas/mediaprovider.cpp
    src/canvas/canvascontroller.cpp
)

qt_add_executable(BrotherhoodCanvas MACOSX_BUNDLE ${APP_SOURCES})
set_target_properties(BrotherhoodCanvas PROPERTIES
    OUTPUT_NAME "Brotherhood Canvas"
    MACOSX_BUNDLE_BUNDLE_NAME "Brotherhood Canvas"
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.brotherhood.canvas.qt"
    MACOSX_BUNDLE_BUNDLE_VERSION "1"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
    MACOSX_BUNDLE_ICON_FILE "AppIcon"
    MACOSX_BUNDLE_ICON_NAME "AppIcon"
    MACOSX_BUNDLE_COPYRIGHT "Brotherhood"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.brotherhood.canvas.qt")
target_compile_definitions(BrotherhoodCanvas PRIVATE APP_VERSION="${PROJECT_VERSION}")
if(BCQ_DEV)
    target_compile_definitions(BrotherhoodCanvas PRIVATE BCQ_DEV=1)
    target_sources(BrotherhoodCanvas PRIVATE src/dev/driver.cpp)
endif()

file(GLOB_RECURSE QML_FILES RELATIVE ${CMAKE_SOURCE_DIR} CONFIGURE_DEPENDS qml/*.qml)
set_source_files_properties(qml/components/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/components/Icons.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/canvas/Cam.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
qt_add_qml_module(BrotherhoodCanvas
    URI Canvas
    VERSION 1.0
    QML_FILES ${QML_FILES}
)

qt_add_shaders(BrotherhoodCanvas "shaders"
    BATCHABLE PRECOMPILE OPTIMIZED
    PREFIX "/shaders"
    BASE resources/shaders
    FILES resources/shaders/pattern.frag resources/shaders/rounded.frag)

# Fonts and images are served from qrc:/assets/... (QML) and :/assets/... (C++)
file(GLOB_RECURSE ASSET_FILES CONFIGURE_DEPENDS
    ${CMAKE_SOURCE_DIR}/resources/fonts/*.ttf
    ${CMAKE_SOURCE_DIR}/resources/images/*.svg
    ${CMAKE_SOURCE_DIR}/resources/images/*.png)
qt_add_resources(BrotherhoodCanvas assets PREFIX "/assets" BASE ${CMAKE_SOURCE_DIR}/resources FILES ${ASSET_FILES})

target_link_libraries(BrotherhoodCanvas PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Network Qt6::Concurrent Qt6::Multimedia Qt6::Svg
    "-framework AppKit" "-framework Foundation" "-framework CoreGraphics" "-framework ImageIO"
    "-framework AVFoundation" "-framework CoreMedia" "-framework UniformTypeIdentifiers" "-framework IOKit")

# App icon: resources/AppIcon.icon is an Icon Composer document. actool turns it into Assets.car (macOS 26+) plus a
# flat AppIcon.icns for older systems, straight into the bundle.
if(EXISTS ${CMAKE_SOURCE_DIR}/resources/AppIcon.icon)
add_custom_command(TARGET BrotherhoodCanvas POST_BUILD
    COMMAND xcrun actool "${CMAKE_SOURCE_DIR}/resources/AppIcon.icon"
            --compile "$<TARGET_BUNDLE_CONTENT_DIR:BrotherhoodCanvas>/Resources"
            --platform macosx --minimum-deployment-target 14.0 --app-icon AppIcon
            --output-partial-info-plist "${CMAKE_BINARY_DIR}/icon-partial.plist" --output-format human-readable-text
    COMMAND sh -c "chmod u+w '$<TARGET_BUNDLE_CONTENT_DIR:BrotherhoodCanvas>/Info.plist'; /usr/libexec/PlistBuddy -c 'Add :CFBundleIconName string AppIcon' '$<TARGET_BUNDLE_CONTENT_DIR:BrotherhoodCanvas>/Info.plist' 2>/dev/null; touch '$<TARGET_BUNDLE_DIR:BrotherhoodCanvas>'"
    COMMENT "Compiling the app icon"
    VERBATIM)
endif()
