#include "recSetManager.h"

RecSetManager::RecSetManager(QObject *parent) : QObject(parent) {}

RecSetManager::RecSetManager(const RecSetManager &other) {
    m_recSetVec = other.m_recSetVec;
}

RecSetManager::RecSetManager(RecSetManager &&other) {
    m_recSetVec = std::move(other.m_recSetVec);
}

RecSetManager &RecSetManager::operator=(const RecSetManager &other) {
    m_recSetVec = other.m_recSetVec;
    return *this;
}

RecSetManager &RecSetManager::operator=(RecSetManager &&other) {
    m_recSetVec = std::move(other.m_recSetVec);
    return *this;
}

bool RecSetManager::createRecSet(const QString &setName) {
    for (const auto& rs : m_recSetVec) {
        if (rs.getSetName() == setName)
            return false;
    }
    m_recSetVec.emplace_back(RecSet{setName});
    return true;
}

bool RecSetManager::deleteRecSet(const QString &setName) {
    for (auto it = m_recSetVec.begin(); it != m_recSetVec.end(); ++it) {
        if (it->getSetName() == setName) {
            m_recSetVec.erase(it);
            return true;
        }
    }
    return false;
}

bool RecSetManager::renameRecSet(int i, const QString &setName) {
    if (i >= 0 && i < m_recSetVec.size()) {
        m_recSetVec[i].setRecSetName(setName);
        return true;
    }
    return false;
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
    DictRec dr{
        static_cast<size_t>(rec.value("languageFrom").toInt()),
        static_cast<size_t>(rec.value("languageTo"  ).toInt()),
        rec.value("expression").toString(),
        rec.value("hint"      ).toString(),
        rec.value("audioPath" ).toString(),
        rec.value("imagePath" ).toString(),
        rec.value("context"   ).toString()
    };
    addRecToRecSet(setName, dr);
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

QVariantMap RecSetManager::getRecSetInfoQML(int idx) {
    if (idx < 0 || idx >= m_recSetVec.size())
        return {};
    const auto& rs = m_recSetVec.at(idx);
    QVariantMap map;
    map["name"]      = rs.getSetName();
    map["wordCount"] = rs.getWordCount();
    return map;
}

QVariantMap RecSetManager::getWordFromRecSetQML(int setIdx, int wordIdx) {
    if (setIdx < 0 || setIdx >= m_recSetVec.size())
        return {};
    return m_recSetVec.at(setIdx).getWordAtQML(static_cast<size_t>(wordIdx));
}
