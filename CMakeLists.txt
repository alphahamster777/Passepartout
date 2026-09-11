cmake_minimum_required(VERSION 3.28)

project(Passepartout VERSION 2.2.0 LANGUAGES CXX)
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

# FREE vs PRO are separate Play Store listings built from this same source
# tree (see the "Lite + Pro" discussion) — the only difference is which
# Cloud Function URL gets compiled into FirebaseAiHelper, which in turn is
# the only thing that determines the monthly AI-generation quota. Build the
# Pro variant with -DPASSEPARTOUT_TIER=PRO.
set(PASSEPARTOUT_TIER "FREE" CACHE STRING "Which Play Store listing this build is for: FREE or PRO")
set_property(CACHE PASSEPARTOUT_TIER PROPERTY STRINGS FREE PRO)
if(NOT PASSEPARTOUT_TIER STREQUAL "FREE" AND NOT PASSEPARTOUT_TIER STREQUAL "PRO")
    message(FATAL_ERROR "PASSEPARTOUT_TIER must be FREE or PRO, got: ${PASSEPARTOUT_TIER}")
endif()

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

find_package(Qt6 REQUIRED COMPONENTS Quick Core  Multimedia QuickControls2 QuickDialogs2 Network TextToSpeech LinguistTools)

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

qt_add_qml_module(FlashCardController
    URI FlashCardController
    VERSION 1.0
    RESOURCE_PREFIX /
    SOURCES
    ${CMAKE_SOURCE_DIR}/include/flashCardController.h
    ${CMAKE_SOURCE_DIR}/src/flashCardController.cpp
    OUTPUT_DIRECTORY
      "${CMAKE_BINARY_DIR}/FlashCardController"
)

target_link_libraries(FlashCardController PRIVATE Qt6::Core BaseTestController)

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

qt_add_qml_module(AppLifecycleBridge
    URI AppLifecycleBridge
    VERSION 1.0
    RESOURCE_PREFIX /
    SOURCES
    ${CMAKE_SOURCE_DIR}/include/appLifecycleBridge.h
    ${CMAKE_SOURCE_DIR}/src/appLifecycleBridge.cpp
    OUTPUT_DIRECTORY
      "${CMAKE_BINARY_DIR}/AppLifecycleBridge"
)

