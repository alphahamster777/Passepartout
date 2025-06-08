#pragma once

// #include <string>
// #include <optional>
// #include <vector>
// #include <set>
#include <stdexcept>

#include "dictRec.h"
#include <QObject>
#include <QVariant>
#include <QVector>
#include <QString>

class RecSet : public QObject {
    Q_OBJECT
public:
    // Constructors
    RecSet(const QString& setName) : m_setName(setName) {}

    RecSet(const RecSet& other){
        m_setName = other.m_setName;
        m_words = other.m_words;
    }
    RecSet(RecSet&& other) {
        m_setName = std::move(other.m_setName);
        m_words = std::move(other.m_words);
    }
    RecSet& operator=(const RecSet& other) {
        m_setName = other.m_setName;
        m_words = other.m_words;
        return *this;
    }
    RecSet& operator=(RecSet&& other) {
        m_setName = std::move(other.m_setName);
        m_words = std::move(other.m_words);
        return *this;
    }

    // Methods to manage word set
    void addWord(const DictRec& word) { m_words.push_back(word); }
    bool removeWord(const DictRec& expression) {
        for (auto it = m_words.begin(); it != m_words.end(); ++it) {
            if (*it == expression) {
                m_words.erase(it);
                return true;
            }
        }
        return false; // Word not found
    }

    // std::set<SetElement> getAllWords() const { return m_words; }
    auto begin() const { return m_words.begin(); }
    auto end() const { return m_words.end(); }
    auto begin() { return m_words.begin(); }
    auto end() { return m_words.end(); }

    // Random access
    const DictRec& getWordAt(size_t index) const {
        if (index >= m_words.size()) {
            throw std::out_of_range("Index out of range");
        }
        auto it = m_words.begin();
        std::advance(it, index); // Move iterator to the specified index
        return *it;
    }

    // Getters
    QString getSetName() const { return m_setName; }
    size_t getWordCount() const { return m_words.size(); }
private:
    QString m_setName;               // Name of the word set.
    QVector<DictRec> m_words;        // Collection of words in the set.
};
