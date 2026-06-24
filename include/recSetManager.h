#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqml.h>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>
#include <QMap>
#include <QStringList>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QFile>
#include <QDir>
#include <QStandardPaths>
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

    // Set CRUD
    Q_INVOKABLE bool createRecSet(const QString& setName);
    Q_INVOKABLE bool createRecSet(const QString& setName, const QString& folderPath);
    Q_INVOKABLE bool deleteRecSet(const QString& setName);
    Q_INVOKABLE bool renameRecSet(int i, const QString& setName);

    Q_INVOKABLE void addRecToRecSet(const QString& setName, const DictRec& newWord);
    Q_INVOKABLE void addRecToRecSet(const QString& setName, const QVariantMap& rec);

    Q_INVOKABLE bool removeRecFromRecSet(const QString& setName, const DictRec& setElement);
    Q_INVOKABLE bool clearRecordsFromRecSet(const QString& setName);

    // Returns {name, wordCount, folderPath} for the set at idx
    Q_INVOKABLE QVariantMap getRecSetInfoQML(int idx);

    // Returns word data map for word wordIdx inside set setIdx
    Q_INVOKABLE QVariantMap getWordFromRecSetQML(int setIdx, int wordIdx);

    Q_INVOKABLE QVector<RecSet> getAllRecSets() const { return m_recSetVec; }

    // ── Library (folder) API ──────────────────────────────────────────────────
    // Returns ordered items for a given folder: [{type,name,fullPath,index,wordCount}, ...]
    Q_INVOKABLE QVariantList getFolderItems(const QString& folderPath) const;

    // Creates an (initially empty) library at the given full path, e.g. "Travel" or "Travel/Europe"
    Q_INVOKABLE bool createFolder(const QString& folderPath);

    // Deletes a folder and all its contents (sets + nested folders)
    Q_INVOKABLE bool deleteFolder(const QString& folderPath);

    // Renames a folder at the given full path; updates all child paths
    Q_INVOKABLE bool renameFolder(const QString& oldPath, const QString& newPath);

    // Moves a set to a different folder (updates order lists)
    Q_INVOKABLE bool moveSetToFolder(int setIdx, const QString& newFolderPath);

    // Moves an entire library (and its contents) under a new parent path.
    // E.g. moveFolderToFolder("Travel/Europe", "Work") → library becomes "Work/Europe".
    Q_INVOKABLE bool moveFolderToFolder(const QString& folderPath, const QString& newParentPath);

    // Persists a new drag-and-drop ordering for a folder.
    // keys = ordered list of "folder:FULLPATH" or "set:SETNAME" strings.
    Q_INVOKABLE bool reorderFolderItems(const QString& folderPath, const QStringList& keys);

    // ── Persistence ───────────────────────────────────────────────────────────
    Q_INVOKABLE bool saveAllToJson(const QString& filePath);
    Q_INVOKABLE bool loadFromJson(const QString& filePath);

    // Export a single set
    Q_INVOKABLE bool exportSetToZip(int idx, const QString& filePath);

    // Import a set
    Q_INVOKABLE QVariantMap readSetFromZip(const QString& filePath);
    Q_INVOKABLE QVariantMap readSetFromBinary(const QString& filePath);
    Q_INVOKABLE QVariantMap readSetFromXml(const QString& filePath);

private:
    QVector<RecSet> m_recSetVec;
    // Maps folderPath → ordered list of "folder:FULLPATH" or "set:NAME" keys.
    // An entry here whose key doesn't appear in any set's folderPath represents an empty folder.
    QMap<QString, QStringList> m_folderItemOrder;

    // Appends an item key to a folder's order list if not already present.
    void ensureInOrder(const QString& folderPath, const QString& key);

    // Removes an item key from a folder's order list.
    void removeFromOrder(const QString& folderPath, const QString& key);

    // Returns the parent path of a given full path ("" for root-level items).
    static QString parentOf(const QString& fullPath);

    static QString localPath(const QString& urlOrPath);
};
