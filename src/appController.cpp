#include "appController.h"

AppController::AppController(QObject *parent) {
    loadData();
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
