#include "recSetManager.h"

#include <private/qzipreader_p.h>
#include <private/qzipwriter_p.h>
#include <QFileInfo>
#include <QPair>
#include <QUuid>

RecSetManager::RecSetManager(QObject *parent) : QObject(parent) {}

RecSetManager::RecSetManager(const RecSetManager &other) {
    m_recSetVec = other.m_recSetVec;
    m_folderItemOrder = other.m_folderItemOrder;
}

RecSetManager::RecSetManager(RecSetManager &&other) {
    m_recSetVec = std::move(other.m_recSetVec);
    m_folderItemOrder = std::move(other.m_folderItemOrder);
}

RecSetManager &RecSetManager::operator=(const RecSetManager &other) {
    m_recSetVec = other.m_recSetVec;
    m_folderItemOrder = other.m_folderItemOrder;
    return *this;
}

RecSetManager &RecSetManager::operator=(RecSetManager &&other) {
    m_recSetVec = std::move(other.m_recSetVec);
    m_folderItemOrder = std::move(other.m_folderItemOrder);
    return *this;
}

// ── helpers ───────────────────────────────────────────────────────────────────

QString RecSetManager::parentOf(const QString& fullPath) {
    int slash = fullPath.lastIndexOf('/');
    return slash == -1 ? QString() : fullPath.left(slash);
}

void RecSetManager::ensureInOrder(const QString& folderPath, const QString& key) {
    auto& list = m_folderItemOrder[folderPath];
    if (!list.contains(key))
        list.append(key);
}

void RecSetManager::removeFromOrder(const QString& folderPath, const QString& key) {
    auto it = m_folderItemOrder.find(folderPath);
    if (it != m_folderItemOrder.end())
        it->removeAll(key);
}

// ── Set CRUD ──────────────────────────────────────────────────────────────────

int RecSetManager::createRecSet(const QString &setName) {
    return createRecSet(setName, QString());
}

int RecSetManager::createRecSet(const QString &setName, const QString &folderPath) {
    if (isFolderNameTaken(folderPath, setName))
        return -1;
    RecSet rs(setName);
    rs.setFolderPath(folderPath);
    m_recSetVec.push_back(std::move(rs));
    ensureInOrder(folderPath, "set:" + setName);
    return static_cast<int>(m_recSetVec.size()) - 1;
}

bool RecSetManager::deleteRecSet(const QString &setName) {
    for (auto it = m_recSetVec.begin(); it != m_recSetVec.end(); ++it) {
        if (it->getSetName() == setName) {
            removeFromOrder(it->getFolderPath(), "set:" + setName);
            m_recSetVec.erase(it);
            return true;
        }
    }
    return false;
}

bool RecSetManager::deleteRecSetAt(int idx) {
    if (idx < 0 || idx >= m_recSetVec.size()) return false;
    const auto& rs = m_recSetVec.at(idx);
    removeFromOrder(rs.getFolderPath(), "set:" + rs.getSetName());
    m_recSetVec.erase(m_recSetVec.begin() + idx);
    return true;
}

bool RecSetManager::renameRecSet(int i, const QString &setName) {
    if (i < 0 || i >= m_recSetVec.size()) return false;
    const QString folderPath = m_recSetVec.at(i).getFolderPath();
    const QString oldName    = m_recSetVec.at(i).getSetName();
    if (oldName == setName) return true;
    if (isFolderNameTaken(folderPath, setName))
        return false;
    removeFromOrder(folderPath, "set:" + oldName);
    m_recSetVec[i].setRecSetName(setName);
    ensureInOrder(folderPath, "set:" + setName);
    return true;
}

DictRec RecSetManager::dictRecFromVariant(const QVariantMap &rec) {
    return DictRec{
        static_cast<size_t>(rec.value("languageFrom").toInt()),
        static_cast<size_t>(rec.value("languageTo"  ).toInt()),
        rec.value("expression"  ).toString(),
        rec.value("hint"        ).toString(),
        rec.value("audioPath"   ).toString(),
        rec.value("imagePath"   ).toString(),
        rec.value("exampleUsage").toString()
    };
}

void RecSetManager::addRecToRecSet(const QString &setName, const DictRec &newWord) {
    for (auto& recSet : m_recSetVec) {
        if (recSet.getSetName() == setName) {
            recSet.addWord(newWord);
            return;
        }
    }
    createRecSet(setName);
    m_recSetVec.back().addWord(newWord);
}

void RecSetManager::addRecToRecSet(const QString &setName, const QVariantMap &rec) {
    addRecToRecSet(setName, dictRecFromVariant(rec));
}

void RecSetManager::addRecToRecSetAt(int idx, const QVariantMap &rec) {
    if (idx < 0 || idx >= m_recSetVec.size()) return;
    m_recSetVec[idx].addWord(dictRecFromVariant(rec));
}

