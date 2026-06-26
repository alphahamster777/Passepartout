cmake_minimum_required(VERSION 3.28)

project(Passepartout VERSION 0.1 LANGUAGES CXX)
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g")
# QT_QML_DEBUG only for Debug builds — globally defining it causes the app to
# hang on Android when Qt Creator's QML debugger port-forward fails.
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    add_definitions(-DQT_QML_DEBUG)
endif()

if (NOT CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    message(FATAL_ERROR "Error: This project requires Clang. Please switch to Clang.")
else()
    if (CMAKE_CXX_COMPILER_VERSION VERSION_LESS  17.0.2)
        message(FATAL_ERROR "Error: Clang version  17.0.2 or higher is required. Current version: ${CMAKE_CXX_COMPILER_VERSION}")
    endif()
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Core  Multimedia QuickControls2 QuickDialogs2 Network TextToSpeech)

if(Qt6_VERSION VERSION_GREATER_EQUAL "6.10.0")
    find_package(Qt6 REQUIRED COMPONENTS CorePrivate)
endif()

qt_standard_project_setup(REQUIRES 6.5)

qt_add_qml_module(LanguageHelper
    URI LanguageHelper
    VERSION 1.0
    RESOURCE_PREFIX /
    SOURCES
    ${CMAKE_SOURCE_DIR}/include/languageHelper.h
    ${CMAKE_SOURCE_DIR}/src/languageHelper.cpp
    OUTPUT_DIRECTORY
      "${CMAKE_BINARY_DIR}/LanguageHelper"
)

