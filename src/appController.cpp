#include "appController.h"

AppController::AppController(QObject *parent) {
    if (!loadData()) {
        // First run – seed with example data
        m_recSetManager.createRecSet("Default Set");
        m_recSetManager.addRecToRecSet("Default Set", DictRec(2, 1, "der Fahrrad", "bicycle", "audio.mp3", "qrc:/images/bicycle.jpg"));
        m_recSetManager.addRecToRecSet("Default Set", DictRec(2, 1, "die Käse", "cheese", "audio.mp3", "qrc:/images/cheese.jpg"));
        m_recSetManager.addRecToRecSet("Default Set", DictRec(1, 2, "opportunity", "Möglichkeit", "audio.mp3", "qrc:/images/default_logo.jpg"));

        m_recSetManager.createRecSet("Default Set 2");
        m_recSetManager.addRecToRecSet("Default Set 2", DictRec(2, 1, "die Käse", "cheese", "audio.mp3", "qrc:/images/cheese.jpg"));
        m_recSetManager.addRecToRecSet("Default Set 2", DictRec(1, 2, "opportunity", "Möglichkeit", "audio.mp3", "qrc:/images/default_logo.jpg"));
    }
}

QList<QString> AppController::getRecSetNameList() const {
    QList<QString> ret;
    for (auto& recSet : m_recSetManager.getAllRecSets()) {
        ret.append(recSet.getSetName());
    }
    return ret;
}

QString AppController::dataFilePath() const {
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + "/wordsets.json";
}

void AppController::saveData() {
    m_recSetManager.saveAllToJson(dataFilePath());
}

bool AppController::loadData() {
    return m_recSetManager.loadFromJson(dataFilePath());
}
