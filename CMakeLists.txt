cmake_minimum_required(VERSION 3.20)
project(AnalysePlugin LANGUAGES CXX OBJCXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_OBJCXX_STANDARD 17)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0")
set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64")

# Self-contained: all needed headers are vendored into deps/ so the build does
# NOT depend on the Windows tree or the host source tree. The ScintillaView
# class itself lives in the running host process and is resolved at runtime via
# NSClassFromString — we only need its header for type declarations.
set(DEPS_INCLUDE "${CMAKE_SOURCE_DIR}/deps")

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

add_library(AnalysePlugin SHARED
    # Entry + controller
    src/PluginEntry.mm
    src/AnalyseController.mm
    # AppKit UI
    src/ResultPanelView.mm
    src/PatternEditorView.mm
    # Portable C++ core (ported nearly verbatim from the Windows plugin)
    src/tclColor.cpp
    src/tclPattern.cpp
    src/tclPatternList.cpp
    src/tclResult.cpp
    src/tclResultList.cpp
    src/tclFindResultDoc.cpp
    # XML config (kept wire-compatible with AnalyseDoc.xsd via NSXMLDocument)
    src/FindConfigDoc.mm
    # ── Pending phases (uncomment as each lands) ──
    # src/OptionsWindow.mm
    # src/HelpWindow.mm
    # src/ColorNames.mm
)

target_include_directories(AnalysePlugin PRIVATE
    ${DEPS_INCLUDE}
    src
)

target_link_libraries(AnalysePlugin PRIVATE
    "-framework Cocoa"
    "-framework AppKit"
)

# NOTE: we deliberately do NOT use `-undefined dynamic_lookup`. ScintillaView is
# reached purely via NSClassFromString + objc_msgSend (no link-time symbol), so
# the plugin has no genuine host-only symbols. Linking normally means a missing
# definition fails the BUILD instead of silently dropping the plugin at dlopen.

target_compile_options(AnalysePlugin PRIVATE
    -Wall -Wno-unused-parameter
    -fvisibility=hidden
    $<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-arc>
)

set_target_properties(AnalysePlugin PROPERTIES PREFIX "" SUFFIX ".dylib")

set(PLUGIN_INSTALL_DIR "$ENV{HOME}/.nextpad++/plugins/AnalysePlugin")
install(TARGETS AnalysePlugin DESTINATION "${PLUGIN_INSTALL_DIR}")
