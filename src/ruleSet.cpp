#include "ruleSet.h"

RuleSet::RuleSet(const QString& setName) : m_setName(setName) {}

RuleSet::RuleSet(const RuleSet& other) {
    m_setName = other.m_setName;
    m_folderPath = other.m_folderPath;
    m_theory = other.m_theory;
    m_questions = other.m_questions;
}

RuleSet::RuleSet(RuleSet&& other) {
    m_setName = std::move(other.m_setName);
    m_folderPath = std::move(other.m_folderPath);
    m_theory = std::move(other.m_theory);
    m_questions = std::move(other.m_questions);
}

RuleSet& RuleSet::operator=(const RuleSet& other) {
    m_setName = other.m_setName;
    m_folderPath = other.m_folderPath;
    m_theory = other.m_theory;
    m_questions = other.m_questions;
    return *this;
}

RuleSet& RuleSet::operator=(RuleSet&& other) {
    m_setName = std::move(other.m_setName);
    m_folderPath = std::move(other.m_folderPath);
    m_theory = std::move(other.m_theory);
    m_questions = std::move(other.m_questions);
    return *this;
}

QVariantMap RuleSet::getQuestionAtQML(int index) const {
    if (index < 0 || index >= m_questions.size())
        return {};
    return m_questions.at(index);
}
