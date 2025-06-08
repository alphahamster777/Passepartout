#pragma once

#include <optional>

#include <QObject>
#include <QString>
#include <QVariant>

#include "languageHelper.h"

class DictRec : public QObject {
    Q_OBJECT
public:
    // Constructors
    DictRec(size_t exprlangID, size_t  hintLangID, const QString& expression, const QString& hint,
               const std::optional<QString>& audioPath = std::nullopt, const std::optional<QString>& imagePath = std::nullopt)
        : m_exprLangID(exprlangID), m_hintLangID(hintLangID), m_expression(expression), m_hint(hint),
        m_audioPath(audioPath), m_imagePath(imagePath) {}

    DictRec(const DictRec& other){
        m_exprLangID = other.m_exprLangID;
        m_hintLangID = other.m_exprLangID;
        m_expression = other.m_expression;
        m_hint = other.m_hint;
        m_audioPath = other.m_audioPath;
        m_imagePath = other.m_imagePath;
    }
    DictRec(DictRec&& other) {
        m_exprLangID = std::move(other.m_exprLangID);
        m_hintLangID = std::move(other.m_exprLangID);
        m_expression = std::move(other.m_expression);
        m_hint = std::move(other.m_hint);
        m_audioPath = std::move(other.m_audioPath);
        m_imagePath = std::move(other.m_imagePath);
    }
    DictRec& operator=(const DictRec& other) {
        m_exprLangID = other.m_exprLangID;
        m_hintLangID = other.m_exprLangID;
        m_expression = other.m_expression;
        m_hint = other.m_hint;
        m_audioPath = other.m_audioPath;
        m_imagePath = other.m_imagePath;
        return *this;
    }
    DictRec& operator=(DictRec&& other) {
        m_exprLangID = std::move(other.m_exprLangID);
        m_hintLangID = std::move(other.m_exprLangID);
        m_expression = std::move(other.m_expression);
        m_hint = std::move(other.m_hint);
        m_audioPath = std::move(other.m_audioPath);
        m_imagePath = std::move(other.m_imagePath);
        return *this;
    }

    // Getters
    int getExprLanguageID() const { return m_exprLangID; }
    int getHintLanguageID() const { return m_hintLangID; }
    QString getExpression() const { return m_expression; }
    QString getHint() const { return m_hint; }
    std::optional<QString> getAudioPath() const { return m_audioPath; }
    std::optional<QString> getImagePath() const { return m_imagePath; }

    // Setters
    void setExprLangID(int languageID) { m_exprLangID = languageID; }
    void setHintLangID(int languageID) { m_hintLangID = languageID; }
    void setExpression(const QString& expression) { m_expression = expression; }
    void setMeaning(const QString& hint) { m_hint = hint; }
    void setAudioPath(const std::optional<QString>& audioPath) { m_audioPath = audioPath; }
    void setImagePath(const std::optional<QString>& imagePath) { m_imagePath = imagePath; }

    // Spaceship operator for comparisons
    auto operator<=>(const DictRec& other) const {
        if (auto cmp = m_expression <=> other.m_expression; cmp != 0) return cmp;
        if (auto cmp = m_hint <=> other.m_hint; cmp != 0) return cmp;
        if (auto cmp = m_exprLangID <=> other.m_exprLangID; cmp != 0) return cmp;
        if (auto cmp = m_hintLangID <=> other.m_hintLangID; cmp != 0) return cmp;
        return m_audioPath.value_or("") <=> other.m_audioPath.value_or("");
    }

    bool operator==(const DictRec& other) const {
        if(m_exprLangID != other.m_exprLangID){
            return false;
        }
        if(m_hintLangID != other.m_exprLangID){
            return false;
        }
        if(m_expression != other.m_expression){
            return false;
        }
        if(m_hint != other.m_hint){
            return false;
        }
        if(m_audioPath != other.m_audioPath){
            return false;
        }
        if(m_imagePath != other.m_imagePath){
            return false;
        }

        return true;
    }

private:
    int m_exprLangID;               // ID representing the language of the word to learn.
    int m_hintLangID = 0;           // ID representing the language of the hint if ste to zero that means only that it could use any language.
    QString m_expression;        // The word or expression to memorize.
    QString m_hint;       // The translation of the expression.
    std::optional<QString> m_audioPath; // File path or URL for the audio pronunciation.
    std::optional<QString> m_imagePath; // File path or URL for the corresponding image.
};
