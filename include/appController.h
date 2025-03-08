#ifndef APPCONTROLLER_H
#define APPCONTROLLER_H

#include <QObject>
#include "recSetManager.h"
#include <QtQml/qqml.h>
// #include "spellingTestController.h"
// #include "setPreviewMenuController.h"

class AppController: public QObject
{
    Q_OBJECT
    QML_ELEMENT
    // QML_SINGLETON
    Q_PROPERTY(RecSetManager* recSetManager READ recSetManager)

public:
    AppController(QObject* parent = nullptr) {
        m_recSetManager.createRecSet("Default Set");
        m_recSetManager.addRecToRecSet("Default Set", DictRec(2, 1, "der Fahrrad", "bicycle", "audio.mp3", "qrc:/images/bicycle.jpg"));
        m_recSetManager.addRecToRecSet("Default Set", DictRec(2, 1, "die Käse", "cheese", "audio.mp3", "qrc:/images/cheese.jpg"));
        m_recSetManager.addRecToRecSet("Default Set", DictRec(1, 2, "opportunity", "Möglichkeit", "audio.mp3", "qrc:/images/default_logo.jpg"));
    }
    RecSetManager* recSetManager() { return &m_recSetManager; }
private:
    RecSetManager m_recSetManager;
    // SpellingTestController m_spellingTestController;
    // SetPreviewMenuController m_setPreviewController;
};

#endif // APPCONTROLLER_H
