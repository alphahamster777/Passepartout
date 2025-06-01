#pragma once

#include <vector>

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
    explicit RecSetManager(QObject* parent = nullptr)
        : QObject(parent)
    {}
    RecSetManager(const RecSetManager& other){
        m_recSetVec = other.m_recSetVec;
    }
    RecSetManager(RecSetManager&& other) {
        m_recSetVec = std::move(other.m_recSetVec);
    }
    RecSetManager& operator=(const RecSetManager& other) {
        m_recSetVec = other.m_recSetVec;
        return *this;
    }
    RecSetManager& operator=(RecSetManager&& other) {
        m_recSetVec = std::move(other.m_recSetVec);
        return *this;
    }

    // Create a new word set
    Q_INVOKABLE bool createRecSet(const QString& setName) {
        for (auto& RecSet : m_recSetVec) {
            if (RecSet.getSetName() == setName) {
                return false; //Word already present
            }
        }

        m_recSetVec.emplace_back(RecSet{setName});
        return true; // Word set not found
    }

    Q_INVOKABLE bool deleteRecSet(const QString& setName) {
        for (auto it = m_recSetVec.begin(); it != m_recSetVec.end(); ++it) {
            if (it->getSetName() == setName) {
                m_recSetVec.erase(it);  // Remove the element from the vector
                return true;           // Element successfully removed
            }
        }
        return false;  // Word set not found
    }

    Q_INVOKABLE void addRecToRecSet(const QString& setName, const DictRec& newWord) {
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
    Q_INVOKABLE void addRecToRecSet(const QString& setName,
                                    const QVariantMap& rec)
    {
        DictRec dr {
            static_cast<size_t>(rec.value("languageFrom" ).toInt()),
            static_cast<size_t>(rec.value("languageTo" ).toInt()),
            rec.value("expression" ).toString().toStdString(),
            rec.value("hint"       ).toString().toStdString(),
            rec.value("audioPath"  ).toString().toStdString(),
            rec.value("imagePath"  ).toString().toStdString()
        };
        return addRecToRecSet(setName, dr);
    }

    // Q_INVOKABLE bool addRecordsToRecSet(const QString& setName,
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

    // Remove a word from a word set
    Q_INVOKABLE bool removeRecFromRecSet(const std::string& setName, const DictRec& setElement) {
        for (auto& recSet : m_recSetVec) {
            if (recSet.getSetName() == setName) {
                return recSet.removeWord(setElement);
            }
        }
        return false; // Word set not found
    }

    // Get all word sets
    std::vector<RecSet> getAllRecSets() const { return m_recSetVec; }
private:
    std::vector<RecSet> m_recSetVec; // Collection of expresion sets to learn.
};