bool RecSetManager::removeRecFromRecSet(const QString &setName, const DictRec &setElement) {
    for (auto& recSet : m_recSetVec) {
        if (recSet.getSetName() == setName)
            return recSet.removeWord(setElement);
    }
    return false;
}

bool RecSetManager::clearRecordsFromRecSet(const QString &setName) {
    for (auto& recSet : m_recSetVec) {
        if (recSet.getSetName() == setName) {
            recSet.clearWords();
            return true;
        }
    }
    return false;
}

bool RecSetManager::clearRecordsFromRecSetAt(int idx) {
    if (idx < 0 || idx >= m_recSetVec.size()) return false;
    m_recSetVec[idx].clearWords();
    return true;
}

QVariantMap RecSetManager::getRecSetInfoQML(int idx) {
    if (idx < 0 || idx >= m_recSetVec.size())
        return {};
    const auto& rs = m_recSetVec.at(idx);
    QVariantMap map;
    map["name"]       = rs.getSetName();
    map["wordCount"]  = rs.getWordCount();
    map["folderPath"] = rs.getFolderPath();
    return map;
}

QVariantMap RecSetManager::getWordFromRecSetQML(int setIdx, int wordIdx) {
    if (setIdx < 0 || setIdx >= m_recSetVec.size())
        return {};
    return m_recSetVec.at(setIdx).getWordAtQML(static_cast<size_t>(wordIdx));
}

// ── Library (folder) API ──────────────────────────────────────────────────────

QVariantList RecSetManager::getFolderItems(const QString& folderPath) const {
    // Determine which item keys are valid (exist in sets or as folder entries)
    QSet<QString> validFolderKeys;
    for (auto it = m_folderItemOrder.begin(); it != m_folderItemOrder.end(); ++it) {
        // Any folder that has an entry under some parent is a valid folder key
        if (!it.key().isEmpty())
            validFolderKeys.insert("folder:" + it.key());
    }

    // Set names are only unique within a folder, so index sets by (folder, name) —
    // not by name alone — to avoid resolving to a same-named set in another folder.
    QMap<QPair<QString, QString>, int> setIndexByFolderAndName;
    for (int i = 0; i < m_recSetVec.size(); ++i) {
        const auto& rs = m_recSetVec.at(i);
        setIndexByFolderAndName[{rs.getFolderPath(), rs.getSetName()}] = i;
    }

    // Start with explicitly ordered items for this folder
    QVariantList result;
    QSet<QString> seen;

    auto it = m_folderItemOrder.find(folderPath);
    if (it != m_folderItemOrder.end()) {
        for (const QString& key : *it) {
            seen.insert(key);
            if (key.startsWith(QLatin1String("folder:"))) {
                QString fp = key.mid(7);
                // Only show immediate children
                if (parentOf(fp) != folderPath) continue;
                // Check if this folder still has any content or is explicitly tracked
                bool exists = m_folderItemOrder.contains(fp);
                if (!exists) {
                    // Check if any set lives under it
                    for (const auto& rs : m_recSetVec) {
                        if (rs.getFolderPath() == fp ||
                            rs.getFolderPath().startsWith(fp + "/")) {
                            exists = true;
                            break;
                        }
                    }
                }
                if (!exists) continue;
                QString displayName = fp.section('/', -1);
                QVariantMap item;
                item["type"]     = QStringLiteral("folder");
                item["name"]     = displayName;
                item["fullPath"] = fp;
                item["index"]    = -1;
                item["wordCount"] = 0;
                result.append(item);
            } else if (key.startsWith(QLatin1String("set:"))) {
                QString name = key.mid(4);
                auto sit = setIndexByFolderAndName.find({folderPath, name});
                if (sit == setIndexByFolderAndName.end()) continue;
                int idx = sit.value();
                QVariantMap item;
                item["type"]     = QStringLiteral("set");
                item["name"]     = name;
                item["fullPath"] = QString();
                item["index"]    = idx;
                item["wordCount"] = m_recSetVec.at(idx).getWordCount();
                result.append(item);
            }
        }
    }

    // Append any sets in this folder not yet covered by the order list
    for (int i = 0; i < m_recSetVec.size(); ++i) {
        const auto& rs = m_recSetVec.at(i);
        if (rs.getFolderPath() != folderPath) continue;
        QString key = "set:" + rs.getSetName();
        if (seen.contains(key)) continue;
        QVariantMap item;
        item["type"]     = QStringLiteral("set");
        item["name"]     = rs.getSetName();
        item["fullPath"] = QString();
        item["index"]    = i;
        item["wordCount"] = rs.getWordCount();
        result.append(item);
    }

    return result;
}

