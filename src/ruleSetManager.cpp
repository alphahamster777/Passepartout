#include "ruleSetManager.h"
#include "recSetManager.h"

#include <private/qzipwriter_p.h>
#include <private/qzipreader_p.h>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QStandardPaths>
#include <QUrl>
#include <QUuid>

RuleSetManager::RuleSetManager(QObject* parent) : QObject(parent) {}

namespace {
QString localPath(const QString& urlOrPath) {
    QUrl url(urlOrPath);
    return url.isLocalFile() ? url.toLocalFile() : urlOrPath;
}
// Mirrors RecSetManager's own file-local isUrl() — duplicated rather than
// shared since it's a one-line helper and the two managers otherwise avoid
// depending on each other's implementation details.
bool isUrl(const QString& s) {
    return s.startsWith(QLatin1String("http://")) || s.startsWith(QLatin1String("https://"));
}
}

int RuleSetManager::createRuleSet(const QString& setName, const QString& folderPath) {
    if (m_recSetManager && m_recSetManager->isFolderNameTaken(folderPath, setName))
        return -1;
    RuleSet gs(setName);
    gs.setFolderPath(folderPath);
    m_ruleSetVec.push_back(std::move(gs));
    if (m_recSetManager)
        m_recSetManager->registerOrderKey(folderPath, "ruleset:" + setName);
    return static_cast<int>(m_ruleSetVec.size()) - 1;
}

bool RuleSetManager::deleteRuleSetAt(int idx) {
    if (idx < 0 || idx >= m_ruleSetVec.size()) return false;
    const auto& gs = m_ruleSetVec.at(idx);
    if (m_recSetManager)
        m_recSetManager->unregisterOrderKey(gs.getFolderPath(), "ruleset:" + gs.getSetName());
    m_ruleSetVec.erase(m_ruleSetVec.begin() + idx);
    return true;
}

bool RuleSetManager::renameRuleSet(int idx, const QString& setName) {
    if (idx < 0 || idx >= m_ruleSetVec.size()) return false;
    const QString folderPath = m_ruleSetVec.at(idx).getFolderPath();
    const QString oldName    = m_ruleSetVec.at(idx).getSetName();
    if (oldName == setName) return true;
    if (m_recSetManager && m_recSetManager->isFolderNameTaken(folderPath, setName))
        return false;
    if (m_recSetManager)
        m_recSetManager->unregisterOrderKey(folderPath, "ruleset:" + oldName);
    m_ruleSetVec[idx].setRuleSetName(setName);
    if (m_recSetManager)
        m_recSetManager->registerOrderKey(folderPath, "ruleset:" + setName);
    return true;
}

bool RuleSetManager::clearQuestionsAt(int idx) {
    if (idx < 0 || idx >= m_ruleSetVec.size()) return false;
    m_ruleSetVec[idx].clearQuestions();
    return true;
}

void RuleSetManager::addQuestionToSetAt(int idx, const QVariantMap& question) {
    if (idx < 0 || idx >= m_ruleSetVec.size()) return;
    m_ruleSetVec[idx].addQuestion(question);
}

bool RuleSetManager::setTheoryAt(int idx, const QVariantMap& theory) {
    if (idx < 0 || idx >= m_ruleSetVec.size()) return false;
    m_ruleSetVec[idx].setTheory(theory);
    return true;
}

QVariantMap RuleSetManager::getRuleSetInfoQML(int idx) const {
    if (idx < 0 || idx >= m_ruleSetVec.size())
        return {};
    const auto& gs = m_ruleSetVec.at(idx);
    QVariantMap map;
    map["name"]          = gs.getSetName();
    map["questionCount"] = gs.getQuestionCount();
    map["folderPath"]    = gs.getFolderPath();
    map["theory"]        = gs.getTheory();
    return map;
}

QVariantMap RuleSetManager::getQuestionFromSetQML(int setIdx, int qIdx) const {
    if (setIdx < 0 || setIdx >= m_ruleSetVec.size())
        return {};
    return m_ruleSetVec.at(setIdx).getQuestionAtQML(qIdx);
}

