#include "recSet.h"
#include <QVariantMap>

RecSet::RecSet(const QString &setName) : m_setName(setName) {}

RecSet::RecSet(const RecSet &other){
    m_setName = other.m_setName;
    m_words = other.m_words;
}

RecSet::RecSet(RecSet &&other) {
    m_setName = std::move(other.m_setName);
    m_words = std::move(other.m_words);
}

RecSet &RecSet::operator=(RecSet &&other) {
    m_setName = std::move(other.m_setName);
    m_words = std::move(other.m_words);
    return *this;
}

bool RecSet::removeWord(const DictRec &expression) {
    for (auto it = m_words.begin(); it != m_words.end(); ++it) {
        if (*it == expression) {
            m_words.erase(it);
            return true;
        }
    }
    return false; // Word not found
}

const DictRec &RecSet::getWordAt(size_t index) const {
    if (index >= m_words.size()) {
        throw std::out_of_range("Index out of range");
    }
    auto it = m_words.begin();
    std::advance(it, index); // Move iterator to the specified index
    return *it;
}

QVariantMap RecSet::getWordAtQML(size_t index) const {
    if (index >= static_cast<size_t>(m_words.size()))
        return {};
    const auto& word = m_words.at(index);
    QVariantMap map;
    map["exprLangID"]  = word.getExprLanguageID();
    map["hintLangID"]  = word.getHintLanguageID();
    map["expression"]  = word.getExpression();
    map["hint"]        = word.getHint();
    map["audioPath"]   = word.getAudioPath();
    map["imagePath"]   = word.getImagePath();
    return map;
}

RecSet &RecSet::operator=(const RecSet &other) {
    m_setName = other.m_setName;
    m_words = other.m_words;
    return *this;
}