bool RecSetManager::isLibraryNameTaken(const QString& parentPath, const QString& name,
                                        const QString& excludeFullPath) const {
    if (name.isEmpty()) return false;
    QString fullPath = parentPath.isEmpty() ? name : parentPath + "/" + name;
    if (fullPath == excludeFullPath) return false;

    auto it = m_folderItemOrder.find(parentPath);
    return it != m_folderItemOrder.end() && it->contains("folder:" + fullPath);
}

bool RecSetManager::isSetNameTaken(const QString& parentPath, const QString& name,
                                    int excludeSetIdx) const {
    if (name.isEmpty()) return false;
    for (int i = 0; i < m_recSetVec.size(); ++i) {
        if (i == excludeSetIdx) continue;
        const auto& rs = m_recSetVec.at(i);
        if (rs.getFolderPath() == parentPath && rs.getSetName() == name)
            return true;
    }
    return false;
}

bool RecSetManager::isFolderNameTaken(const QString& parentPath, const QString& name,
                                       const QString& excludeFullPath) const {
    return isLibraryNameTaken(parentPath, name, excludeFullPath) ||
           isSetNameTaken(parentPath, name);
}

bool RecSetManager::createFolder(const QString& folderPath) {
    if (folderPath.isEmpty()) return false;
    QString parent = parentOf(folderPath);
    QString name   = folderPath.section('/', -1);
    if (isFolderNameTaken(parent, name))
        return false;
    // Mark this folder in the parent's order list and ensure it has an entry in the map
    ensureInOrder(parent, "folder:" + folderPath);
    if (!m_folderItemOrder.contains(folderPath))
        m_folderItemOrder[folderPath] = {};
    return true;
}

bool RecSetManager::deleteFolder(const QString& folderPath) {
    if (folderPath.isEmpty()) return false;

    // Delete all sets whose path starts with folderPath or folderPath + "/"
    auto sit = m_recSetVec.begin();
    while (sit != m_recSetVec.end()) {
        const QString& fp = sit->getFolderPath();
        if (fp == folderPath || fp.startsWith(folderPath + "/")) {
            sit = m_recSetVec.erase(sit);
        } else {
            ++sit;
        }
    }

    // Remove all order entries for the folder and its children
    QList<QString> toRemove;
    for (auto it = m_folderItemOrder.begin(); it != m_folderItemOrder.end(); ++it) {
        if (it.key() == folderPath || it.key().startsWith(folderPath + "/"))
            toRemove.append(it.key());
    }
    for (const QString& k : toRemove)
        m_folderItemOrder.remove(k);

    // Remove the folder key from the parent
    removeFromOrder(parentOf(folderPath), "folder:" + folderPath);
    return true;
}

bool RecSetManager::renameFolder(const QString& oldPath, const QString& newPath) {
    if (oldPath.isEmpty() || newPath.isEmpty()) return false;
    if (oldPath == newPath) return true;

    QString newParent = parentOf(newPath);
    QString newName   = newPath.section('/', -1);
    if (isFolderNameTaken(newParent, newName, oldPath))
        return false;

    // Update all sets whose folderPath starts with oldPath
    for (auto& rs : m_recSetVec) {
        const QString& fp = rs.getFolderPath();
        if (fp == oldPath) {
            rs.setFolderPath(newPath);
        } else if (fp.startsWith(oldPath + "/")) {
            rs.setFolderPath(newPath + fp.mid(oldPath.length()));
        }
    }

    // Rebuild order map entries for the renamed subtree
    QMap<QString, QStringList> rebuildEntries;
    QList<QString> toRemove;
    for (auto it = m_folderItemOrder.begin(); it != m_folderItemOrder.end(); ++it) {
        const QString& key = it.key();
        if (key == oldPath || key.startsWith(oldPath + "/")) {
            QString newKey = newPath + key.mid(oldPath.length());
            // Remap "folder:OLD/..." keys inside the list
            QStringList newList;
            for (const QString& item : it.value()) {
                if (item.startsWith("folder:" + oldPath))
                    newList.append("folder:" + newPath + item.mid(7 + oldPath.length()));
                else
                    newList.append(item);
            }
            rebuildEntries[newKey] = newList;
            toRemove.append(key);
        }
    }
    for (const QString& k : toRemove)
        m_folderItemOrder.remove(k);
    for (auto it = rebuildEntries.begin(); it != rebuildEntries.end(); ++it)
        m_folderItemOrder[it.key()] = it.value();

    // Update the parent's order list reference
    QString parent = parentOf(oldPath);
    auto& parentList = m_folderItemOrder[parent];
    int idx = parentList.indexOf("folder:" + oldPath);
    if (idx != -1)
        parentList[idx] = "folder:" + newPath;

    return true;
}