bool RuleSetManager::isRuleSetNameTaken(const QString& parentPath, const QString& name,
                                               int excludeIdx) const {
    if (name.isEmpty()) return false;
    for (int i = 0; i < m_ruleSetVec.size(); ++i) {
        if (i == excludeIdx) continue;
        const auto& gs = m_ruleSetVec.at(i);
        if (gs.getFolderPath() == parentPath && gs.getSetName() == name)
            return true;
    }
    return false;
}

bool RuleSetManager::moveRuleSetToFolder(int idx, const QString& newFolderPath, bool overwrite) {
    if (idx < 0 || idx >= m_ruleSetVec.size()) return false;
    QString oldFolder = m_ruleSetVec.at(idx).getFolderPath();
    QString setName   = m_ruleSetVec.at(idx).getSetName();
    if (oldFolder == newFolderPath) return false;

    // A library with the same name can't be overwritten by a set.
    if (m_recSetManager && m_recSetManager->isLibraryNameTaken(newFolderPath, setName))
        return false;

    int clashIdx = -1;
    for (int i = 0; i < m_ruleSetVec.size(); ++i) {
        if (i == idx) continue;
        if (m_ruleSetVec.at(i).getFolderPath() == newFolderPath &&
            m_ruleSetVec.at(i).getSetName() == setName) {
            clashIdx = i;
            break;
        }
    }
    if (clashIdx != -1) {
        if (!overwrite) return false;
        if (m_recSetManager)
            m_recSetManager->unregisterOrderKey(newFolderPath, "ruleset:" + setName);
        m_ruleSetVec.erase(m_ruleSetVec.begin() + clashIdx);
        if (clashIdx < idx) --idx;
    }

    if (m_recSetManager)
        m_recSetManager->unregisterOrderKey(oldFolder, "ruleset:" + setName);
    m_ruleSetVec[idx].setFolderPath(newFolderPath);
    if (m_recSetManager)
        m_recSetManager->registerOrderKey(newFolderPath, "ruleset:" + setName);
    return true;
}

void RuleSetManager::deleteInSubtree(const QString& folderPath) {
    auto it = m_ruleSetVec.begin();
    while (it != m_ruleSetVec.end()) {
        const QString& fp = it->getFolderPath();
        if (fp == folderPath || fp.startsWith(folderPath + "/"))
            it = m_ruleSetVec.erase(it);
        else
            ++it;
    }
}

void RuleSetManager::updateFolderPathsForRename(const QString& oldPath, const QString& newPath) {
    for (auto& gs : m_ruleSetVec) {
        const QString& fp = gs.getFolderPath();
        if (fp == oldPath)
            gs.setFolderPath(newPath);
        else if (fp.startsWith(oldPath + "/"))
            gs.setFolderPath(newPath + fp.mid(oldPath.length()));
    }
}

QVariantList RuleSetManager::findConflictsInFolder(const QString& sourcePath, const QString& destPath) const {
    QVariantList result;
    for (const auto& gs : m_ruleSetVec) {
        if (gs.getFolderPath() == sourcePath && isRuleSetNameTaken(destPath, gs.getSetName())) {
            QVariantMap m;
            m["name"]       = gs.getSetName();
            m["destFolder"] = destPath;
            result.append(m);
        }
    }
    return result;
}

bool RuleSetManager::mergeDirectSetsInto(const QString& sourcePath, const QString& destPath,
                                             const QSet<QString>& overwriteKeys) {
    QSet<int> stuck;
    for (;;) {
        int idx = -1;
        for (int i = 0; i < m_ruleSetVec.size(); ++i) {
            if (m_ruleSetVec.at(i).getFolderPath() == sourcePath && !stuck.contains(i)) {
                idx = i;
                break;
            }
        }
        if (idx == -1) break;

        const QString setName = m_ruleSetVec.at(idx).getSetName();
        if (isRuleSetNameTaken(destPath, setName) &&
            !overwriteKeys.contains(destPath + "|" + setName)) {
            stuck.insert(idx);
            continue;
        }
        if (!moveRuleSetToFolder(idx, destPath, /*overwrite=*/true))
            stuck.insert(idx);
    }
    return !stuck.isEmpty();
}

