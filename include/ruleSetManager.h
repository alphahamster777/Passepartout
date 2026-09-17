#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqml.h>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>
#include <QSet>
#include <QStringList>

#include "ruleSet.h"

class RecSetManager;

// Mirrors RecSetManager's CRUD/persistence surface for a second, parallel
// content type. Folder/library bookkeeping (m_folderItemOrder, create/
// delete/rename/reorder folder, cross-type name uniqueness) stays owned by
// RecSetManager — see setRecSetManager() — since folders interleave word
// sets and rule sets in one shared order table; this class only owns the
// rule-specific content vector and delegates order/uniqueness questions
// to the RecSetManager it's wired to (set once by AppController at startup).
class RuleSetManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
public:
    explicit RuleSetManager(QObject* parent = nullptr);

    void setRecSetManager(RecSetManager* mgr) { m_recSetManager = mgr; }

    // Set CRUD. createRuleSet/renameRuleSet return -1/false on a name
    // collision with another rule set in the same folder (checked via
    // isRuleSetNameTaken below) — a word set or library may share the name.
    Q_INVOKABLE int createRuleSet(const QString& setName, const QString& folderPath);
    Q_INVOKABLE bool deleteRuleSetAt(int idx);
    Q_INVOKABLE bool renameRuleSet(int idx, const QString& setName);

    Q_INVOKABLE bool clearQuestionsAt(int idx);
    Q_INVOKABLE void addQuestionToSetAt(int idx, const QVariantMap& question);
    Q_INVOKABLE bool setTheoryAt(int idx, const QVariantMap& theory);

    // Returns {name, questionCount, folderPath, theory} — see RuleSet.h for
    // the theory/question shapes.
    Q_INVOKABLE QVariantMap getRuleSetInfoQML(int idx) const;
    Q_INVOKABLE QVariantMap getQuestionFromSetQML(int setIdx, int qIdx) const;
    Q_INVOKABLE int getRuleSetCount() const { return m_ruleSetVec.size(); }

    Q_INVOKABLE bool isRuleSetNameTaken(const QString& parentPath, const QString& name,
                                            int excludeIdx = -1) const;

    // Mirrors RecSetManager::moveSetToFolder exactly.
    Q_INVOKABLE bool moveRuleSetToFolder(int idx, const QString& newFolderPath,
                                             bool overwrite = false);

    Q_INVOKABLE bool saveAllToJson(const QString& filePath);
    Q_INVOKABLE bool loadFromJson(const QString& filePath);

    // Mirrors RecSetManager::exportSetToZip's .ppset format (a manifest.json
    // plus a media/ folder for any locally-referenced image/audio theory
    // blocks), with "kind":"ruleset" in the manifest distinguishing it from
    // a word-set .ppset.
    Q_INVOKABLE bool exportSetToZip(int idx, const QString& filePath);
    // Manifest-only peek — lets a caller route a shared/opened .ppset to the
    // right importer before reading the rest of it. See exportSetToZip's
    // comment for the "kind" field this checks.
    Q_INVOKABLE bool isRuleSetZip(const QString& filePath) const;
    // Inverse of exportSetToZip — returns {name, theory, questions}, or {} if
    // filePath isn't readable as a rule-set .ppset.
    Q_INVOKABLE QVariantMap readSetFromZip(const QString& filePath);

    // ── Called by RecSetManager's folder-orchestration methods ─────────────
    // (deleteFolder/renameFolder/moveFolderToFolder/mergeFolderInto/
    // findMergeSetConflicts) so rule sets stay consistent with the shared
    // folder tree RecSetManager owns. Not meant to be called from QML.
    void deleteInSubtree(const QString& folderPath);
    void updateFolderPathsForRename(const QString& oldPath, const QString& newPath);
    QVariantList findConflictsInFolder(const QString& sourcePath, const QString& destPath) const;
    // Returns true if anything got left behind ("stuck") due to a declined
    // name-collision overwrite — the caller needs this to decide whether
    // sourcePath's own bookkeeping is safe to remove after a merge.
    bool mergeDirectSetsInto(const QString& sourcePath, const QString& destPath,
                              const QSet<QString>& overwriteKeys);
    // Used by RecSetManager::getFolderItems to resolve "ruleset:NAME"
    // order-table keys. Returns -1 if no rule set named `name` exists
    // directly in `folderPath`.
    int indexOf(const QString& folderPath, const QString& name) const;

private:
    QVector<RuleSet> m_ruleSetVec;
    RecSetManager* m_recSetManager = nullptr;
};
