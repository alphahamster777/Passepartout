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
    QML_ELEMENT
public:
    // Constructors
    RecSet(const QString& setName);

    RecSet(const RecSet& other);
    RecSet(RecSet&& other);
    RecSet& operator=(const RecSet& other);
    RecSet& operator=(RecSet&& other);

    // Methods to manage word set
    void addWord(const DictRec& word) { m_words.push_back(word); }
    bool removeWord(const DictRec& expression);
    void clearWords() { m_words.clear(); }

    // std::set<SetElement> getAllWords() const { return m_words; }
    auto begin() const { return m_words.begin(); }
    auto end() const { return m_words.end(); }
    auto begin() { return m_words.begin(); }
    auto end() { return m_words.end(); }

    // Random access
    Q_INVOKABLE const DictRec& getWordAt(size_t index) const;

    Q_INVOKABLE void setRecSetName(QString newName) {m_setName = newName;};

    Q_INVOKABLE QVariantMap getWordAtQML(size_t index) const;

    // Getters
    Q_INVOKABLE QString getSetName() const { return m_setName; }
    Q_INVOKABLE int getWordCount() const { return m_words.size(); }
    Q_INVOKABLE QString getFolderPath() const { return m_folderPath; }
    Q_INVOKABLE void setFolderPath(const QString& path) { m_folderPath = path; }

private:
    QString m_setName;               // Name of the word set.
    QString m_folderPath;            // "" = root, "Lib" = inside Lib, "Lib/Sub" = nested.
    QVector<DictRec> m_words;        // Collection of words in the set.
};
