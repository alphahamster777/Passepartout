cmake_minimum_required(VERSION 3.28)

project(Passepartout VERSION 0.1 LANGUAGES CXX)

if (NOT CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    message(FATAL_ERROR "Error: This project requires Clang. Please switch to Clang.")
else()
    if (CMAKE_CXX_COMPILER_VERSION VERSION_LESS 18.1.3)
        message(FATAL_ERROR "Error: Clang version 14 or higher is required. Current version: ${CMAKE_CXX_COMPILER_VERSION}")
    endif()
endif()

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(DictRec
    ${CMAKE_SOURCE_DIR}/include/dictRec.h
    ${CMAKE_SOURCE_DIR}/src/dictRec.cpp
)
target_include_directories(DictRec
    PUBLIC ${CMAKE_SOURCE_DIR}/include
)

add_library(RecSet
    ${CMAKE_SOURCE_DIR}/include/recSet.h
    ${CMAKE_SOURCE_DIR}/src/recSet.cpp
)
target_include_directories(RecSet
    PUBLIC ${CMAKE_SOURCE_DIR}/include
)
target_link_libraries(RecSet
    PRIVATE DictRec
)

add_library(RecSetManager
    ${CMAKE_SOURCE_DIR}/include/recSetManager.h
    ${CMAKE_SOURCE_DIR}/src/recSetManager.cpp
)
target_include_directories(RecSetManager
    PUBLIC ${CMAKE_SOURCE_DIR}/include
)
target_link_libraries(RecSetManager
    PRIVATE DictRec RecSet
)

find_package(Qt6 REQUIRED COMPONENTS Quick Core Multimedia QuickControls2)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_library(SpellingTestController
    ${CMAKE_SOURCE_DIR}/include/spellingTestController.h
    ${CMAKE_SOURCE_DIR}/src/spellingTestController.cpp
)
target_include_directories(SpellingTestController
    PUBLIC ${CMAKE_SOURCE_DIR}/include
)
target_link_libraries(SpellingTestController PRIVATE Qt6::Core RecSetManager)


qt_add_library(SetPreviewMenuController
    ${CMAKE_SOURCE_DIR}/include/setPreviewMenuController.h
    ${CMAKE_SOURCE_DIR}/src/setPreviewMenuController.cpp
)
target_include_directories(SetPreviewMenuController
    PUBLIC ${CMAKE_SOURCE_DIR}/include
)
target_link_libraries(SetPreviewMenuController PRIVATE Qt6::Core Qt6::Qml RecSetManager)

qt_add_executable(appPassepartout
    ${CMAKE_SOURCE_DIR}/src/main.cpp
)

qt_add_qml_module(appPassepartout
    URI Passepartout
    VERSION 1.0
    QML_FILES SpellingTest.qml SetPreviewMenu.qml Results.qml
    QML_FILES Main.qml
)

# Include the resource file
qt_add_resources(appPassepartout "resources"
    PREFIX "/"
    FILES
        images/bicycle.jpg
        images/cheese.jpg
        images/default_logo.jpg
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

target_link_libraries(appPassepartout
    PRIVATE Qt6::Multimedia Qt6::QuickControls2 SpellingTestController SetPreviewMenuController
)

include(GNUInstallDirs)
install(TARGETS appPassepartout
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
