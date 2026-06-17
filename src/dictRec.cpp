#include "dictRec.h"

// #include <tuple>

DictRec::DictRec(size_t exprlangID, size_t hintLangID, const QString &expression, const QString &hint,
                 const QString &audioPath, const QString &imagePath)
    : m_exprLangID(exprlangID), m_hintLangID(hintLangID), m_expression(expression), m_hint(hint),
      m_audioPath(audioPath), m_imagePath(imagePath) {}

DictRec::DictRec(const DictRec &other) {
    m_exprLangID = other.m_exprLangID;
    m_hintLangID = other.m_hintLangID;
    m_expression = other.m_expression;
    m_hint       = other.m_hint;
    m_audioPath  = other.m_audioPath;
    m_imagePath  = other.m_imagePath;
}

DictRec::DictRec(DictRec &&other) {
    m_exprLangID = std::move(other.m_exprLangID);
    m_hintLangID = std::move(other.m_hintLangID);
    m_expression = std::move(other.m_expression);
    m_hint       = std::move(other.m_hint);
    m_audioPath  = std::move(other.m_audioPath);
    m_imagePath  = std::move(other.m_imagePath);
}

DictRec &DictRec::operator=(const DictRec &other) {
    m_exprLangID = other.m_exprLangID;
    m_hintLangID = other.m_hintLangID;
    m_expression = other.m_expression;
    m_hint       = other.m_hint;
    m_audioPath  = other.m_audioPath;
    m_imagePath  = other.m_imagePath;
    return *this;
}

DictRec &DictRec::operator=(DictRec &&other) {
    m_exprLangID = std::move(other.m_exprLangID);
    m_hintLangID = std::move(other.m_hintLangID);
    m_expression = std::move(other.m_expression);
    m_hint       = std::move(other.m_hint);
    m_audioPath  = std::move(other.m_audioPath);
    m_imagePath  = std::move(other.m_imagePath);
    return *this;
}

// auto DictRec::operator<=>(const DictRec &other) const {
//     if (auto cmp = m_expression <=> other.m_expression; cmp != 0) return cmp;
//     if (auto cmp = m_hint       <=> other.m_hint;       cmp != 0) return cmp;
//     if (auto cmp = m_exprLangID <=> other.m_exprLangID; cmp != 0) return cmp;
//     if (auto cmp = m_hintLangID <=> other.m_hintLangID; cmp != 0) return cmp;
//     return m_audioPath <=> other.m_audioPath;
// }
// bool DictRec::operator<(const DictRec& other) const
// {
//     return std::tie(m_expression,
//                     m_hint,
//                     m_exprLangID,
//                     m_hintLangID,
//                     m_audioPath)
//            < std::tie(m_expression,
//                       m_hint,
//                       m_exprLangID,
//                       m_hintLangID,
//                       m_audioPath);
// }

bool DictRec::operator==(const DictRec &other) const {
    return m_exprLangID == other.m_exprLangID
        && m_hintLangID == other.m_hintLangID
        && m_expression == other.m_expression
        && m_hint       == other.m_hint
        && m_audioPath  == other.m_audioPath
        && m_imagePath  == other.m_imagePath;
}
