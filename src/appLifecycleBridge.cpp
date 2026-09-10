#include "appLifecycleBridge.h"

#ifdef Q_OS_ANDROID
#include <QJniEnvironment>
#include <QJniObject>
#include <jni.h>
#endif

namespace {
// QML_SINGLETON guarantees the engine constructs exactly one instance, so a
// plain static pointer is enough to reach it from the free-function JNI
// callback below (which, being a native method, can't be a member function).
AppLifecycleBridge* g_instance = nullptr;

#ifdef Q_OS_ANDROID
void nativeOnNewIntent(JNIEnv*, jobject) {
    if (g_instance)
        emit g_instance->newIntentReceived();
}
#endif
}

AppLifecycleBridge::AppLifecycleBridge(QObject* parent) : QObject(parent) {
    g_instance = this;
#ifdef Q_OS_ANDROID
    QJniEnvironment env;
    const bool registered = env.registerNativeMethods(
        "com/alphahamster/passepartout/PassepartoutActivity", {
        { "nativeOnNewIntent", "()V", reinterpret_cast<void*>(&nativeOnNewIntent) }
    });
    if (!registered)
        qWarning("AppLifecycleBridge: registerNativeMethods failed — "
                 "onNewIntent notifications will not reach QML via this path.");
#endif
}