bool RecSetManager::moveSetToFolder(int setIdx, const QString& newFolderPath, bool overwrite) {
    if (setIdx < 0 || setIdx >= m_recSetVec.size()) return false;
    QString oldFolder = m_recSetVec.at(setIdx).getFolderPath();
    QString setName   = m_recSetVec.at(setIdx).getSetName();
    if (oldFolder == newFolderPath) return false;

    // A library with the same name can't be overwritten by a set.
    if (isLibraryNameTaken(newFolderPath, setName)) return false;

    int clashIdx = -1;
    for (int i = 0; i < m_recSetVec.size(); ++i) {
        if (i == setIdx) continue;
        if (m_recSetVec.at(i).getFolderPath() == newFolderPath &&
            m_recSetVec.at(i).getSetName() == setName) {
            clashIdx = i;
            break;
        }
    }
    if (clashIdx != -1) {
        if (!overwrite) return false;
        removeFromOrder(newFolderPath, "set:" + setName);
        m_recSetVec.erase(m_recSetVec.begin() + clashIdx);
        if (clashIdx < setIdx) --setIdx;
    }

    removeFromOrder(oldFolder, "set:" + setName);
    m_recSetVec[setIdx].setFolderPath(newFolderPath);
    ensureInOrder(newFolderPath, "set:" + setName);
    return true;
}

bool RecSetManager::reorderFolderItems(const QString& folderPath, const QStringList& keys) {
    m_folderItemOrder[folderPath] = keys;
    return true;
}

bool RecSetManager::moveFolderToFolder(const QString& folderPath, const QString& newParentPath,
                                        bool merge, const QStringList& overwriteKeys) {
    if (folderPath.isEmpty()) return false;

    QString lastName = folderPath.section('/', -1);
    QString newPath  = newParentPath.isEmpty() ? lastName : newParentPath + "/" + lastName;

    if (newPath == folderPath) return false;
    // Prevent moving a folder into itself or any of its descendants
    if (newParentPath == folderPath || newParentPath.startsWith(folderPath + "/"))
        return false;
    // A set with the same name can't be merged into or replaced by a library.
    if (isSetNameTaken(newParentPath, lastName)) return false;

    if (isLibraryNameTaken(newParentPath, lastName, folderPath)) {
        if (!merge) return false;
        mergeFolderInto(folderPath, newPath,
                         QSet<QString>(overwriteKeys.cbegin(), overwriteKeys.cend()));
        return true;
    }

    // 1. Update folderPath on every set inside this subtree
    for (auto& rs : m_recSetVec) {
        const QString& fp = rs.getFolderPath();
        if (fp == folderPath)
            rs.setFolderPath(newPath);
        else if (fp.startsWith(folderPath + "/"))
            rs.setFolderPath(newPath + fp.mid(folderPath.length()));
    }

    // 2. Rebuild the order map for the moved subtree
    QMap<QString, QStringList> toAdd;
    QList<QString> toRemove;
    for (auto it = m_folderItemOrder.begin(); it != m_folderItemOrder.end(); ++it) {
        const QString& key = it.key();
        if (key == folderPath || key.startsWith(folderPath + "/")) {
            QString newKey = newPath + key.mid(folderPath.length());
            QStringList newList;
            for (const QString& item : it.value()) {
                if (item.startsWith("folder:" + folderPath))
                    newList.append("folder:" + newPath + item.mid(7 + folderPath.length()));
                else
                    newList.append(item);
            }
            toAdd[newKey] = newList;
            toRemove.append(key);
        }
    }
    for (const QString& k : toRemove)
        m_folderItemOrder.remove(k);
    for (auto it = toAdd.begin(); it != toAdd.end(); ++it)
        m_folderItemOrder[it.key()] = it.value();

    // 3. Remove from old parent's order, add to new parent's order
    removeFromOrder(parentOf(folderPath), "folder:" + folderPath);
    ensureInOrder(newParentPath, "folder:" + newPath);

    return true;
}

QVariantList RecSetManager::findMergeSetConflicts(const QString& sourcePath, const QString& destPath) const {
    QVariantList result;

    for (const auto& rs : m_recSetVec) {
        if (rs.getFolderPath() == sourcePath && isSetNameTaken(destPath, rs.getSetName())) {
            QVariantMap m;
            m["name"]       = rs.getSetName();
            m["destFolder"] = destPath;
            result.append(m);
        }
    }

    auto orderIt = m_folderItemOrder.find(sourcePath);
    if (orderIt != m_folderItemOrder.end()) {
        for (const QString& key : orderIt.value()) {
            if (!key.startsWith(QLatin1String("folder:"))) continue;
            QString fp = key.mid(7);
            if (parentOf(fp) != sourcePath) continue;
            QString childName = fp.section('/', -1);
            if (isLibraryNameTaken(destPath, childName)) {
                QString childDest = destPath.isEmpty() ? childName : destPath + "/" + childName;
                result += findMergeSetConflicts(fp, childDest);
            }
            // No library collision at destPath — the whole subtree just moves over,
            // so nothing pre-exists there for its sets to clash with.
        }
    }

    return result;
}