int RuleSetManager::indexOf(const QString& folderPath, const QString& name) const {
    for (int i = 0; i < m_ruleSetVec.size(); ++i) {
        const auto& gs = m_ruleSetVec.at(i);
        if (gs.getFolderPath() == folderPath && gs.getSetName() == name)
            return i;
    }
    return -1;
}

// ── Persistence ───────────────────────────────────────────────────────────

namespace {
QJsonObject questionToJson(const QVariantMap& q) {
    return QJsonObject::fromVariantMap(q);
}
QVariantMap questionFromJson(const QJsonObject& o) {
    return o.toVariantMap();
}
}

bool RuleSetManager::saveAllToJson(const QString& filePath) {
    QJsonArray setsArr;
    for (const auto& gs : m_ruleSetVec) {
        QJsonObject setObj;
        setObj["name"]       = gs.getSetName();
        setObj["folderPath"] = gs.getFolderPath();
        setObj["theory"]     = QJsonObject::fromVariantMap(gs.getTheory());
        QJsonArray questionsArr;
        for (int i = 0; i < gs.getQuestionCount(); ++i)
            questionsArr.append(questionToJson(gs.getQuestionAt(i)));
        setObj["questions"] = questionsArr;
        setsArr.append(setObj);
    }

    QJsonObject root;
    root["version"] = 1;
    root["sets"]    = setsArr;

    QFile file(localPath(filePath));
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return false;
    file.write(QJsonDocument(root).toJson());
    return true;
}

bool RuleSetManager::loadFromJson(const QString& filePath) {
    QFile file(localPath(filePath));
    if (!file.open(QIODevice::ReadOnly))
        return false;
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    if (!doc.isObject())
        return false;

    m_ruleSetVec.clear();
    QJsonObject root = doc.object();
    for (const auto& setVal : root["sets"].toArray()) {
        QJsonObject setObj = setVal.toObject();
        RuleSet gs(setObj["name"].toString());
        gs.setFolderPath(setObj["folderPath"].toString());
        gs.setTheory(setObj["theory"].toObject().toVariantMap());
        for (const auto& qv : setObj["questions"].toArray())
            gs.addQuestion(questionFromJson(qv.toObject()));
        m_ruleSetVec.push_back(std::move(gs));
    }
    return true;
}

// ── ZIP Export ────────────────────────────────────────────────────────────

// manifest.json schema — mirrors RecSetManager's word-set .ppset format,
// with "kind":"ruleset" so a future importer can tell the two apart:
// { "version":1, "kind":"ruleset", "name":"...",
//   "theory": { "blocks": [ {kind,value,imgHeight}, ... ] },
//   "questions": [ {type,text,answers,options,...}, ... ] }
// A theory block's "value" is embedded under media/ (like RecSet's
// imagePath/audioPath) when it's a local image/audio path rather than a URL.
bool RuleSetManager::exportSetToZip(int idx, const QString& filePath) {
    if (idx < 0 || idx >= m_ruleSetVec.size())
        return false;

    const auto& gs = m_ruleSetVec.at(idx);
    QZipWriter zip(localPath(filePath));
    zip.setCompressionPolicy(QZipWriter::AutoCompress);

    int mediaIdx = 0;
    QJsonArray blocksArr;
    for (const auto& blockVar : gs.getTheory().value("blocks").toList()) {
        QVariantMap block = blockVar.toMap();
        QString kind  = block.value("kind").toString();
        QString value = block.value("value").toString();

        if ((kind == QLatin1String("image") || kind == QLatin1String("audio"))
            && !value.isEmpty() && !isUrl(value)) {
            QString local = localPath(value);
            QFile f(local);
            if (f.open(QIODevice::ReadOnly)) {
                QString ext    = QFileInfo(local).suffix();
                QString prefix = kind == QLatin1String("image") ? QStringLiteral("img") : QStringLiteral("aud");
                QString name   = QStringLiteral("media/%1_%2.%3").arg(prefix).arg(mediaIdx++).arg(ext);
                zip.addFile(name, f.readAll());
                value = name;
            }
        }

        QJsonObject blockObj;
        blockObj["kind"]  = kind;
        blockObj["value"] = value;
        if (block.contains("imgHeight"))
            blockObj["imgHeight"] = block.value("imgHeight").toInt();
        blocksArr.append(blockObj);
    }
    QJsonObject theoryObj;
    theoryObj["blocks"] = blocksArr;

    QJsonArray questionsArr;
    for (int i = 0; i < gs.getQuestionCount(); ++i)
        questionsArr.append(questionToJson(gs.getQuestionAt(i)));

    QJsonObject manifest;
    manifest["version"]   = 1;
    manifest["kind"]      = "ruleset";
    manifest["name"]      = gs.getSetName();
    manifest["theory"]    = theoryObj;
    manifest["questions"] = questionsArr;
    zip.addFile(QStringLiteral("manifest.json"), QJsonDocument(manifest).toJson());
    zip.close();
    return zip.status() == QZipWriter::NoError;
}

