#pragma once

#include <QList>
#include <QString>
#include <QObject>
#include <QDir>
#include <QStandardPaths>
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
    AppController(QObject* parent = nullptr);

    Q_INVOKABLE RecSetManager* recSetManager() {
        return &m_recSetManager;
    }

    QList<QString> getRecSetNameList() const;

    Q_INVOKABLE void saveData();
    Q_INVOKABLE bool loadData();

    // This static method is required by QML_SINGLETON
    static QObject* qmlInstance(QQmlEngine*, QJSEngine*) {
        return new AppController();
    }

signals:
    void recSetNameListChanged();

private:
    RecSetManager m_recSetManager;
    QString dataFilePath() const;
};
