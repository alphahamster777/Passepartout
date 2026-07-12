#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqml.h>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>
#include <QMap>
#include <QSet>
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
    // Returns the index of the newly created set, or -1 if a library or set already
    // named `setName` exists directly in `folderPath` (names are unique per-folder,
    // not app-wide — the same name may exist in different folders).
    Q_INVOKABLE int createRecSet(const QString& setName);
    Q_INVOKABLE int createRecSet(const QString& setName, const QString& folderPath);
    Q_INVOKABLE bool deleteRecSet(const QString& setName);
    Q_INVOKABLE bool deleteRecSetAt(int idx);

    // Renames the set at idx; refused if another set/library already has that name
    // in the same folder.
    Q_INVOKABLE bool renameRecSet(int i, const QString& setName);

    Q_INVOKABLE void addRecToRecSet(const QString& setName, const DictRec& newWord);
    Q_INVOKABLE void addRecToRecSet(const QString& setName, const QVariantMap& rec);
    Q_INVOKABLE void addRecToRecSetAt(int idx, const QVariantMap& rec);

    Q_INVOKABLE bool removeRecFromRecSet(const QString& setName, const DictRec& setElement);
    Q_INVOKABLE bool clearRecordsFromRecSet(const QString& setName);
    Q_INVOKABLE bool clearRecordsFromRecSetAt(int idx);

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

    // Moves a set to a different folder (updates order lists).
    // If a set with the same name already exists at newFolderPath: with overwrite=false
    // the move is refused (returns false, nothing changes); with overwrite=true the
    // existing destination set is replaced by the moved one.
    Q_INVOKABLE bool moveSetToFolder(int setIdx, const QString& newFolderPath, bool overwrite = false);

    // Moves an entire library (and its contents) under a new parent path.
    // E.g. moveFolderToFolder("Travel/Europe", "Work") → library becomes "Work/Europe".
    // If a library with the same name already exists at newParentPath: with merge=false
    // the move is refused (returns false, nothing changes); with merge=true the two
    // libraries' contents are combined into one, leaving a single library with that name.
    // Any set-name collision among their children is overwritten only if its
    // "destFolderPath|setName" key (see findMergeSetConflicts) is present in
    // overwriteKeys; otherwise that one set is left behind, unmerged, in its
    // original library.
    Q_INVOKABLE bool moveFolderToFolder(const QString& folderPath, const QString& newParentPath,
                                         bool merge = false, const QStringList& overwriteKeys = {});

    // Dry-runs a moveFolderToFolder(..., merge=true) of sourcePath into the
    // already-existing destPath library and returns every set-name collision it
    // would need to resolve, recursing into colliding sub-libraries too:
    // [{name, destFolder}, ...]. Ask the user about each before calling
    // moveFolderToFolder with the approved "destFolder|name" keys.
    Q_INVOKABLE QVariantList findMergeSetConflicts(const QString& sourcePath, const QString& destPath) const;

    // Returns true if a sibling library already named `name` exists directly under
    // `parentPath`. Pass the full path of the library being renamed/moved as
    // `excludeFullPath` so it doesn't collide with itself.
    Q_INVOKABLE bool isLibraryNameTaken(const QString& parentPath, const QString& name,
                                         const QString& excludeFullPath = QString()) const;

    // Returns true if a sibling set already named `name` exists directly under
    // `parentPath`. Pass the index of the set being moved as `excludeSetIdx` so it
    // doesn't collide with itself.
    Q_INVOKABLE bool isSetNameTaken(const QString& parentPath, const QString& name,
                                     int excludeSetIdx = -1) const;

    // Returns true if a library or set already named `name` exists directly under
    // `parentPath`. Pass the full path of the library being renamed/moved as
    // `excludeFullPath` so it doesn't collide with itself.
    Q_INVOKABLE bool isFolderNameTaken(const QString& parentPath, const QString& name,
                                        const QString& excludeFullPath = QString()) const;

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

    // Merges every set and sub-library directly/indirectly under sourcePath into the
    // already-existing destPath library. A colliding set is overwritten only if its
    // "destFolderPath|setName" key is in overwriteKeys; otherwise it's left behind.
    void mergeFolderInto(const QString& sourcePath, const QString& destPath,
                          const QSet<QString>& overwriteKeys);

    // Builds a DictRec from a QML-supplied word map (languageFrom, languageTo,
    // expression, hint, audioPath, imagePath).
    static DictRec dictRecFromVariant(const QVariantMap& rec);
};