// ── ZIP Import ────────────────────────────────────────────────────────────

// Cheap manifest-only peek so a caller (e.g. Main.qml's incoming-shared-file
// handler) can tell a rule-set .ppset from a word-set one *before* committing
// to importing it as either — a word-set manifest has no "kind" field at
// all, so this is the only reliable way to tell them apart up front.
bool RuleSetManager::isRuleSetZip(const QString& filePath) const {
    QZipReader zip(localPath(filePath));
    QByteArray manifestData = zip.fileData(QStringLiteral("manifest.json"));
    if (manifestData.isEmpty())
        return false;
    QJsonObject manifest = QJsonDocument::fromJson(manifestData).object();
    return manifest[QStringLiteral("kind")].toString() == QLatin1String("ruleset");
}

QVariantMap RuleSetManager::readSetFromZip(const QString& filePath) {
    QZipReader zip(localPath(filePath));
    QByteArray manifestData = zip.fileData(QStringLiteral("manifest.json"));
    if (manifestData.isEmpty())
        return {};

    QJsonObject manifest = QJsonDocument::fromJson(manifestData).object();
    QString setName = manifest[QStringLiteral("name")].toString();

    // Extract media files into a unique cache directory under AppDataLocation
    // — mirrors RecSetManager::readSetFromZip.
    QString cacheBase = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
                        + QStringLiteral("/import_cache/")
                        + QUuid::createUuid().toString(QUuid::Id128).left(8)
                        + QStringLiteral("/");
    QDir().mkpath(cacheBase);

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

    // Resolve any local (non-URL) theory image/audio path to its extracted
    // cache location, same as exportSetToZip embedded it under media/.
    QJsonObject theoryObj = manifest[QStringLiteral("theory")].toObject();
    QVariantList blocks;
    for (const auto& bv : theoryObj[QStringLiteral("blocks")].toArray()) {
        QJsonObject bo = bv.toObject();
        QString kind  = bo[QStringLiteral("kind")].toString();
        QString value = bo[QStringLiteral("value")].toString();
        if ((kind == QLatin1String("image") || kind == QLatin1String("audio"))
            && !value.isEmpty() && !isUrl(value)) {
            value = QUrl::fromLocalFile(cacheBase + value).toString();
        }
        QVariantMap block;
        block[QStringLiteral("kind")]  = kind;
        block[QStringLiteral("value")] = value;
        if (bo.contains(QStringLiteral("imgHeight")))
            block[QStringLiteral("imgHeight")] = bo[QStringLiteral("imgHeight")].toInt();
        blocks.append(block);
    }
    QVariantMap theory;
    theory[QStringLiteral("blocks")] = blocks;

    QVariantList questions;
    for (const auto& qv : manifest[QStringLiteral("questions")].toArray())
        questions.append(questionFromJson(qv.toObject()));

    QVariantMap result;
    result[QStringLiteral("name")]      = setName;
    result[QStringLiteral("theory")]    = theory;
    result[QStringLiteral("questions")] = questions;
    return result;
}