void RecSetManager::mergeFolderInto(const QString& sourcePath, const QString& destPath,
                                     const QSet<QString>& overwriteKeys) {
    // Move every direct set out of sourcePath into destPath. A colliding set is
    // overwritten only if the caller approved its "destFolder|name" key; otherwise
    // (declined, or it clashes with a same-named sub-library) it's left behind.
    QSet<int> stuckSetIdx;
    for (;;) {
        int idx = -1;
        for (int i = 0; i < m_recSetVec.size(); ++i) {
            if (m_recSetVec.at(i).getFolderPath() == sourcePath && !stuckSetIdx.contains(i)) {
                idx = i;
                break;
            }
        }
        if (idx == -1) break;

        const QString setName = m_recSetVec.at(idx).getSetName();
        if (isSetNameTaken(destPath, setName) &&
            !overwriteKeys.contains(destPath + "|" + setName)) {
            stuckSetIdx.insert(idx);
            continue;
        }
        if (!moveSetToFolder(idx, destPath, /*overwrite=*/true))
            stuckSetIdx.insert(idx);
    }

    // Move every direct sub-library, merging into same-named siblings recursively.
    QStringList childFolders;
    auto orderIt = m_folderItemOrder.find(sourcePath);
    if (orderIt != m_folderItemOrder.end()) {
        for (const QString& key : orderIt.value()) {
            if (!key.startsWith(QLatin1String("folder:"))) continue;
            QString fp = key.mid(7);
            if (parentOf(fp) == sourcePath)
                childFolders.append(fp);
        }
    }
    for (const QString& childSource : childFolders) {
        QString childName = childSource.section('/', -1);
        if (isLibraryNameTaken(destPath, childName)) {
            // Recursive merge cleans up childSource's own bookkeeping when done.
            QString childDest = destPath.isEmpty() ? childName : destPath + "/" + childName;
            mergeFolderInto(childSource, childDest, overwriteKeys);
        } else {
            // No clash — a plain move re-parents childSource (and its whole subtree).
            moveFolderToFolder(childSource, destPath);
        }
    }

    // Drop sourcePath's own bookkeeping only if it's actually empty now — a stuck
    // set (see above) keeps it alive so nothing becomes invisible/orphaned.
    bool stillHasSets = !stuckSetIdx.isEmpty();
    bool stillHasFolders = false;
    auto remainingIt = m_folderItemOrder.find(sourcePath);
    if (remainingIt != m_folderItemOrder.end()) {
        for (const QString& key : remainingIt.value()) {
            if (key.startsWith(QLatin1String("folder:"))) { stillHasFolders = true; break; }
        }
    }
    if (!stillHasSets && !stillHasFolders) {
        removeFromOrder(parentOf(sourcePath), "folder:" + sourcePath);
        m_folderItemOrder.remove(sourcePath);
    }
}

// ── static helpers ────────────────────────────────────────────────────────────

QString RecSetManager::localPath(const QString& urlOrPath) {
    QUrl url(urlOrPath);
    return url.isLocalFile() ? url.toLocalFile() : urlOrPath;
}

static QJsonObject wordToJson(const DictRec& w) {
    QJsonObject o;
    o["exprLangID"]   = w.getExprLanguageID();
    o["hintLangID"]   = w.getHintLanguageID();
    o["expression"]   = w.getExpression();
    o["hint"]         = w.getHint();
    o["audioPath"]    = w.getAudioPath();
    o["imagePath"]    = w.getImagePath();
    o["exampleUsage"] = w.getExampleUsage();
    return o;
}

static DictRec wordFromJson(const QJsonObject& o) {
    return DictRec{
        static_cast<size_t>(o["exprLangID"].toInt()),
        static_cast<size_t>(o["hintLangID"].toInt()),
        o["expression"].toString(),
        o["hint"].toString(),
        o["audioPath"].toString(),
        o["imagePath"].toString(),
        o["exampleUsage"].toString()
    };
}

// ── Persistence ───────────────────────────────────────────────────────────────

