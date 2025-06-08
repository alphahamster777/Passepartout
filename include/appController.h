#pragma once

#include <QList>
#include <QString>
#include <QObject>
#include <QtQml/qqml.h>

#include "recSetManager.h"

class AppController: public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(RecSetManager* recSetManager READ recSetManager)
    Q_PROPERTY(QList<QString> recSetNameList READ getRecSetNameList NOTIFY recSetNameListChanged)

public:
    AppController(QObject* parent = nullptr) {
        m_recSetManager.createRecSet("Default Set");
        m_recSetManager.addRecToRecSet("Default Set", DictRec(2, 1, "der Fahrrad", "bicycle", "audio.mp3", "qrc:/images/bicycle.jpg"));
        m_recSetManager.addRecToRecSet("Default Set", DictRec(2, 1, "die Käse", "cheese", "audio.mp3", "qrc:/images/cheese.jpg"));
        m_recSetManager.addRecToRecSet("Default Set", DictRec(1, 2, "opportunity", "Möglichkeit", "audio.mp3", "qrc:/images/default_logo.jpg"));

        m_recSetManager.createRecSet("Default Set 2");
        m_recSetManager.addRecToRecSet("Default Set 2", DictRec(2, 1, "die Käse", "cheese", "audio.mp3", "qrc:/images/cheese.jpg"));
        m_recSetManager.addRecToRecSet("Default Set 2", DictRec(1, 2, "opportunity", "Möglichkeit", "audio.mp3", "qrc:/images/default_logo.jpg"));
    }

    Q_INVOKABLE RecSetManager* recSetManager() {
        return &m_recSetManager;
    }

    QList<QString> getRecSetNameList() const {
        QList<QString> ret;
        for (auto& recSet : m_recSetManager.getAllRecSets()) {
            ret.append(recSet.getSetName());
        }
        return ret;
    }

    // This static method is required by QML_SINGLETON
    static QObject* qmlInstance(QQmlEngine*, QJSEngine*) {
        return new AppController();
    }

signals:
    void recSetNameListChanged();
private:
    RecSetManager m_recSetManager;
};
