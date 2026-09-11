#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>//to set "Material" style
#include <QLoggingCategory>
#include <QCoreApplication>

#include "appController.h"

int main(int argc, char *argv[])
{
    qputenv("QML_XHR_ALLOW_FILE_READ", "1");
    QLoggingCategory::setFilterRules(QStringLiteral("qt.qml.debug=true"));
    QGuiApplication app(argc, argv);
    app.setOrganizationName("Passepartout");
    app.setApplicationName("Passepartout");
    app.setApplicationVersion(APP_VERSION);

    // Installed before any QML loads, so every qsTr() binding evaluates
    // against the right language from its very first read — AppController
    // (a QML_SINGLETON) doing this itself in its own constructor would race
    // against whichever QML binding happens to be created first.
    AppController::applyInterfaceLanguage(AppController::resolveInterfaceLanguage());

    QQmlApplicationEngine engine;
    QQuickStyle::setStyle("Material");

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("Passepartout", "Main");
    return app.exec();
}