bool RecSetManager::saveAllToJson(const QString& filePath) {
    QJsonArray setsArr;
    for (const auto& rs : m_recSetVec) {
        QJsonObject setObj;
        setObj["name"]       = rs.getSetName();
        setObj["folderPath"] = rs.getFolderPath();
        QJsonArray wordsArr;
        for (int i = 0; i < rs.getWordCount(); ++i)
            wordsArr.append(wordToJson(rs.getWordAt(static_cast<size_t>(i))));
        setObj["words"] = wordsArr;
        setsArr.append(setObj);
    }

    QJsonObject orderObj;
    for (auto it = m_folderItemOrder.begin(); it != m_folderItemOrder.end(); ++it) {
        QJsonArray arr;
        for (const QString& k : it.value())
            arr.append(k);
        orderObj[it.key()] = arr;
    }

    QJsonObject root;
    root["version"] = 2;
    root["sets"]    = setsArr;
    root["order"]   = orderObj;

    QFile file(localPath(filePath));
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return false;
    file.write(QJsonDocument(root).toJson());
    return true;
}

bool RecSetManager::loadFromJson(const QString& filePath) {
    QFile file(localPath(filePath));
    if (!file.open(QIODevice::ReadOnly))
        return false;
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());

    m_recSetVec.clear();
    m_folderItemOrder.clear();

    // v1 format: bare JSON array of sets (no folderPath, no order)
    if (doc.isArray()) {
        for (const auto& setVal : doc.array()) {
            QJsonObject setObj = setVal.toObject();
            RecSet rs(setObj["name"].toString());
            for (const auto& wv : setObj["words"].toArray())
                rs.addWord(wordFromJson(wv.toObject()));
            m_recSetVec.push_back(std::move(rs));
        }
        // Rebuild default order (flat, root-level)
        for (const auto& rs : m_recSetVec)
            ensureInOrder(QString(), "set:" + rs.getSetName());
        return true;
    }

    if (!doc.isObject()) return false;
    QJsonObject root = doc.object();

    for (const auto& setVal : root["sets"].toArray()) {
        QJsonObject setObj = setVal.toObject();
        RecSet rs(setObj["name"].toString());
        rs.setFolderPath(setObj["folderPath"].toString());
        for (const auto& wv : setObj["words"].toArray())
            rs.addWord(wordFromJson(wv.toObject()));
        m_recSetVec.push_back(std::move(rs));
    }

    QJsonObject orderObj = root["order"].toObject();
    for (auto it = orderObj.begin(); it != orderObj.end(); ++it) {
        QStringList list;
        for (const auto& v : it.value().toArray())
            list.append(v.toString());
        m_folderItemOrder[it.key()] = list;
    }

    return true;
}

// ── ZIP Export / Import ───────────────────────────────────────────────────────

// manifest.json schema:
// { "version":1, "name":"...", "words":[{ exprLangID, hintLangID, expression, hint,
//   "imagePath":"media/img_0.jpg"|"https://..."|"", "audioPath":"media/aud_0.mp3"|""|... }] }
// Paths starting with "http" are kept as-is; everything else is embedded in media/.

static bool isUrl(const QString& s) {
    return s.startsWith(QLatin1String("http://")) || s.startsWith(QLatin1String("https://"));
}

bool RecSetManager::exportSetToZip(int idx, const QString& filePath) {
    if (idx < 0 || idx >= m_recSetVec.size())
        return false;

    const auto& rs = m_recSetVec.at(idx);
    QZipWriter zip(localPath(filePath));
    zip.setCompressionPolicy(QZipWriter::AutoCompress);

    QJsonArray wordsArr;
    int mediaIdx = 0;

    for (int i = 0; i < rs.getWordCount(); ++i) {
        const auto& w = rs.getWordAt(static_cast<size_t>(i));
        QJsonObject obj;
        obj[QStringLiteral("exprLangID")] = w.getExprLanguageID();
        obj[QStringLiteral("hintLangID")] = w.getHintLanguageID();
        obj[QStringLiteral("expression")]   = w.getExpression();
        obj[QStringLiteral("hint")]         = w.getHint();
        obj[QStringLiteral("exampleUsage")] = w.getExampleUsage();

        // image
        QString imgPath = w.getImagePath();
        if (!imgPath.isEmpty() && !isUrl(imgPath)) {
            QString local = localPath(imgPath);
            QFile f(local);
            if (f.open(QIODevice::ReadOnly)) {
                QString ext  = QFileInfo(local).suffix();
                QString name = QStringLiteral("media/img_%1.%2").arg(mediaIdx++).arg(ext);
                zip.addFile(name, f.readAll());
                imgPath = name;
            }
        }
        obj[QStringLiteral("imagePath")] = imgPath;

        // audio
        QString audPath = w.getAudioPath();
        if (!audPath.isEmpty() && !isUrl(audPath)) {
            QString local = localPath(audPath);
            QFile f(local);
            if (f.open(QIODevice::ReadOnly)) {
                QString ext  = QFileInfo(local).suffix();
                QString name = QStringLiteral("media/aud_%1.%2").arg(mediaIdx++).arg(ext);
                zip.addFile(name, f.readAll());
                audPath = name;
            }
        }
        obj[QStringLiteral("audioPath")] = audPath;

        wordsArr.append(obj);
    }

    QJsonObject manifest;
    manifest[QStringLiteral("version")] = 1;
    manifest[QStringLiteral("name")]    = rs.getSetName();
    manifest[QStringLiteral("words")]   = wordsArr;
    zip.addFile(QStringLiteral("manifest.json"), QJsonDocument(manifest).toJson());
    zip.close();
    return zip.status() == QZipWriter::NoError;
}

