#pragma once

#include <QList>
#include <QString>
#include <QObject>
#include <QDir>
#include <QStandardPaths>
#include <QtQml/qqml.h>

#include "baseTestController.h"
#include "recSetManager.h"

class AppController: public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(RecSetManager* recSetManager READ recSetManager CONSTANT)
    Q_PROPERTY(QList<QString> recSetNameList READ getRecSetNameList NOTIFY recSetNameListChanged)
    // BaseTestController::SpellingStrictness value (Strict/Normal/Lenient),
    // persisted via QSettings so it's remembered across sessions. Read
    // directly from the same QSettings key by checkTypedAnswer() itself —
    // this property exists so QML has something to bind the picker to.
    Q_PROPERTY(int spellingStrictness READ spellingStrictness WRITE setSpellingStrictness NOTIFY spellingStrictnessChanged)

public:
    AppController(QObject* parent = nullptr);

    Q_INVOKABLE RecSetManager* recSetManager() {
        return &m_recSetManager;
    }

    QList<QString> getRecSetNameList() const;

    Q_INVOKABLE void saveData();
    Q_INVOKABLE bool loadData();

    int spellingStrictness() const;
    void setSpellingStrictness(int value);

    // This static method is required by QML_SINGLETON
    static QObject* qmlInstance(QQmlEngine*, QJSEngine*) {
        return new AppController();
    }

signals:
    void recSetNameListChanged();
    void spellingStrictnessChanged();

private:
    RecSetManager m_recSetManager;
    QString dataFilePath() const;
};
