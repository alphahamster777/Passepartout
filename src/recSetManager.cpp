#include "recSetManager.h"


RecSetManager::RecSetManager(QObject *parent)
    : QObject(parent)
{}

RecSetManager::RecSetManager(const RecSetManager &other){
    m_recSetVec = other.m_recSetVec;
}

RecSetManager::RecSetManager(RecSetManager &&other) {
    m_recSetVec = std::move(other.m_recSetVec);
}

RecSetManager &RecSetManager::operator=(RecSetManager &&other) {
    m_recSetVec = std::move(other.m_recSetVec);
    return *this;
}

bool RecSetManager::createRecSet(const QString &setName) {
    for (auto& RecSet : m_recSetVec) {
        if (RecSet.getSetName() == setName) {
            return false; //Word already present
        }
    }

    m_recSetVec.emplace_back(RecSet{setName});
    return true; // Word set not found
}

bool RecSetManager::deleteRecSet(const QString &setName) {
    for (auto it = m_recSetVec.begin(); it != m_recSetVec.end(); ++it) {
        if (it->getSetName() == setName) {
            m_recSetVec.erase(it);  // Remove the element from the vector
            return true;           // Element successfully removed
        }
    }
    return false;  // Word set not found
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
    return;
}

// Q_INVOKABLE bool RecSetManager::addRecordsToRecSet(const QString& setName,
//                             const QVariantList& records)
// {
//     if (!createRecSet(setName))
//         return false;

//     for (auto v : records) {
//         auto m = v.toMap();

//         DictRec rec {
//             1,
//             1,
//             m["expression"].toString().toStdString(),
//             m["hint"].toString().toStdString(),
//             m["audioPath"].toString().toStdString(),
//             m["imagePath"].toString().toStdString()
//         };
//         addRecToRecSet(setName, rec);
//     }
//     return true;
// }


void RecSetManager::addRecToRecSet(const QString &setName, const QVariantMap &rec)
{
    DictRec dr {
        static_cast<size_t>(rec.value("languageFrom" ).toInt()),
        static_cast<size_t>(rec.value("languageTo" ).toInt()),
        rec.value("expression" ).toString(),
        rec.value("hint"       ).toString(),
        rec.value("audioPath"  ).toString(),
        rec.value("imagePath"  ).toString()
    };
    return addRecToRecSet(setName, dr);
}

bool RecSetManager::removeRecFromRecSet(const std::string &setName, const DictRec &setElement) {
    for (auto& recSet : m_recSetVec) {
        if (recSet.getSetName() == setName) {
            return recSet.removeWord(setElement);
        }
    }
    return false; // Word set not found
}

RecSetManager &RecSetManager::operator=(const RecSetManager &other) {
    m_recSetVec = other.m_recSetVec;
    return *this;
}
