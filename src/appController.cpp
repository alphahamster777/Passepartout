#include "appController.h"

AppController::AppController(QObject *parent) {
    m_recSetManager.createRecSet("Default Set");
    m_recSetManager.addRecToRecSet("Default Set", DictRec(2, 1, "der Fahrrad", "bicycle", "audio.mp3", "qrc:/images/bicycle.jpg"));
    m_recSetManager.addRecToRecSet("Default Set", DictRec(2, 1, "die Käse", "cheese", "audio.mp3", "qrc:/images/cheese.jpg"));
    m_recSetManager.addRecToRecSet("Default Set", DictRec(1, 2, "opportunity", "Möglichkeit", "audio.mp3", "qrc:/images/default_logo.jpg"));

    m_recSetManager.createRecSet("Default Set 2");
    m_recSetManager.addRecToRecSet("Default Set 2", DictRec(2, 1, "die Käse", "cheese", "audio.mp3", "qrc:/images/cheese.jpg"));
    m_recSetManager.addRecToRecSet("Default Set 2", DictRec(1, 2, "opportunity", "Möglichkeit", "audio.mp3", "qrc:/images/default_logo.jpg"));
}

QList<QString> AppController::getRecSetNameList() const {
    QList<QString> ret;
    for (auto& recSet : m_recSetManager.getAllRecSets()) {
        ret.append(recSet.getSetName());
    }
    return ret;
}
