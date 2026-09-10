#pragma once

#include <QObject>
#include <QtQml/qqml.h>

// Bridges Android's Activity.onNewIntent() into a Qt signal.
//
// Qt.application.state transitioning to Active was used as a proxy for
// "a new intent just arrived" (for both the OAuth sign-in redirect and a
// re-tapped shared .ppset file), but turned out unreliable: when Android
// switches back to an already-resident app quickly, Qt doesn't always
// register that as an Inactive->Active *transition* — so a QML
// onStateChanged handler can simply never fire, silently missing the new
// intent. onNewIntent() itself has no such gap: Android calls it
// unconditionally whenever a new Intent reaches this app's singleTask
// Activity while it's already running. PassepartoutActivity.java calls a
// native method on every onNewIntent(); that native function (registered
// via QJniEnvironment::registerNativeMethods in the .cpp) emits
// newIntentReceived() on this singleton so QML can react to the one
// genuinely reliable signal instead.
class AppLifecycleBridge : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit AppLifecycleBridge(QObject* parent = nullptr);

    static QObject* qmlInstance(QQmlEngine*, QJSEngine*) { return new AppLifecycleBridge(); }

signals:
    void newIntentReceived();
};
