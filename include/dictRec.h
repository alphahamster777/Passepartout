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
            const std::optional<QString>& audioPath = std::nullopt, const std::optional<QString>& imagePath = std::nullopt);

    DictRec(const DictRec& other);
    DictRec(DictRec&& other);
    DictRec& operator=(const DictRec& other);
    DictRec& operator=(DictRec&& other);

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
    auto operator<=>(const DictRec& other) const;

    bool operator==(const DictRec& other) const;

private:
    int m_exprLangID;               // ID representing the language of the word to learn.
    int m_hintLangID = 0;           // ID representing the language of the hint if ste to zero that means only that it could use any language.
    QString m_expression;        // The word or expression to memorize.
    QString m_hint;       // The translation of the expression.
    std::optional<QString> m_audioPath; // File path or URL for the audio pronunciation.
    std::optional<QString> m_imagePath; // File path or URL for the corresponding image.
};
