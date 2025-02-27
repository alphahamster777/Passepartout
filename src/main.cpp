#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>//to set "Material" style
#include "spellingTestController.h"
#include "setPreviewMenuController.h"

// import word_set_manager;
int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;
    QQuickStyle::setStyle("Material");

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    // qmlRegisterType<SpellingTestController>("Passepartout", 1, 0, "AppController");
    RecSetManager recSetManager; // Assume it's initialized properly
    recSetManager.createRecSet("Default Set");
    recSetManager.addRecToRecSet("Default Set", DictRec(2, 1, "der Fahrrad", "bicycle", "audio.mp3", "qrc:/images/bicycle.jpg"));
    recSetManager.addRecToRecSet("Default Set", DictRec(2, 1, "die Käse", "cheese", "audio.mp3", "qrc:/images/cheese.jpg"));
    recSetManager.addRecToRecSet("Default Set", DictRec(1, 2, "opportunity", "Möglichkeit", "audio.mp3", "qrc:/images/default_logo.jpg"));
    SpellingTestController spellingTestController(&recSetManager);
    engine.rootContext()->setContextProperty("spellingTestController", &spellingTestController);

    SetPreviewMenuController setPreviewController(&recSetManager);
    engine.rootContext()->setContextProperty("setPreviewController", &setPreviewController);
    engine.loadFromModule("Passepartout", "Main");
    return app.exec();
}
