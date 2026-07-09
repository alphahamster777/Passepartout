#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>//to set "Material" style
#include <QLoggingCategory>
#include <QCoreApplication>

int main(int argc, char *argv[])
{
    qputenv("QML_XHR_ALLOW_FILE_READ", "1");
    QLoggingCategory::setFilterRules(QStringLiteral("qt.qml.debug=true"));
    QGuiApplication app(argc, argv);
    app.setApplicationVersion(APP_VERSION);
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