target_include_directories(LanguageHelper
    PUBLIC ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(LanguageHelper
    PRIVATE Qt6::Core
)

add_library(DictRec
    ${CMAKE_SOURCE_DIR}/include/dictRec.h
    ${CMAKE_SOURCE_DIR}/src/dictRec.cpp
)
target_include_directories(DictRec
    PUBLIC ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(DictRec
    PRIVATE Qt6::Core
)

add_library(RecSet
    ${CMAKE_SOURCE_DIR}/include/recSet.h
    ${CMAKE_SOURCE_DIR}/src/recSet.cpp
)
target_include_directories(RecSet
    PUBLIC ${CMAKE_SOURCE_DIR}/include
)
target_link_libraries(RecSet
    PRIVATE DictRec Qt6::Core
)

qt_add_qml_module(RecSetManager
    URI RecSetManager
    VERSION 1.0
    RESOURCE_PREFIX /
    SOURCES
    ${CMAKE_SOURCE_DIR}/include/recSetManager.h
    ${CMAKE_SOURCE_DIR}/src/recSetManager.cpp
    OUTPUT_DIRECTORY
      "${CMAKE_BINARY_DIR}/RecSetManager"
)

target_include_directories(RecSetManager
    PUBLIC ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(RecSetManager
    PRIVATE DictRec RecSet Qt6::Core
)

# QZipReader/QZipWriter private headers require explicit CorePrivate linkage in Qt 6.10+;
# on older Qt6 the private include dirs were exposed transitively through Qt6::Core.
if(Qt6_VERSION VERSION_GREATER_EQUAL "6.10.0")
    target_link_libraries(RecSetManager PRIVATE Qt6::CorePrivate)
else()
    target_include_directories(RecSetManager PRIVATE ${Qt6Core_PRIVATE_INCLUDE_DIRS})
endif()

add_library(BaseTestController STATIC
    ${CMAKE_SOURCE_DIR}/include/baseTestController.h
    ${CMAKE_SOURCE_DIR}/src/baseTestController.cpp
)
target_include_directories(BaseTestController PUBLIC ${CMAKE_SOURCE_DIR}/include)
target_link_libraries(BaseTestController PRIVATE Qt6::Core RecSetManager)

qt_add_qml_module(SpellingTestController
    URI SpellingTestController
    VERSION 1.0
    RESOURCE_PREFIX /
    SOURCES
    ${CMAKE_SOURCE_DIR}/include/spellingTestController.h
    ${CMAKE_SOURCE_DIR}/src/spellingTestController.cpp
    OUTPUT_DIRECTORY
      "${CMAKE_BINARY_DIR}/SpellingTestController"
)

target_link_libraries(SpellingTestController PRIVATE Qt6::Core BaseTestController)

qt_add_qml_module(LeitnerTestController
    URI LeitnerTestController
    VERSION 1.0
    RESOURCE_PREFIX /
    SOURCES
    ${CMAKE_SOURCE_DIR}/include/leitnerTestController.h
    ${CMAKE_SOURCE_DIR}/src/leitnerTestController.cpp
    OUTPUT_DIRECTORY
      "${CMAKE_BINARY_DIR}/LeitnerTestController"
)

target_link_libraries(LeitnerTestController PRIVATE Qt6::Core BaseTestController)

qt_add_qml_module(SetPreviewMenuController
    URI SetPreviewMenuController
    VERSION 1.0
    RESOURCE_PREFIX /
    SOURCES
    ${CMAKE_SOURCE_DIR}/include/setPreviewMenuController.h
    ${CMAKE_SOURCE_DIR}/src/setPreviewMenuController.cpp
    OUTPUT_DIRECTORY
    "${CMAKE_BINARY_DIR}/SetPreviewMenuController"
)

target_link_libraries(SetPreviewMenuController PRIVATE Qt6::Core Qt6::Qml RecSetManager)

qt_add_qml_module(ShareHelper
    URI ShareHelper
    VERSION 1.0
    RESOURCE_PREFIX /
    SOURCES
    ${CMAKE_SOURCE_DIR}/include/shareHelper.h
    ${CMAKE_SOURCE_DIR}/src/shareHelper.cpp
    OUTPUT_DIRECTORY
      "${CMAKE_BINARY_DIR}/ShareHelper"
)

target_include_directories(ShareHelper
    PUBLIC ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(ShareHelper PRIVATE Qt6::Core)

qt_add_qml_module(MediaHelper
    URI MediaHelper
    VERSION 1.0
    RESOURCE_PREFIX /
    SOURCES
    ${CMAKE_SOURCE_DIR}/include/mediaHelper.h
    ${CMAKE_SOURCE_DIR}/src/mediaHelper.cpp
    OUTPUT_DIRECTORY
      "${CMAKE_BINARY_DIR}/MediaHelper"
)

target_include_directories(MediaHelper
    PUBLIC ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(MediaHelper PRIVATE Qt6::Core Qt6::Gui Qt6::Network Qt6::TextToSpeech)

qt_add_qml_module(AppController
    URI AppController
    VERSION 1.0
    RESOURCE_PREFIX /
    SOURCES
    ${CMAKE_SOURCE_DIR}/include/appController.h
    ${CMAKE_SOURCE_DIR}/src/appController.cpp
    OUTPUT_DIRECTORY
    "${CMAKE_BINARY_DIR}/AppController"
)

target_link_libraries(AppController PRIVATE Qt6::Core Qt6::Qml RecSetManager)

qt_add_executable(appPassepartout
    ${CMAKE_SOURCE_DIR}/src/main.cpp
)

qt_add_qml_module(appPassepartout
    URI Passepartout
    VERSION 1.0
    QML_FILES Main.qml Results.qml SetDirMenu.qml SpellingTest.qml SetPreviewMenu.qml CreatingRecSet.qml CameraCapture.qml AboutOpenSourcePage.qml LicenseTextPage.qml 
    IMPORTS LeitnerTestController SpellingTestController
)

target_link_libraries(appPassepartout
    PRIVATE Qt6::Multimedia Qt6::QuickControls2 Qt6::QuickDialogs2
            Qt6::Network Qt6::TextToSpeech
            SpellingTestController LeitnerTestController
)

qt_add_resources(appPassepartout "license_resources"
    PREFIX "/"
    FILES
        licenses/LGPL-3.0.txt
        licenses/GPL-3.0.txt
        licenses/qt_notice.txt
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appPassepartout PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appPassepartout
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

set_target_properties(appPassepartout PROPERTIES
    QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_SOURCE_DIR}/android"
)

set_target_properties(appPassepartout PROPERTIES
    QT_ANDROID_VERSION_CODE "1"
    QT_ANDROID_VERSION_NAME "1.0.0"
)

# Bundle OpenSSL 3.x for Android so HTTPS (Wikipedia image fetch) works.
# KDAB's android_openssl provides pre-built arm64-v8a libssl_3.so / libcrypto_3.so.
if(ANDROID)
    include(FetchContent)
    FetchContent_Declare(
        android_openssl
        GIT_REPOSITORY https://github.com/KDAB/android_openssl.git
        GIT_TAG        master
        GIT_SHALLOW    TRUE
    )
    FetchContent_MakeAvailable(android_openssl)
    include("${android_openssl_SOURCE_DIR}/android_openssl.cmake")
    add_android_openssl_libraries(appPassepartout)
endif()

include(GNUInstallDirs)
install(TARGETS appPassepartout
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