QVariantMap RecSetManager::readSetFromZip(const QString& filePath) {
    QZipReader zip(localPath(filePath));
    QByteArray manifestData = zip.fileData(QStringLiteral("manifest.json"));
    if (manifestData.isEmpty())
        return {};

    QJsonObject manifest = QJsonDocument::fromJson(manifestData).object();
    QString setName = manifest[QStringLiteral("name")].toString();

    // Extract media files into a unique cache directory under AppDataLocation
    QString cacheBase = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
                        + QStringLiteral("/import_cache/")
                        + QUuid::createUuid().toString(QUuid::Id128).left(8)
                        + QStringLiteral("/");
    QDir().mkpath(cacheBase);

    // Pre-extract all media/ entries
    for (const auto& entry : zip.fileInfoList()) {
        if (entry.filePath.startsWith(QLatin1String("media/"))) {
            QByteArray data = zip.fileData(entry.filePath);
            if (data.isEmpty()) continue;
            QString dest = cacheBase + entry.filePath;
            QDir().mkpath(QFileInfo(dest).absolutePath());
            QFile out(dest);
            if (out.open(QIODevice::WriteOnly))
                out.write(data);
        }
    }
    zip.close();

    QVariantList words;
    for (const auto& wv : manifest[QStringLiteral("words")].toArray()) {
        QJsonObject wo = wv.toObject();
        QString imgPath = wo[QStringLiteral("imagePath")].toString();
        QString audPath = wo[QStringLiteral("audioPath")].toString();

        // Resolve relative media paths to absolute cache paths
        if (!imgPath.isEmpty() && !isUrl(imgPath))
            imgPath = QUrl::fromLocalFile(cacheBase + imgPath).toString();
        if (!audPath.isEmpty() && !isUrl(audPath))
            audPath = QUrl::fromLocalFile(cacheBase + audPath).toString();

        QVariantMap w;
        w[QStringLiteral("languageFrom")] = wo[QStringLiteral("exprLangID")].toInt();
        w[QStringLiteral("languageTo")]   = wo[QStringLiteral("hintLangID")].toInt();
        w[QStringLiteral("expression")]   = wo[QStringLiteral("expression")].toString();
        w[QStringLiteral("hint")]         = wo[QStringLiteral("hint")].toString();
        w[QStringLiteral("audioPath")]    = audPath;
        w[QStringLiteral("imagePath")]    = imgPath;
        w[QStringLiteral("exampleUsage")] = wo[QStringLiteral("exampleUsage")].toString();
        words.append(w);
    }

    QVariantMap result;
    result[QStringLiteral("name")]  = setName;
    result[QStringLiteral("words")] = words;
    return result;
}

// ── Legacy Binary/XML Export ──────────────────────────────────────────────────

static const quint32 k_binaryMagic   = 0x50505354; // "PPST"
static const quint16 k_binaryVersion = 1;

// bool RecSetManager::exportSetToBinary(int idx, const QString& filePath) {
//     if (idx < 0 || idx >= m_recSetVec.size())
//         return false;
//     QFile file(localPath(filePath));
//     if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
//         return false;
//     QDataStream out(&file);
//     out.setVersion(QDataStream::Qt_6_5);
//     out << k_binaryMagic << k_binaryVersion;
//     const auto& rs = m_recSetVec.at(idx);
//     out << rs.getSetName() << qint32(rs.getWordCount());
//     for (int i = 0; i < rs.getWordCount(); ++i) {
//         const auto& w = rs.getWordAt(static_cast<size_t>(i));
//         out << qint32(w.getExprLanguageID())
//             << qint32(w.getHintLanguageID())
//             << w.getExpression()
//             << w.getHint()
//             << w.getAudioPath()
//             << w.getImagePath();
//     }
//     return true;
// }

