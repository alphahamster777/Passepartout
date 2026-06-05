#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqml.h>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QFile>
#include <QDataStream>
#include <QXmlStreamWriter>
#include <QXmlStreamReader>

#include "dictRec.h"
#include "recSet.h"

class RecSetManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
public:
    explicit RecSetManager(QObject* parent = nullptr);
    RecSetManager(const RecSetManager& other);
    RecSetManager(RecSetManager&& other);
    RecSetManager& operator=(const RecSetManager& other);
    RecSetManager& operator=(RecSetManager&& other);

    Q_INVOKABLE bool createRecSet(const QString& setName);
    Q_INVOKABLE bool deleteRecSet(const QString& setName);
    Q_INVOKABLE bool renameRecSet(int i, const QString& setName);

    Q_INVOKABLE void addRecToRecSet(const QString& setName, const DictRec& newWord);
    Q_INVOKABLE void addRecToRecSet(const QString& setName, const QVariantMap& rec);

    Q_INVOKABLE bool removeRecFromRecSet(const QString& setName, const DictRec& setElement);
    Q_INVOKABLE bool clearRecordsFromRecSet(const QString& setName);

    // Returns {name, wordCount} for the set at idx
    Q_INVOKABLE QVariantMap getRecSetInfoQML(int idx);

    // Returns word data map for word wordIdx inside set setIdx
    Q_INVOKABLE QVariantMap getWordFromRecSetQML(int setIdx, int wordIdx);

    Q_INVOKABLE QVector<RecSet> getAllRecSets() const { return m_recSetVec; }

    // Persistence
    Q_INVOKABLE bool saveAllToJson(const QString& filePath);
    Q_INVOKABLE bool loadFromJson(const QString& filePath);

    // Export a single set
    Q_INVOKABLE bool exportSetToBinary(int idx, const QString& filePath);
    Q_INVOKABLE bool exportSetToXml(int idx, const QString& filePath);

    // Import a set — returns {name, words:[{languageFrom,languageTo,expression,hint,context,audioPath,imagePath},...]}
    Q_INVOKABLE QVariantMap readSetFromBinary(const QString& filePath);
    Q_INVOKABLE QVariantMap readSetFromXml(const QString& filePath);

private:
    QVector<RecSet> m_recSetVec;

    static QString localPath(const QString& urlOrPath);
};
