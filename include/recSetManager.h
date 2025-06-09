#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqml.h>
#include <QVariant>

#include "dictRec.h"
#include "recSet.h"

class RecSetManager  : public QObject {
    Q_OBJECT
    QML_ELEMENT
    // QML_UNCREATABLE("Provided by AppController")
public:
    explicit RecSetManager(QObject* parent = nullptr);
    RecSetManager(const RecSetManager& other);
    RecSetManager(RecSetManager&& other);
    RecSetManager& operator=(const RecSetManager& other);
    RecSetManager& operator=(RecSetManager&& other);

    // Create a new word set
    Q_INVOKABLE bool createRecSet(const QString& setName);

    Q_INVOKABLE bool deleteRecSet(const QString& setName);

    Q_INVOKABLE void addRecToRecSet(const QString& setName, const DictRec& newWord);
    Q_INVOKABLE void addRecToRecSet(const QString& setName,
                                    const QVariantMap& rec);
    // Q_INVOKABLE bool addRecordsToRecSet(const QString& setName,
    //                             const QVariantList& records)

    Q_INVOKABLE bool removeRecFromRecSet(const std::string& setName, const DictRec& setElement);

    // Get all word sets
    std::vector<RecSet> getAllRecSets() const { return m_recSetVec; }
private:
    std::vector<RecSet> m_recSetVec; // Collection of expresion sets to learn.
};