QVariantMap RecSetManager::readSetFromBinary(const QString& filePath) {
    QFile file(localPath(filePath));
    if (!file.open(QIODevice::ReadOnly))
        return {};
    QDataStream in(&file);
    in.setVersion(QDataStream::Qt_6_5);
    quint32 magic; quint16 version;
    in >> magic >> version;
    if (magic != k_binaryMagic)
        return {};
    QString setName;
    qint32 wordCount;
    in >> setName >> wordCount;
    QVariantList words;
    for (int i = 0; i < wordCount; ++i) {
        qint32 exprLangID, hintLangID;
        QString expression, hint, audioPath, imagePath;
        in >> exprLangID >> hintLangID >> expression >> hint >> audioPath >> imagePath;
        QVariantMap w;
        w["languageFrom"] = (int)exprLangID;
        w["languageTo"]   = (int)hintLangID;
        w["expression"]   = expression;
        w["hint"]         = hint;
        w["audioPath"]    = audioPath;
        w["imagePath"]    = imagePath;
        w["exampleUsage"] = QString{};
        words.append(w);
    }
    QVariantMap result;
    result["name"]  = setName;
    result["words"] = words;
    return result;
}

QVariantMap RecSetManager::readSetFromXml(const QString& filePath) {
    QFile file(localPath(filePath));
    if (!file.open(QIODevice::ReadOnly))
        return {};
    QXmlStreamReader xml(&file);
    QString setName;
    QVariantList words;
    while (!xml.atEnd() && !xml.hasError()) {
        xml.readNext();
        if (!xml.isStartElement()) continue;
        if (xml.name() == QLatin1String("RecSet")) {
            setName = xml.attributes().value("name").toString();
        } else if (xml.name() == QLatin1String("Word")) {
            QVariantMap w;
            w["languageFrom"] = 10;
            w["languageTo"]   = 10;
            w["expression"]   = QString{};
            w["hint"]         = QString{};
            w["audioPath"]    = QString{};
            w["imagePath"]    = QString{};
            w["exampleUsage"] = QString{};
            while (!xml.atEnd() && !xml.hasError()) {
                xml.readNext();
                if (xml.isEndElement() && xml.name() == QLatin1String("Word")) break;
                if (!xml.isStartElement()) continue;
                const QString tag = xml.name().toString();
                const QString val = xml.readElementText();
                if      (tag == "ExprLangID")   w["languageFrom"] = val.toInt();
                else if (tag == "HintLangID")   w["languageTo"]   = val.toInt();
                else if (tag == "Expression")   w["expression"]   = val;
                else if (tag == "Hint")         w["hint"]         = val;
                else if (tag == "AudioPath")    w["audioPath"]    = val;
                else if (tag == "ImagePath")    w["imagePath"]    = val;
                else if (tag == "ExampleUsage") w["exampleUsage"] = val;
            }
            words.append(w);
        }
    }
    if (xml.hasError())
        return {};
    QVariantMap result;
    result["name"]  = setName;
    result["words"] = words;
    return result;
}

// QString RecSetManager::exportSetToText(int idx) {
//     if (idx < 0 || idx >= m_recSetVec.size())
//         return {};
//     const auto& rs = m_recSetVec.at(idx);
//     QString result = rs.getSetName() + "\n\n";
//     for (int i = 0; i < rs.getWordCount(); ++i) {
//         const auto& w = rs.getWordAt(static_cast<size_t>(i));
//         result += QString::number(i + 1) + ". " + w.getExpression();
//         if (!w.getHint().isEmpty())
//             result += " — " + w.getHint();
//         result += "\n";
//     }
//     return result;
// }

// bool RecSetManager::exportSetToXml(int idx, const QString& filePath) {
//     if (idx < 0 || idx >= m_recSetVec.size())
//         return false;
//     QFile file(localPath(filePath));
//     if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
//         return false;
//     QXmlStreamWriter xml(&file);
//     xml.setAutoFormatting(true);
//     xml.writeStartDocument();
//     const auto& rs = m_recSetVec.at(idx);
//     xml.writeStartElement("RecSet");
//     xml.writeAttribute("name", rs.getSetName());
//     for (int i = 0; i < rs.getWordCount(); ++i) {
//         const auto& w = rs.getWordAt(static_cast<size_t>(i));
//         xml.writeStartElement("Word");
//         xml.writeTextElement("ExprLangID", QString::number(w.getExprLanguageID()));
//         xml.writeTextElement("HintLangID", QString::number(w.getHintLanguageID()));
//         xml.writeTextElement("Expression", w.getExpression());
//         xml.writeTextElement("Hint",       w.getHint());
//         xml.writeTextElement("AudioPath",  w.getAudioPath());
//         xml.writeTextElement("ImagePath",  w.getImagePath());
//         xml.writeEndElement();
//     }
//     xml.writeEndElement();
//     xml.writeEndDocument();
//     return true;
// }