target_include_directories(AppLifecycleBridge
    PUBLIC ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(AppLifecycleBridge PRIVATE Qt6::Core)

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

# Prompt/schema/response-parsing shared by GeminiHelper (direct Gemini calls,
# used for desktop/local testing) and FirebaseAiHelper (Firebase AI Logic,
# Android only) so both backends agree on what a generated word set is.
add_library(AiWordSetShared STATIC
    ${CMAKE_SOURCE_DIR}/include/aiWordSetShared.h
    ${CMAKE_SOURCE_DIR}/src/aiWordSetShared.cpp
)
target_include_directories(AiWordSetShared
    PUBLIC ${CMAKE_SOURCE_DIR}/include
)
target_link_libraries(AiWordSetShared PRIVATE Qt6::Core)

qt_add_qml_module(GeminiHelper
    URI GeminiHelper
    VERSION 1.0
    RESOURCE_PREFIX /
    SOURCES
    ${CMAKE_SOURCE_DIR}/include/geminiHelper.h
    ${CMAKE_SOURCE_DIR}/src/geminiHelper.cpp
    OUTPUT_DIRECTORY
      "${CMAKE_BINARY_DIR}/GeminiHelper"
)

target_include_directories(GeminiHelper
    PUBLIC ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(GeminiHelper PRIVATE Qt6::Core Qt6::Network AiWordSetShared)

qt_add_qml_module(FirebaseAiHelper
    URI FirebaseAiHelper
    VERSION 1.0
    RESOURCE_PREFIX /
    SOURCES
    ${CMAKE_SOURCE_DIR}/include/firebaseAiHelper.h
    ${CMAKE_SOURCE_DIR}/src/firebaseAiHelper.cpp
    OUTPUT_DIRECTORY
      "${CMAKE_BINARY_DIR}/FirebaseAiHelper"
)

target_include_directories(FirebaseAiHelper
    PUBLIC ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(FirebaseAiHelper PRIVATE Qt6::Core Qt6::Network AiWordSetShared)
target_compile_definitions(FirebaseAiHelper PRIVATE PASSEPARTOUT_TIER_${PASSEPARTOUT_TIER}=1)

qt_add_qml_module(GoogleSignInHelper
    URI GoogleSignInHelper
    VERSION 1.0
    RESOURCE_PREFIX /
    SOURCES
    ${CMAKE_SOURCE_DIR}/include/googleSignInHelper.h
    ${CMAKE_SOURCE_DIR}/src/googleSignInHelper.cpp
    OUTPUT_DIRECTORY
      "${CMAKE_BINARY_DIR}/GoogleSignInHelper"
)

target_include_directories(GoogleSignInHelper
    PUBLIC ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(GoogleSignInHelper PRIVATE Qt6::Core Qt6::Gui Qt6::Network)

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
    QML_FILES Main.qml Results.qml SetDirMenu.qml SpellingTest.qml SetPreviewMenu.qml CreatingRecSet.qml CameraCapture.qml AboutOpenSourcePage.qml LicenseTextPage.qml FlashCard.qml
    IMPORTS LeitnerTestController SpellingTestController FlashCardController LanguageHelper
)

# IMPORTS (above) only tells qmlimportscanner what to discover/bundle for
# deployment — it does NOT give Ninja a rebuild-ordering dependency, since a
# QML-only plugin like LanguageHelper is never linked into appPassepartout's
# executable. Without this, editing languageHelper.h/cpp and then building
# only the appPassepartout target can silently link/package a stale plugin
# (verified: "ninja: no work to do" for appPassepartout even right after
# LanguageHelper's own sources changed) — add_dependencies() is what actually
# forces Ninja to rebuild LanguageHelper first when it's out of date.
add_dependencies(appPassepartout LanguageHelper)

# main.cpp calls AppController::resolveInterfaceLanguage()/applyInterfaceLanguage()
# directly (in C++, ahead of any QML) — needs the header, and an explicit link
# since that direct C++ dependency isn't declared via IMPORTS above the way the
# QML-only singletons are (those get pulled in by Qt's qmlimportscanner instead).
target_include_directories(appPassepartout PRIVATE ${CMAKE_SOURCE_DIR}/include)

target_link_libraries(appPassepartout
    PRIVATE Qt6::Multimedia Qt6::QuickControls2 Qt6::QuickDialogs2
            Qt6::Network Qt6::TextToSpeech
            SpellingTestController LeitnerTestController FlashCardController
            AppController
)

qt_add_resources(appPassepartout "license_resources"
    PREFIX "/"
    FILES
        licenses/LGPL-3.0.txt
        licenses/GPL-3.0.txt
        licenses/qt_notice.txt
)

# One .ts per LanguageHelper language except English (the qsTr() source
# language itself, so it needs no translation file — AppController::
# applyInterfaceLanguage() leaves no translator installed for it and the
# source text shows through as-is). SOURCE_TARGETS is deliberately omitted:
# these .ts files are already fully populated by hand/AI rather than by
# lupdate, so this only compiles+embeds them (as :/i18n/app_<code>.qm) —
# it does not run lupdate against the sources or touch their content.
# To pick up newly added qsTr() strings later, run lupdate manually against
# the QML_FILES above into each translations/app_<code>.ts and fill in the
# new <translation> entries (lupdate preserves the existing ones).
qt_add_translations(appPassepartout
    TS_FILES
        translations/app_af.ts
        translations/app_ar.ts
        translations/app_az.ts
        translations/app_be.ts
        translations/app_bg.ts
        translations/app_bn.ts
        translations/app_ca.ts
        translations/app_cs.ts
        translations/app_cy.ts
        translations/app_da.ts
        translations/app_de.ts
        translations/app_el.ts
        translations/app_es.ts
        translations/app_et.ts
        translations/app_eu.ts
        translations/app_fa.ts
        translations/app_fi.ts
        translations/app_fil.ts
        translations/app_fr.ts
        translations/app_gl.ts
        translations/app_he.ts
        translations/app_hi.ts
        translations/app_hr.ts
        translations/app_hu.ts
        translations/app_hy.ts
        translations/app_id.ts
        translations/app_is.ts
        translations/app_it.ts
        translations/app_ja.ts
        translations/app_ka.ts
        translations/app_kk.ts
        translations/app_ko.ts
        translations/app_lt.ts
        translations/app_lv.ts
        translations/app_mr.ts
        translations/app_ms.ts
        translations/app_nb.ts
        translations/app_nl.ts
        translations/app_pl.ts
        translations/app_pt.ts
        translations/app_ro.ts
        translations/app_ru.ts
        translations/app_sk.ts
        translations/app_sl.ts
        translations/app_sq.ts
        translations/app_sr.ts
        translations/app_sv.ts
        translations/app_sw.ts
        translations/app_ta.ts
        translations/app_th.ts
        translations/app_tr.ts
        translations/app_uk.ts
        translations/app_ur.ts
        translations/app_vi.ts
        translations/app_zh_CN.ts
    RESOURCE_PREFIX "/i18n"
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
if(IOS)
    set_target_properties(appPassepartout PROPERTIES
    #    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.passepartout
        MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION}
        MACOSX_BUNDLE TRUE
        WIN32_EXECUTABLE TRUE
    )
elseif(ANDROID)
    set_target_properties(appPassepartout PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_SOURCE_DIR}/android"
        # Display name shown on the launcher icon
        QT_ANDROID_APP_NAME "Passepartout"
        # Google Play use the number to decide whether one build is newer than another.
        # Every public release must use a higher value than the previous one.
        QT_ANDROID_VERSION_CODE "14"
        # Human-readable app version
        QT_ANDROID_VERSION_NAME "${PROJECT_VERSION}"

        # Minimum Android version your app can run on (e.g., Android 8.0)
        QT_ANDROID_MIN_SDK_VERSION "26"

        # Target SDK version forced to API 36 to fix the Play Store error
        QT_ANDROID_TARGET_SDK_VERSION "36"

        # Automatically signs the bundle if you configure keystore in Qt Creator
        QT_ANDROID_SIGN_PACKAGE ON
    )

    # Bundle OpenSSL 3.x for Android so HTTPS (Wikipedia image fetch) works.
    # KDAB's android_openssl provides pre-built arm64-v8a libssl_3.so / libcrypto_3.so.
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

target_compile_definitions(appPassepartout PRIVATE APP_VERSION="${PROJECT_VERSION}")

include(GNUInstallDirs)
install(TARGETS appPassepartout
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
